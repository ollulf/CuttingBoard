extends Node

## Stills of the fence colliders in the real test level: the paddock with the fence
## shapes drawn in orange, a top-down view of the runtime-baked navmesh around it, and
## the three fence pieces side by side.
##
##   godot --path cutting-board res://tests/visual/fence_capture.tscn -- --shots=<dir>

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const FENCE_1X1 := preload("res://scenes/environment/buildings/1x1_fence.tscn")
const FENCE_1X2 := preload("res://scenes/environment/buildings/1x2_fence.tscn")
const FENCE_CORNER := preload("res://scenes/environment/buildings/fence_1x1_corner.tscn")

var _shots_dir := ""
var _level: Node3D
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
	PsxScreen.enabled = false
	# Must be set before the level enters the tree to have its shapes drawn.
	get_tree().debug_collisions_hint = true
	_level = LEVEL.instantiate()
	_style_debug_shapes(_level)
	add_child(_level)
	for node in _level.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	# A low sun so the night-time village reads in the stills.
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	add_child(_camera)
	_camera.make_current()
	_take_shots.call_deferred()


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	await get_tree().create_timer(1.5).timeout
	_frame(Vector3(-2.0, 17.0, -15.0), Vector3(-13.5, 0, -27.5))
	await _shot("paddock")
	# Top-down over the paddock with the runtime-baked navmesh drawn on the ground.
	var overlay := _navmesh_overlay()
	add_child(overlay)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 16.0
	_camera.global_position = Vector3(-14.7, 40.0, -26.0)
	_camera.rotation_degrees = Vector3(-90, 0, 0)
	await _shot("navmesh")
	overlay.queue_free()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_frame(Vector3(-17.0, 2.2, -36.5), Vector3(-17.0, 0.6, -30.0))
	await _shot("paddock_close")
	# The three pieces side by side in the empty paddock.
	var pieces := [[FENCE_1X1, -20.0], [FENCE_1X2, -15.0], [FENCE_CORNER, -9.5]]
	for piece in pieces:
		var fence: Node3D = piece[0].instantiate()
		_style_debug_shapes(fence)
		_level.add_child(fence)
		fence.transform = Transform3D(Basis.IDENTITY, Vector3(piece[1], 0, -25.0))
	_frame(Vector3(-14.5, 3.4, -20.2), Vector3(-14.5, 0.4, -25.3))
	await _shot("pieces")
	_frame(Vector3(-7.4, 2.2, -27.4), Vector3(-9.2, 0.5, -25.4))
	await _shot("corner")
	get_tree().quit()


## Draws fence shapes filled in orange so they stand out from the other debug shapes,
## and hides the terrain's heightmap wireframe, which would cover everything.
func _style_debug_shapes(root: Node) -> void:
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape.name == "TerrainCollision":
			shape.visible = false
		elif _in_fence(shape):
			shape.debug_color = Color(1.0, 0.45, 0.1, 0.45)
			shape.debug_fill = true


func _in_fence(node: Node) -> bool:
	while node:
		if "fence" in node.scene_file_path:
			return true
		node = node.get_parent()
	return false


## A translucent green mesh of the navmesh the level baked at runtime.
func _navmesh_overlay() -> MeshInstance3D:
	var region: NavigationRegion3D = _level.get_node("NavigationRegion3D")
	var nav_mesh := region.navigation_mesh
	var verts := nav_mesh.get_vertices()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nav_mesh.get_polygon_count():
		var poly := nav_mesh.get_polygon(i)
		for j in range(1, poly.size() - 1):
			for k in [poly[0], poly[j], poly[j + 1]]:
				st.add_vertex(verts[k] + Vector3.UP * 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.9, 0.35, 0.45)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	instance.global_transform = region.global_transform
	return instance


func _frame(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at)


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
