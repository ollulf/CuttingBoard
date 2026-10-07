extends Node

## Headless checks that an item in a hand can be dragged onto a hotbar square, through
## real input like inventory_hotbar_check. The item stays in the hand and the square
## follows it, as it does after a draw: its key then puts it away (wear intact) and draws
## it back into the square's own hand. Also covers that a hand drop replaces a square's
## link and that one item answers to one key. Prints PASS/FAIL per check and quits with
## the number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/hand_to_hotbar_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const BOX_SMALL := preload("res://resources/items/box_small.tres")

var _failures := 0
var _level: Node
var _panel: InventoryPanel
var _bar: HotbarPanel
var _mouse := Vector2.ZERO


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_level = LEVEL.instantiate()
	add_child(_level)
	_panel = _level.find_child("InventoryPanel", true, false) as InventoryPanel
	_bar = _level.find_child("HotbarPanel", true, false) as HotbarPanel
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var pack: Inventory = _panel._inventory
	var hotbar: Hotbar = _panel._hotbar
	var left: HandSlot = _panel._hands[0]
	var right: HandSlot = _panel._hands[1]
	for index in hotbar.slot_count():
		hotbar.clear(index)
	assert(left.is_free() and right.is_free())
	pack.add_at(ROCK, Vector2i(0, 0))
	pack.add_at(BOX_SMALL, Vector2i(0, 2))
	var box_entry := pack.get_entry_at(Vector2i(0, 2))
	box_entry.durability = 37
	hotbar.hold_entry(pack.get_entry_at(Vector2i(0, 0)), right)
	hotbar.hold_entry(box_entry, left)
	await _frames(2)
	var rock_obj := right.get_held()
	var box_obj := left.get_held()
	_check("setup: rock in the right hand, box in the left",
		right.get_item_data() == ROCK and left.get_item_data() == BOX_SMALL)

	_panel.open()
	await _frames(3)
	await _drag(_hand_center(right), _slot_center(0))
	_check("right hand -> square 1 links the held rock", hotbar.get_slot(0).held == rock_obj)
	_check("the rock stays in the right hand", right.get_held() == rock_obj)
	await _drag(_hand_center(left), _slot_center(4))
	_check("left hand -> square 5 links the held box", hotbar.get_slot(4).held == box_obj)
	_check("the box stays in the left hand", left.get_held() == box_obj)
	_panel.close()
	await _frames(3)

	await _press("hotbar_1")
	var rock_slot := hotbar.get_slot(0)
	_check("key 1 puts the held rock away", right.is_free() and rock_slot.entry != null
		and pack.get_entries().has(rock_slot.entry))
	await _press("hotbar_1")
	_check("key 1 again draws the rock into the left hand (square 1's hand)",
		left.get_item_data() == ROCK)
	# The box was in the left hand, so the draw banked it first; it stays linked to 5.
	var box_slot := hotbar.get_slot(4)
	_check("the box drawn over was banked with its wear",
		box_slot.entry != null and box_slot.entry.durability == 37)
	await _press("hotbar_5")
	_check("key 5 draws the box into the right hand with its wear",
		right.get_item_data() == BOX_SMALL and right.get_durability() == 37)

	# Replacing: the rock (left, square 1) onto square 2 moves its one key there; then
	# the box (right, square 5) onto square 2 replaces the rock's link.
	_panel.open()
	await _frames(3)
	await _drag(_hand_center(left), _slot_center(1))
	_check("one item, one key: square 1 lets go when the rock lands on square 2",
		hotbar.get_slot(1).held == left.get_held() and hotbar.get_slot(0).is_empty())
	await _drag(_hand_center(right), _slot_center(1))
	_check("a hand drop on an occupied square replaces its link",
		hotbar.get_slot(1).held == right.get_held() and hotbar.get_slot(4).is_empty())
	_check("hands keep their items after linking",
		left.get_item_data() == ROCK and right.get_item_data() == BOX_SMALL)
	_panel.close()
	await _frames(2)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _press(action: String) -> void:
	var key := InputEventAction.new()
	key.action = action
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(5)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(from, true)
	await _frames(2)
	for step in range(1, 7):
		await _move(from.lerp(to, step / 6.0), true)
	_button(to, false)
	await _frames(2)


func _move(to: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - _mouse
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_mouse = to
	Input.parse_input_event(event)
	await _frames(1)


func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _slot_center(index: int) -> Vector2:
	return _bar.slot_rect(index).get_center()


func _hand_center(hand: HandSlot) -> Vector2:
	var box: Control = _panel._slot_boxes[hand]
	return box.get_global_rect().get_center()


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
