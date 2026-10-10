extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const YARD := Vector3(-58, 0, -30)

const SHOTS := {
	"overview": [Vector3(11, 8, 9), Vector3(-1, 0, -1)],
	"map": [Vector3(30, 95, 0.1), Vector3(30, 0, -12)],
	"approach": [Vector3(16, 2.4, 6), Vector3(0, 1.0, 0)],
}

var _camera: Camera3D
var _terrain: Terrain
var _dir := "user://chair_yard_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_dir = arg.substr(8)
	DirAccess.make_dir_recursive_absolute(_dir)
	var level := LEVEL.instantiate()
	add_child(level)
	_terrain = level.get_node("Terrain")
	_camera = Camera3D.new()
	_camera.fov = 70
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	var player := get_child(0).get_node("Player")
	player.get_node("MaskOffVision").queue_free()
	for node in player.find_children("*", "CanvasLayer", true, false):
		if node.name.to_lower().contains("hud"):
			node.visible = false
	for shot_name in SHOTS:
		var shot: Array = SHOTS[shot_name]
		var ground := Vector3(0, _terrain.height_at(YARD.x, YARD.z), 0)
		_camera.global_position = YARD + ground + shot[0]
		_camera.look_at(YARD + ground + shot[1])
		_camera.make_current()
		for i in 8:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(_dir.path_join("%s.png" % shot_name))
		print("saved ", shot_name)
	get_tree().quit()
