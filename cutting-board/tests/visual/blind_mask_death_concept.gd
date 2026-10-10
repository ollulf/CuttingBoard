extends Node3D

const BODY := preload("res://scenes/characters/human_body.tscn")
const MASK := preload("res://resources/items/villager_mask.tres")

const BREAK_TIME := 0.8
const END_TIME := BREAK_TIME + BlindCollapse.END_TIME + 0.5

var _shots_dir := ""
var _shot_times: Array[float] = [0.5, 1.2, 3.2, 6.4, 8.6, 10.0]
var _taken := 0
var _time := 0.0
var _root: Node3D
var _body: HumanBody
var _collapse: BlindCollapse
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_build_stage()
	_root = Node3D.new()
	add_child(_root)
	_body = BODY.instantiate()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.5, 0.8)
	_body.material = material
	_body.mask = MASK
	_body.animated = true
	_root.add_child(_body)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()
	_camera.look_at_from_position(Vector3(3.7, 1.6, -2.1), Vector3(0.0, 0.75, -0.9))


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.42, 0.42, 0.5)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.9, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.36, 0.31, 0.24)
	floor_mesh.material_override = floor_material
	ground.add_child(floor_mesh)
	add_child(ground)


func _process(delta: float) -> void:
	_time += delta
	if _collapse == null and _time >= BREAK_TIME:
		_body.break_mask()
		_collapse = BlindCollapse.new(_body)
	if _collapse and not _body.is_limp():
		_collapse.advance(delta)
		_root.position += Vector3.FORWARD * _collapse.step_speed() * delta
		if _collapse.is_down():
			_body.go_limp()
	if _taken < _shot_times.size() and _time >= _shot_times[_taken]:
		_shoot(_taken)
		_taken += 1
	if _time >= END_TIME + 1.0:
		get_tree().quit()


func _shoot(index: int) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/a_%d.png" % [_shots_dir, index])
