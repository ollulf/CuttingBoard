extends Node3D

## The walking chair monster in its reference pose on a plain lit floor next to the
## villager body for scale, from the front, the side, three-quarters and behind.
##
##   godot --path cutting-board res://tests/visual/walking_chair_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved. --plain turns the retro screen off.
## --walk instead plays the test walk from three-quarters and never quits: record it with
## --write-movie and --quit-after.

const CHAIR := preload("res://scenes/characters/walking_chair.tscn")
const BODY := preload("res://scenes/characters/human_body.tscn")

## (name, camera direction from the pair, looking at their middle), facing -Z means the
## front is seen from -Z.
const VIEWS := [
	["front", Vector3(0.0, 0.25, -1.0)],
	["side", Vector3(1.0, 0.2, 0.0)],
	["three_quarter", Vector3(0.8, 0.35, -0.8)],
	["back", Vector3(-0.5, 0.3, 1.0)],
]

var _shots_dir := ""
var _camera: Camera3D
var _walk := false
var _chair: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--walk":
			_walk = true
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

	_chair = CHAIR.instantiate()
	add_child(_chair)
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
	var middle := Vector3(-0.45, 0.85, 0.0)
	if _walk:
		_camera.look_at_from_position(middle + Vector3(0.8, 0.35, -0.8).normalized() * 3.6, middle)
		(_chair.get_node("%AnimationPlayer") as AnimationPlayer).play("walk")
		return
	for view in VIEWS:
		var dir: Vector3 = view[1]
		_camera.look_at_from_position(middle + dir.normalized() * 3.6, middle)
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
