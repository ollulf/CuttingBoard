extends Node3D

const TRADER := preload("res://scenes/characters/soul_trader.tscn")
const BODY := preload("res://scenes/characters/human_body.tscn")

const VIEWS := [
	["front", Vector3(0.6, 1.7, -4.4), Vector3(0.0, 1.1, 0.0)],
	["three_quarter", Vector3(3.2, 1.9, -3.0), Vector3(0.0, 1.1, 0.0)],
	["side", Vector3(4.2, 1.5, 0.3), Vector3(0.0, 1.1, 0.0)],
	["head", Vector3(-0.5, 1.9, -0.9), Vector3(0.0, 1.85, 0.35)],
	["flasks", Vector3(0.5, 1.5, -2.2), Vector3(0.0, 1.55, -1.0)],
]

var _shots_dir := ""
var _clip := false
var _camera: Camera3D
var _angle := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			PsxScreen.enabled = false
		elif arg == "--clip":
			_clip = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.06, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.3, 0.38)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 2.6, 0.0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	add_child(floor_mesh)

	add_child(TRADER.instantiate())
	var body: Node3D = BODY.instantiate()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	body.position = Vector3(-1.5, 0, -1.4)
	body.rotation.y = PI * 0.8

	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.make_current()
	if not _clip:
		_run.call_deferred()


func _process(delta: float) -> void:
	if not _clip:
		return
	_angle += delta * 0.6
	var at := Vector3(sin(_angle) * -4.2, 1.8, cos(_angle) * -4.2)
	_camera.look_at_from_position(at, Vector3(0, 1.1, 0))


func _run() -> void:
	for view in VIEWS:
		_camera.look_at_from_position(view[1], view[2])
		await _shot(view[0])
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _shots_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var path := _shots_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
