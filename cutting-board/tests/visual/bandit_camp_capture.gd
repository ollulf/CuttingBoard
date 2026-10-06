extends Node
## Captures the Hollowstump bandit camp in the test level from a few viewpoints.
## Run with Movie Maker off-screen:
##   godot --path cutting-board --position -10000,-10000 --write-movie <tmp>.avi
##     res://tests/visual/bandit_camp_capture.tscn -- --shots=<dir>

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const CAMP := Vector3(56, 0, -68)

## name -> [camera position, look-at target], relative to the camp origin.
const SHOTS := {
	"trail": [Vector3(-17, 3.2, 12), Vector3(-2, 3.0, 0)],
	"gate": [Vector3(-11, 1.8, 0.5), Vector3(0, 1.6, 0)],
	"den": [Vector3(-1.6, 1.6, 1.4), Vector3(1.4, 0.6, -1.2)],
	"overview": [Vector3(-14, 15, 14), Vector3(0, 1, 0)],
}

var _camera: Camera3D
var _dir := "user://bandit_camp_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_dir = arg.substr(8)
	DirAccess.make_dir_recursive_absolute(_dir)
	add_child(LEVEL.instantiate())
	_camera = Camera3D.new()
	_camera.fov = 70
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	for shot_name in SHOTS:
		var shot: Array = SHOTS[shot_name]
		_camera.global_position = CAMP + shot[0]
		_camera.look_at(CAMP + shot[1])
		_camera.make_current()
		for i in 8:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(_dir.path_join("%s.png" % shot_name))
		print("saved ", shot_name)
	get_tree().quit()
