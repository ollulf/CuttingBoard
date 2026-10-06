extends Node3D

## The soul in a bottle at night in the test level: where it stands by the Mask-Monger in
## the market, close up, two bottles side by side (each swirling at its own pace), and in
## the player's hand in first person.
##
##   godot --path cutting-board res://tests/visual/soul_bottle_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved. --plain turns the retro screen
## off.

const BOTTLE := preload("res://scenes/items/soul_bottle.tscn")
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
	_camera.fov = 50.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await _wait(2.0)
	var placed := level.find_child("SoulBottle", true, false) as RigidBody3D
	print("soul bottle in the village at ", placed.global_position if placed else "nowhere")
	if not placed:
		get_tree().quit()
		return
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var player := level.find_child("Player", false, false) as Node3D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	var at := placed.global_position
	placed.freeze = true
	_camera.make_current()
	_look(at + Vector3(1.6, 1.3, 1.8), at)
	await _shot("world_wide")
	_look(at + Vector3(0.3, 0.2, 0.4), at)
	await _shot("world_close")

	# A second bottle beside it: the two swirls should not be in step.
	var twin := BOTTLE.instantiate() as RigidBody3D
	twin.freeze = true
	level.add_child(twin)
	twin.global_position = at + Vector3(0.2, 0.0, 0.0)
	_look(at + Vector3(0.1, 0.15, 0.5), at + Vector3(0.1, 0.0, 0.0))
	await _shot("twins")
	twin.queue_free()

	# Held in the right hand, seen through the player's own camera.
	player.global_position = at + Vector3(-1.5, -0.09, 1.5)
	player.look_at(at + Vector3(0.0, -0.09, 0.0), Vector3.UP)
	(player.get_node("%Camera3D") as Camera3D).make_current()
	var hand := player.get_node("%HandSlotRight") as HandSlot
	(placed.get_node("Carryable") as Carryable).take(player)
	hand.hold(placed)
	await _wait(0.5)
	await _shot("held")
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


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
