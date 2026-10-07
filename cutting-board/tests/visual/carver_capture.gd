extends Node3D

## The Carver concept on a plain lit floor, with a human body beside the stump for scale:
## from the front, three-quarters, close on his mask, from the side (the hunch) and down in the yard. With --clip it
## holds one view on the working arms instead, for recording the idle with Movie Maker.
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <tmp>.avi
##     res://tests/visual/carver_capture.tscn -- --shots=<dir> [--clip]
##
## Needs a real window; under --headless nothing is saved. --plain turns the retro screen off.

const CARVER := preload("res://scenes/characters/carver.tscn")
const BODY := preload("res://scenes/characters/human_body.tscn")

## (name, camera position, looked-at point).
const VIEWS := [
	["front", Vector3(0.0, 4.3, -13.0), Vector3(0.0, 3.9, 0.0)],
	["three_quarter", Vector3(8.0, 4.4, -9.6), Vector3(0.0, 3.8, 0.0)],
	["mask", Vector3(-1.0, 5.8, -4.9), Vector3(0.0, 5.4, -0.9)],
	["side", Vector3(11.0, 4.4, 1.0), Vector3(0.0, 4.0, 0.3)],
	["yard", Vector3(-5.5, 2.6, -6.5), Vector3(-0.5, 1.2, -0.8)],
]
const CLIP_VIEW := [Vector3(4.6, 4.4, -7.4), Vector3(0.0, 4.0, -0.6)]

var _shots_dir := ""
var _clip := false
var _camera: Camera3D


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
	env.environment.ambient_light_color = Color(0.28, 0.28, 0.36)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 2.6, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	add_child(floor_mesh)

	add_child(CARVER.instantiate())
	var body: Node3D = BODY.instantiate()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	body.position = Vector3(-2.3, 0, -3.0)
	body.rotation.y = PI * 0.85

	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.make_current()
	if _clip:
		_camera.look_at_from_position(CLIP_VIEW[0], CLIP_VIEW[1])
	else:
		_run.call_deferred()


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
