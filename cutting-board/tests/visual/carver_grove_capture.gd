extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const SHOTS := [
	["grove_near", Vector3(-60, 3.0, 32), Vector3(-72, 4.0, 42)],
	["grove_far", Vector3(-12, 2.6, 8), Vector3(-72, 3.0, 42)],
	["grove_path", Vector3(-36, 2.2, 23), Vector3(-72, 4.0, 42)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := "user://carver_grove_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(dir)
	var level := LEVEL.instantiate()
	level.get_node("IntroSequence").free()
	add_child(level)
	var terrain: Terrain = level.get_node("Terrain")
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	for i in 30:
		await get_tree().process_frame
	var player := level.get_node("Player")
	player.get_node("MaskOffVision").queue_free()
	for node in player.find_children("*", "CanvasLayer", true, false):
		if node.name.to_lower().contains("hud"):
			node.visible = false
	for shot in SHOTS:
		var at: Vector3 = shot[1]
		at.y += terrain.height_at(at.x, at.z)
		var target: Vector3 = shot[2]
		target.y += terrain.height_at(target.x, target.z)
		camera.global_position = at
		camera.look_at(target)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot[0]])
		print("saved ", shot[0])
	get_tree().quit()
