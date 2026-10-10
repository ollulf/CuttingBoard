extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const BARREL := preload("res://scenes/items/barrel.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const HAMMER := preload("res://resources/items/hammer.tres")
const BOX := preload("res://resources/items/box_small.tres")
const END := 23.5

var _level: Node3D
var _player: CharacterBody3D
var _panel: InventoryPanel
var _fighter: Npc
var _walker: Npc
var _time := 0.0
var _done := {}


func _ready() -> void:
	Sfx.log_plays = true
	_level = LEVEL.instantiate()
	add_child(_level)
	_player = _level.get_node("Player")
	for node in _level.find_children("*", "Npc", true, false):
		if String(node.name).begins_with("Bandit"):
			node.queue_free()
	_level.get_node("TrainingDummy").queue_free()
	for rock in ["Rock", "Rock2", "Rock3", "Rock4", "Rock5"]:
		_level.get_node(rock).queue_free()
	_fighter = _level.get_node("Villager")
	_walker = _level.get_node("Villager2")
	_panel = _level.find_children("*", "InventoryPanel", true, false)[0]
	var inventory: Inventory = _player.inventory
	inventory.add(HAMMER)
	inventory.add(BOX)
	inventory.add(ROCK)


func _process(delta: float) -> void:
	_time += delta
	var t := _time

	_hold("move_forward", (t > 1.0 and t < 7.2) or (t > 8.2 and t < 9.8))
	_hold("sprint", t > 5.6 and t < 7.2)
	_once(4.0, func() -> void: Input.action_press("jump"))
	_once(4.05, func() -> void: Input.action_release("jump"))
	_once(8.0, func() -> void: _player._crouching = true)
	_once(10.0, func() -> void: _player._crouching = false)

	_once(9.0, _send_walker)
	_once(10.5, _place_fighter)
	for blow in 3:
		_once(11.0 + blow * 0.7, func() -> void: _player._punch(_player.hand_right))

	_once(13.6, _draw_rock)
	_once(14.2, func() -> void: _player.hand_right.begin_charge())
	_once(14.9, func() -> void: _player.interactor.release_hand(_player.hand_right))
	if t > 13.8 and t < 15.0:
		_player.camera_pivot.rotation.x = lerpf(_player.camera_pivot.rotation.x, deg_to_rad(8.0), 0.1)

	_once(16.0, _panel.open)
	_once(16.6, func() -> void: _drag_from_cell(Vector2i(0, 0)))
	_once(17.0, func() -> void: _drag_to_cell(Vector2i(3, 4)))
	_once(17.5, func() -> void: _drag_from_cell(Vector2i(3, 4)))
	_once(17.9, func() -> void: _drag_to_item(BOX))
	_once(18.3, func() -> void: _drag_from_cell(Vector2i(3, 4)))
	_once(18.7, func() -> void: _drag_to_hand(_player.hand_right))
	_once(19.2, _panel.close)
	_once(19.6, func() -> void: _player.hotbar.stow_hands())
	_once(20.0, _place_barrel)
	for blow in 3:
		_once(20.5 + blow * 0.65, func() -> void: _player._punch(_player.hand_right))

	if t > 10.4 and t < 13.5 and is_instance_valid(_fighter):
		_face(_fighter.global_position + Vector3.UP * 1.1)
	if t > END:
		get_tree().quit()


func _hold(action: StringName, down: bool) -> void:
	if down and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not down and Input.is_action_pressed(action):
		Input.action_release(action)


func _once(at: float, what: Callable) -> void:
	if _time < at or _done.has(at):
		return
	_done[at] = true
	what.call()


func _ahead(distance: float, side := 0.0) -> Vector3:
	var forward := -_player.global_basis.z
	var right := _player.global_basis.x
	return _player.global_position + forward * distance + right * side


func _send_walker() -> void:
	_walker.brain.shut_down()
	_walker.global_position = _ahead(5.0, 4.0)
	_walker.locomotion.move_to(_ahead(5.0, -6.0))


func _place_fighter() -> void:
	_fighter.brain.shut_down()
	_fighter.locomotion.stop()
	_fighter.global_position = _ahead(1.35)
	_fighter.look_at(Vector3(_player.global_position.x, _fighter.global_position.y, _player.global_position.z))
	_player.melee.unarmed_damage = ceili(_fighter.health.max_health / 3.0)
	_player.melee.reach = 2.5


func _draw_rock() -> void:
	for entry in _player.inventory.get_entries():
		if entry.data == ROCK:
			_player.hotbar.assign(3, entry)
	if _player.hotbar.use(3):
		Sfx.play(_player.hotbar_sound)


func _place_barrel() -> void:
	var barrel := BARREL.instantiate() as RigidBody3D
	_level.add_child(barrel)
	barrel.global_position = _ahead(1.1) + Vector3.UP * 0.6
	_player.camera_pivot.rotation.x = deg_to_rad(-40.0)
	_player.melee.unarmed_damage = 60


func _face(point: Vector3) -> void:
	var to: Vector3 = point - _player.camera_pivot.global_position
	_player.rotation.y = lerp_angle(_player.rotation.y, atan2(-to.x, -to.z), 0.2)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_player.camera_pivot.rotation.x = lerpf(_player.camera_pivot.rotation.x, pitch, 0.2)


func _cell_point(cell: Vector2i) -> Vector2:
	var half := _panel.cell_size * 0.5
	return _panel._grid_origin(InventoryPanel.Side.PLAYER) + Vector2(
		_panel._offset(cell.x) + half, _panel._offset(cell.y) + half
	)


func _drag_from_cell(cell: Vector2i) -> void:
	_panel._begin_drag(_cell_point(cell))


func _drag_to_cell(cell: Vector2i) -> void:
	_release_at(_cell_point(cell))


func _drag_to_item(data: ItemData) -> void:
	for entry in _player.inventory.get_entries():
		if entry.data == data:
			_release_at(_cell_point(entry.origin))
			return


func _drag_to_hand(hand: HandSlot) -> void:
	_release_at(_panel._local_rect(_panel._slot_boxes[hand]).get_center())


func _release_at(pos: Vector2) -> void:
	if _panel._is_dragging():
		_panel._update_drag(pos)
		_panel._end_drag(pos)
