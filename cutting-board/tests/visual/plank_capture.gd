extends Node3D

## The wooden plank weapon: lying in the village's wagon yard, then held by the player.
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <dir>/x.avi
##       res://tests/visual/plank_capture.tscn -- --shots=<dir>

# The village has no ground of its own; the test level puts it on the valley terrain.
const VILLAGE := preload("res://scenes/levels/test_level.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const PLANK := preload("res://scenes/items/plank.tscn")

var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	add_child(VILLAGE.instantiate())
	_tour.call_deferred()


func _tour() -> void:
	await _wait(1.5)
	var plank := find_child("PlankWeapon", true, false) as Node3D
	print("plank at ", plank.global_position)
	print("plank basis ", plank.global_basis)
	for layer in find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var centre := (plank.get_node("CollisionShape3D") as Node3D).global_position
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(centre + Vector3(2.0, 2.5, 0.5), centre)
	camera.make_current()
	await _shot("01_plank_in_village")
	camera.look_at_from_position(centre + Vector3(6.0, 4.0, 3.0), centre + Vector3(-1.5, 0.5, -1.0))
	await _shot("02_plank_wide")

	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.global_position = plank.global_position + Vector3(1.0, 0.0, 2.0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	for layer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var held: Node3D = PLANK.instantiate()
	add_child(held)
	(held.get_node("Carryable") as Carryable).take(player)
	(player.get_node("%HandSlotRight") as HandSlot).hold(held)
	(player.get_node("%Camera3D") as Camera3D).make_current()
	await _shot("03_holding")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await _wait(0.3)
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
