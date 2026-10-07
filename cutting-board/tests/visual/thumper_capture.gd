extends Node3D

## First-person clip of the Churn Thumper in the test level: the player holds it armed in
## the right hand with spikes in the bag, fires at the training dummy (recoil, spike
## sticking in it), then clicks again to rearm (rearm_thumper_both).
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <out>.avi \
##       --fixed-fps 30 --resolution 960x540 --quit-after 150 \
##       res://tests/visual/thumper_capture.tscn [-- --shots=<dir>]

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const THUMPER := preload("res://resources/items/churn_thumper.tres")
const SPIKE := preload("res://resources/items/railroad_spike.tres")

var _player: Node3D
var _thumper: Node3D
var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	# The test level stands the player at the origin facing the training dummy 6 m
	# down -Z, with its own sky and ground, so the clip needs no stage of its own.
	var level := LEVEL.instantiate()
	add_child(level)
	_player = level.get_node("Player")
	# No mask is worn here: drop the mask-off view (the striped void) and the HUD.
	_player.get_node("MaskOffVision").queue_free()
	for node in _player.find_children("*", "CanvasLayer", true, false):
		if node.name.to_lower().contains("hud"):
			node.visible = false
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	_play.call_deferred()


func _play() -> void:
	for i in 20:
		await get_tree().physics_frame
	for i in 3:
		_player.inventory.add(SPIKE)
	_thumper = _player.interactor.spawn_into_hand(THUMPER, -1, _player.hand_right)
	_thumper.armed = true
	_thumper._sync_action()
	await get_tree().create_timer(0.8).timeout
	await _shot("thumper_held")
	_click()
	await get_tree().create_timer(0.9).timeout
	await _shot("thumper_fired")
	_click()
	await get_tree().create_timer(0.6).timeout
	await _shot("thumper_rearming")


func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	_player._use_hand(_player.hand_right, event)


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
