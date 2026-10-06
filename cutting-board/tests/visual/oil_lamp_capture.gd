extends Node3D

## The oil lamp, photographed at night in the test level: where it is placed in the
## wagon yard, lying on the ground, and held in the player's hand in first person.
##
##   godot --path cutting-board res://tests/visual/oil_lamp_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved. --plain turns the retro
## screen off, for reading shapes rather than the look.

const PLAYER := preload("res://scenes/characters/player.tscn")
const LAMP := preload("res://scenes/items/oil_lamp.tscn")
const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _shots_dir := ""
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	_camera = Camera3D.new()
	add_child(_camera)
	_tour.call_deferred()


func _tour() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await _wait(2.0)
	_camera.make_current()
	var placed := level.find_child("OilLamp", true, false) as Node3D
	print("oil lamp in the village at ", placed.global_position if placed else "nowhere")
	if not placed:
		get_tree().quit()
		return
	var at := placed.global_position
	_look(at + Vector3(-0.6, 0.5, 0.7), at + Vector3(0.0, 0.1, 0.0))
	await _shot("01_village_close")
	_look(at + Vector3(-4.0, 1.7, 3.0), at + Vector3(0.0, 0.3, 0.0))
	await _shot("02_village_wide")

	# On the ground, a few steps out in the yard.
	var ground_at := at + Vector3(-2.5, 0.0, 2.0)
	ground_at.y = 0.3
	placed.global_position = ground_at
	await _wait(1.5)
	_look(placed.global_position + Vector3(-2.5, 1.4, 2.5), placed.global_position)
	await _shot("03_ground")

	# Held in the right hand, seen through the player's own camera.
	var player: Node3D = PLAYER.instantiate()
	level.add_child(player)
	player.global_position = placed.global_position + Vector3(0.0, 0.1, 3.0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	for layer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	(placed.get_node("Carryable") as Carryable).take(player)
	(player.get_node("%HandSlotRight") as HandSlot).hold(placed)
	(player.get_node("%Camera3D") as Camera3D).make_current()
	await _wait(0.5)
	await _shot("04_held_first_person")
	_camera.make_current()
	_look(player.global_position + Vector3(2.0, 1.6, -1.0), player.global_position + Vector3(0.0, 1.1, 0.0))
	await _shot("05_held_outside")
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _shot(shot_name: String) -> void:
	await _wait(0.2)
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
