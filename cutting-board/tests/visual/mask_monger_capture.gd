extends Node3D

const MONGER := preload("res://scenes/characters/mask_monger_model.tscn")
const BODY := preload("res://scenes/characters/human_body.tscn")

const VIEWS := [
	["front", Vector3(0.0, 0.25, -1.0)],
	["side", Vector3(1.0, 0.2, 0.0)],
	["three_quarter", Vector3(0.8, 0.35, -0.8)],
	["back", Vector3(-0.5, 0.3, 1.0)],
]

var _shots_dir := ""
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	add_child(floor_mesh)

	var monger: Node3D = MONGER.instantiate()
	add_child(monger)
	var body: Node3D = BODY.instantiate()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	body.position = Vector3(-0.9, 0, 0)
	body.rotation.y = PI

	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()
	_run.call_deferred()


func _run() -> void:
	var middle := Vector3(-0.4, 0.95, 0.0)
	for view in VIEWS:
		var dir: Vector3 = view[1]
		_camera.look_at_from_position(middle + dir.normalized() * 4.2, middle)
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
