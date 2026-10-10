extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const TREES := [
	"tree_1_large", "tree_1_slim", "tree_1_strange", "tree_2_large",
	"tree_2_slim", "tree_3_large", "tree_3_slim", "tree_4_large",
]
const SPACING := 24.0
const CLIP_TREE := 3

var _shots_dir := ""
var _clip := ""
var _camera: Camera3D
var _trees: Array[Node3D] = []
var _nav_region: NavigationRegion3D
var _overlays: Array[MeshInstance3D] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--clip="):
			_clip = arg.trim_prefix("--clip=")
	PsxScreen.enabled = false
	get_tree().debug_collisions_hint = true
	get_tree().debug_navigation_hint = _clip.is_empty()
	_build_stage()
	if _clip.is_empty():
		_run.call_deferred()
	else:
		_walk_clip.call_deferred()


func _run() -> void:
	if not _shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	await _wait(0.5)
	for i in _trees.size():
		var trunk := _trunk_of(_trees[i])
		var distance: float = trunk.radius * 2.6 + 7.0
		var at: Vector3 = trunk.center + Vector3(0, 2.4, 0)
		_camera.global_position = at + Vector3(distance * 0.6, -0.6, distance * 0.8)
		_camera.look_at(at, Vector3.UP)
		_set_overlays(false)
		await _wait(0.2)
		await _shot(TREES[i] + "_plain")
		_set_overlays(true)
		await _wait(0.1)
		await _shot(TREES[i])

	_nav_region.bake_navigation_mesh(false)
	await _wait(0.5)
	_draw_navmesh()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	for tree in _trees:
		(tree as VisualInstance3D).layers = 2
	_camera.cull_mask = 1
	for i in _trees.size():
		var trunk := _trunk_of(_trees[i])
		_camera.size = trunk.radius * 2.0 + 5.0
		_camera.global_position = trunk.center + Vector3(0, 30, 0)
		_camera.look_at(trunk.center, Vector3.FORWARD)
		await _wait(0.2)
		await _shot("nav_" + TREES[i])
	get_tree().quit()


func _walk_clip() -> void:
	var trunk := _trunk_of(_trees[CLIP_TREE])
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.set_process_unhandled_input(false)
	player.global_position = trunk.center + Vector3(0.3, 0.1, trunk.radius + 6.0)
	if _clip == "third":
		player.body.visible = true
		_camera.global_position = trunk.center + Vector3(3.0, 4.2, trunk.radius + 8.0)
		_camera.look_at(trunk.center + Vector3(0.6, 0.8, trunk.radius + 1.0), Vector3.UP)
		_camera.make_current()
	await _wait(0.5)
	Input.action_press("move_forward")
	for i in 150:
		MouseGrab.capture()
		if i == 75:
			Input.action_press("move_right")
		await get_tree().process_frame
	Input.action_release("move_forward")
	Input.action_release("move_right")
	get_tree().quit()


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 1, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 0, Color(0.3, 0.29, 0.26))
	image.set_pixel(0, 1, Color(0.3, 0.29, 0.26))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(200, 60, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 120)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	var ground := StaticBody3D.new()
	ground.add_to_group(&"navigation_source")
	ground.position.x = 80.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 120)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	ground.add_child(floor_mesh)
	add_child(ground)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	_nav_region = NavigationRegion3D.new()
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)

	for i in TREES.size():
		var tree: Node3D = load("res://scenes/environment/foliage/trees/%s.tscn" % TREES[i]).instantiate()
		add_child(tree)
		tree.position = Vector3(i * SPACING, 0, 0)
		_trees.append(tree)
		if _clip.is_empty() or _clip == "third":
			_show_through_bark(tree)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	_camera.make_current()


func _show_through_bark(tree: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = Color(0.1, 0.85, 1.0, 0.35 if _clip.is_empty() else 0.2)
	for node in tree.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var cylinder := shape.shape as CylinderShape3D
		var mesh := CylinderMesh.new()
		mesh.top_radius = cylinder.radius
		mesh.bottom_radius = cylinder.radius
		mesh.height = cylinder.height
		mesh.radial_segments = 24
		mesh.material = material
		var overlay := MeshInstance3D.new()
		overlay.mesh = mesh
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shape.add_child(overlay)
		_overlays.append(overlay)


func _draw_navmesh() -> void:
	var nav_mesh := _nav_region.navigation_mesh
	var vertices := nav_mesh.get_vertices()
	var fill := ImmediateMesh.new()
	fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in nav_mesh.get_polygon_count():
		var polygon := nav_mesh.get_polygon(p)
		for k in range(1, polygon.size() - 1):
			for index in [polygon[0], polygon[k], polygon[k + 1]]:
				fill.surface_add_vertex(vertices[index] + Vector3.UP * 0.05)
	fill.surface_end()
	fill.surface_begin(Mesh.PRIMITIVE_LINES)
	for p in nav_mesh.get_polygon_count():
		var polygon := nav_mesh.get_polygon(p)
		for k in polygon.size():
			fill.surface_add_vertex(vertices[polygon[k]] + Vector3.UP * 0.07)
			fill.surface_add_vertex(vertices[polygon[(k + 1) % polygon.size()]] + Vector3.UP * 0.07)
	fill.surface_end()
	var fill_material := StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.albedo_color = Color(0.2, 0.9, 0.3, 0.45)
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.05, 0.3, 0.1)
	fill.surface_set_material(0, fill_material)
	fill.surface_set_material(1, line_material)
	var instance := MeshInstance3D.new()
	instance.mesh = fill
	add_child(instance)


func _set_overlays(on: bool) -> void:
	for overlay in _overlays:
		overlay.visible = on


func _trunk_of(tree: Node3D) -> Dictionary:
	var shape: CollisionShape3D = tree.find_children("*", "CollisionShape3D", true, false)[0]
	var center := shape.global_position
	center.y = tree.global_position.y
	return {center = center, radius = (shape.shape as CylinderShape3D).radius}


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	if _shots_dir.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
