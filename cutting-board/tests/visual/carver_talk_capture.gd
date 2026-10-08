extends Node

## Stills of the Carver talking in his grove: the player stands at his stump, presses
## Talk, and the speech plank shows his first and third lines.
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <tmp>.avi \
##       --resolution 960x540 res://tests/visual/carver_talk_capture.tscn -- --shots=<dir>

const LEVEL := preload("res://scenes/levels/test_level.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := "user://carver_talk_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(dir)
	var level := LEVEL.instantiate()
	level.get_node("IntroSequence").free()
	add_child(level)
	var terrain: Terrain = level.get_node("Terrain")
	var grove: Node3D = level.get_node("CarverGrove")
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	for i in 30:
		await get_tree().process_frame
	var player: Node3D = level.get_node("Player")
	player.get_node("MaskOffVision").queue_free()
	for node in player.find_children("*", "CanvasLayer", true, false):
		if node.name.to_lower().contains("hud"):
			node.visible = false
	var forward := -grove.global_basis.z
	var centre := grove.global_position
	var near := centre + forward * 2.8
	near.y = terrain.height_at(near.x, near.z) + 1.0
	player.global_position = near
	var at := centre + forward * 6.0 + grove.global_basis.x * 1.5
	at.y = terrain.height_at(at.x, at.z) + 2.2
	camera.global_position = at
	camera.look_at(centre + Vector3(0, 2.6, 0))
	for i in 10:
		await get_tree().process_frame
	var dialogue: Dialogue = grove.get_node("%Dialogue")
	dialogue.use(player)
	for shot in ["talk_1", "talk_2", "talk_3"]:
		# Long enough for the line to type out in full.
		for i in 240:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot])
		print("saved ", shot)
		dialogue.advance()
	get_tree().quit()
