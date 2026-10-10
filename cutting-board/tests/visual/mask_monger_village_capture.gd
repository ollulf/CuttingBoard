extends Node3D

const VILLAGE := preload("res://scenes/levels/village.tscn")
const MONGER_POS := Vector3(2.6, 0.0, 8.4)
const VIEWS := [
	["approach", Vector3(1.4, 1.6, 2.8)],
	["close", Vector3(2.6, 1.6, 5.4)],
]


func _ready() -> void:
	var shots_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	add_child(VILLAGE.instantiate())
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	for view in VIEWS:
		camera.position = view[1]
		camera.look_at(MONGER_POS + Vector3(0, 1.4, 0))
		for i in 10:
			await get_tree().process_frame
		if shots_dir != "":
			DirAccess.make_dir_recursive_absolute(shots_dir)
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots_dir, view[0]])
	get_tree().quit()
