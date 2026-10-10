extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

var _shots_dir := ""
var _only: PackedStringArray = []
var _weapon := "hammer"
var _camera: Camera3D
var _npcs: Array[Npc] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--weapon="):
			_weapon = arg.trim_prefix("--weapon=")
	PsxScreen.enabled = false
	_run.call_deferred()


func _run() -> void:
	await _build_stage()
	await _wait(0.3)
	if _wants("loadouts"):
		await _loadouts()
	if _wants("fight"):
		await _fight()
	get_tree().quit()


func _loadouts() -> void:
	var items := ["hammer", "saw", "plank", "rock", ""]
	for i in items.size():
		var npc := _spawn(Vector3(-3.0 + i * 1.5, 0, 0), Vector3(0, 0, 1))
		npc.brain.shut_down()
		npc.sight.set_physics_process(false)
	await _wait(0.1)
	for i in items.size():
		_arm(_npcs[i], items[i])
	_camera.global_position = Vector3(1.5, 1.6, 6.2)
	_camera.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	await _wait(1.2)
	await _shot("loadouts_front")
	_camera.global_position = Vector3(6.5, 1.5, 2.5)
	_camera.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	await _wait(0.2)
	await _shot("loadouts_side")
	_clear()


func _fight() -> void:
	var villager := _spawn(Vector3(0, 0, 0), Vector3(1, 0, 0))
	villager.sight.set_physics_process(false)
	var bandit := _spawn(Vector3(-2.5, 0, 0), Vector3(1, 0, 0), BANDIT)
	await _wait(0.1)
	_arm(villager, _weapon)
	bandit.brain.shut_down()
	bandit.health.max_health = 100000
	bandit.health.reset()
	_camera.global_position = Vector3(-1.2, 1.7, 4.6)
	_camera.look_at(Vector3(-1.2, 1.0, 0), Vector3.UP)
	await _wait(1.0)
	await _shot("fight_00_before")
	var info := DamageInfo.new(6, bandit)
	info.position = villager.global_position + Vector3.UP * 1.3
	info.direction = Vector3(1, 0, 0)
	info.knockback = 4.0
	villager.health.apply_damage(info)
	villager.sight.set_physics_process(true)
	for i in range(1, 25):
		await _wait(0.15)
		await _shot("fight_%02d" % i)
	print("bandit health after the fight: %d / %d" % [bandit.health.get_current(), bandit.health.max_health])
	_clear()


func _arm(npc: Npc, item: String) -> void:
	if not npc.hand_right.is_free():
		npc.hand_right.release().queue_free()
	for entry in npc.inventory.get_entries():
		npc.inventory.remove(entry)
	if item.is_empty():
		return
	var data := load("res://resources/items/%s.tres" % item) as ItemData
	if data.throwable:
		npc.inventory.add(data)
	else:
		npc.equip(data, npc.hand_right)


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
	material.uv1_scale = Vector3(30, 30, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	var ground := StaticBody3D.new()
	ground.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	ground.add_child(floor_mesh)
	add_child(ground)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.4
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)
	region.bake_navigation_mesh(false)
	var map := get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			break

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()


func _spawn(at: Vector3, facing: Vector3, scene: PackedScene = VILLAGER) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at + Vector3.UP * 0.02
	add_child(npc)
	npc.look_at(npc.global_position + facing, Vector3.UP)
	_npcs.append(npc)
	return npc


func _clear() -> void:
	for npc in _npcs:
		npc.queue_free()
	_npcs.clear()
	for child in get_children():
		if child is RigidBody3D:
			child.queue_free()


func _wants(stage: String) -> bool:
	return _only.is_empty() or Array(_only).any(func(part: String) -> bool: return part in stage)


func _shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	if _shots_dir.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("%s.png" % shot_name))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
