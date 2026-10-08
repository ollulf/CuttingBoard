extends Node

## A 30-second first-person gameplay reel of the test level, played by script with hard
## cuts between beats: the mask goes on before the Mask-Monger, a walk down the village
## street, a word with a villager, a hammer at the training dummy, and the walk up to the
## Carver's grove. Meant for Movie Maker (it records the sound too):
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <out>.avi \
##       --fixed-fps 30 --resolution 1280x720 --quit-after 900 \
##       res://tests/visual/gameplay_reel_capture.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")
const HAMMER := preload("res://resources/items/hammer.tres")

var _level: Node3D
var _player  # player.gd has no class_name.
var _terrain: Terrain


func _ready() -> void:
	_level = LEVEL.instantiate()
	# The opening fall is skipped: the reel starts where it lands, before the Monger.
	_level.get_node("IntroSequence").free()
	add_child(_level)
	_player = _level.get_node("Player")
	_terrain = _level.get_node("Terrain")
	_play.call_deferred()


func _play() -> void:
	await _mask_on()
	await _village_walk()
	await _talk()
	await _dummy()
	await _grove()
	get_tree().quit()


## Lands before the Mask-Monger with no face yet (the grain of the mask-off view), the
## mask in hand; it goes on.
func _mask_on() -> void:
	_place(Vector3(1.5, 0, -45.85), -2.69, -0.05)
	await _physics(10)
	_player.interactor.spawn_into_hand(PLAYER_MASK, -1, _player.hand_right)
	await _wait(1.6)
	await _look(-2.69, 0.25, 0.8)
	await _wait(0.4)
	_click(_player.hand_right)
	await _wait(2.4)


## Cuts to the lantern road and walks up it towards the village, looking about.
func _village_walk() -> void:
	_place(Vector3(0.5, 0, -18.0), 0.0, 0.0)
	await _wait(0.3)
	Input.action_press("move_forward")
	await _look(0.25, 0.02, 1.8)
	await _look(-0.2, 0.0, 2.0)
	await _look(0.0, 0.04, 1.2)
	Input.action_release("move_forward")
	await _wait(0.4)


## Cuts to a villager outside the village and says hello: one line on a speech plank.
func _talk() -> void:
	var villager := _level.get_node("Villager") as Npc
	villager.brain.set_physics_process(false)
	villager.locomotion.stop()
	var at := villager.global_position
	var away := Vector3(1.0, 0, -1.4).normalized()
	_place(at + away * 2.0, 0.0, 0.0)
	_player.look_at(Vector3(at.x, _player.global_position.y, at.z))
	_player.camera_pivot.rotation.x = -0.12
	villager.locomotion.face(_player.global_position)
	await _wait(1.0)
	_player.interactor.interact(_player.inventory)
	await _wait(4.0)


## Cuts to the training dummy with the hammer out: steps in and lands three blows.
func _dummy() -> void:
	_player.control = 0  # ControlMode.FULL: the talk handed back only the view.
	_place(Vector3(0.3, 0, -2.0), 0.0, -0.1)
	_player.interactor.spawn_into_hand(HAMMER, -1, _player.hand_right)
	await _wait(0.6)
	Input.action_press("move_forward")
	await _wait(0.9)
	Input.action_release("move_forward")
	for i in 3:
		await _wait(0.25)
		_click(_player.hand_right)
		await _wait(0.85)
	await _wait(0.8)


## Ends on the footpath to the Carver's grove, walking up towards him.
func _grove() -> void:
	_player.hotbar.stow_hands()
	var target := Vector3(-72, 0, 42)
	target.y = _terrain.height_at(target.x, target.z) + 3.0
	_place(Vector3(-50, 0, 33), 0.0, 0.0)
	_player.look_at(Vector3(target.x, _player.global_position.y, target.z))
	_player.camera_pivot.rotation.x = 0.06
	await _wait(0.4)
	Input.action_press("move_forward")
	await _look(_player.rotation.y + 0.15, 0.1, 3.0)
	Input.action_release("move_forward")
	await _wait(5.0)


# --- Helpers ----------------------------------------------------------------------------


## Stands the player on the ground at `at` (its y is ignored), facing `yaw`, eyes pitched.
func _place(at: Vector3, yaw: float, pitch: float) -> void:
	at.y = _terrain.height_at(at.x, at.z) + 1.0
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	_player.camera_pivot.rotation.x = pitch


## Turns the view to `yaw` / `pitch` over `seconds`, as a hand on the mouse would.
func _look(yaw: float, pitch: float, seconds: float) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_player, "rotation:y", yaw, seconds)
	tween.tween_property(_player.camera_pivot, "rotation:x", pitch, seconds)
	await tween.finished


func _click(hand: HandSlot) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if hand == _player.hand_right else MOUSE_BUTTON_LEFT
	event.pressed = true
	_player._use_hand(hand, event)


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
