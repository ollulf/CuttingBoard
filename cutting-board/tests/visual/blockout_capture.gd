extends Node3D

const DEMO := preload("res://tests/visual/blockout_demo.tscn")

var _shots_dir := ""
var _frame := 0
var _demo: Node3D
var _baked: Node3D
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.24, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.32, 0.38)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)
	_demo = DEMO.instantiate()
	add_child(_demo)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()
	_camera.look_at_from_position(Vector3(-3.5, 9.0, 13.0), Vector3(3.2, 0.6, 0.5))


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 20:
		_report_collision()
		_shot("overview")
		_camera.look_at_from_position(Vector3(1.5, 1.7, 7.5), Vector3(0.0, 1.2, 0.0))
	elif _frame == 25:
		_shot("doorway")
		_camera.look_at_from_position(Vector3(12.5, 3.5, 6.0), Vector3(7.0, 0.8, 1.0))
	elif _frame == 30:
		_shot("ramp_stairs")
		_bake_room()
		_camera.look_at_from_position(Vector3(-4.0, 11.0, 14.0), Vector3(-3.0, 0.6, 0.0))
	elif _frame == 36:
		_shot("baked")
		get_tree().quit()


func _report_collision() -> void:
	var space := get_world_3d().direct_space_state
	for probe in [Vector3(6.5, 5, 2), Vector3(8.5, 5, -1.0), Vector3(0, 5, 0), Vector3(0, 5, 2.85)]:
		var query := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 10)
		var hit := space.intersect_ray(query)
		print("BLOCKOUT ray at ", probe, " hit y=", hit.position.y if hit else -1.0)


func _bake_room() -> void:
	var room := _demo.get_node("%Room") as CSGCombiner3D
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RoomBaked"
	mesh_instance.mesh = room.bake_static_mesh()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = room.bake_collision_shape()
	body.add_child(shape)
	mesh_instance.add_child(body)
	_baked = Node3D.new()
	_baked.add_child(mesh_instance)
	_demo.add_child(_baked)
	_baked.position = Vector3(-7.5, 0, 0)
	print("BLOCKOUT baked room surfaces=", mesh_instance.mesh.get_surface_count(), " collision faces=", (shape.shape as ConcavePolygonShape3D).get_faces().size() / 3)


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
