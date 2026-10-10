class_name InventoryPanel
extends Control

@export var cell_size := 46
@export var cell_gap := 2
@export var tooltip_delay := 0.5
@export var tooltip_offset := Vector2(18, 20)
@export var empty_cell_color := Color(1, 1, 1, 0.07)
@export var item_color := Color(0.66, 0.39, 0.16, 0.4)
@export var weapon_color := Color(0.74, 0.2, 0.15, 0.5)
@export var mask_color := Color(0.88, 0.82, 0.64, 0.42)
@export var wearable_color := Color(0.33, 0.55, 0.28, 0.5)
@export var damage_text_color := Color(1.0, 0.8, 0.7)
@export var price_color := Color(1.0, 0.72, 0.16)
@export var price_short_color := Color(0.75, 0.35, 0.3)
@export var tile_wear_color := Color(0.95, 0.85, 0.55, 0.9)
@export var tile_worn_color := Color(0.9, 0.3, 0.2, 0.95)
@export var item_border_color := Color(0.86, 0.68, 0.36, 0.6)
@export var item_text_color := Color(0.96, 0.9, 0.76)
@export var slot_border_color := Color(0.85, 0.79, 0.63, 0.18)
@export var held_border_color := Color(0.55, 0.9, 0.55, 0.95)
@export var valid_drop_color := Color(0.45, 0.85, 0.45, 0.35)
@export var invalid_drop_color := Color(0.9, 0.35, 0.3, 0.35)
@export var eject_color := Color(1.0, 0.85, 0.55, 0.9)

@export_group("Sounds")
@export var open_sound: SoundBank = preload("res://resources/audio/ui_open.tres")
@export var close_sound: SoundBank = preload("res://resources/audio/ui_close.tres")
@export var pick_sound: SoundBank = preload("res://resources/audio/ui_pick.tres")
@export var place_sound: SoundBank = preload("res://resources/audio/ui_place.tres")
@export var equip_sound: SoundBank = preload("res://resources/audio/ui_equip.tres")
@export var invalid_sound: SoundBank = preload("res://resources/audio/ui_invalid.tres")
@export var drop_sound: SoundBank = preload("res://resources/audio/ui_drop.tres")
@export_group("")

const NO_CELL := Vector2i(-1, -1)

enum Side { PLAYER, CONTAINER }
const NO_SIDE := -1

signal drop_requested(inventory: Inventory, entry: InventoryEntry)

@onready var _window: Control = %Window
@onready var _size_label: Label = %PlayerSize
@onready var _grid: Control = %PlayerGrid
@onready var _container_title: Label = %ContainerTitle
@onready var _container_size: Label = %ContainerSize
@onready var _container_grid: Control = %ContainerGrid
@onready var _container_frame: Control = %ContainerFrame
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_value: Label = %HealthValue
@onready var _figure: PaperDoll = %Figure
@onready var _equip_frame: Control = %EquipFrame
@onready var _hand_boxes: Array[Panel] = [%LeftHandSlot, %RightHandSlot]
@onready var _hand_labels: Array[Label] = [%LeftHandLabel, %RightHandLabel]
@onready var _wear_boxes: Dictionary = {
	Equipment.Slot.MASK: %MaskSlot,
	Equipment.Slot.HEAD: %HeadSlot,
	Equipment.Slot.BODY: %BodySlot,
	Equipment.Slot.PACK: %PackSlot,
}
@onready var _tooltip: ItemTooltip = %ItemTooltip
@onready var _tooltip_timer: Timer = %TooltipTimer

const WEAR_NAMES := {
	Equipment.Slot.MASK: "Mask",
	Equipment.Slot.HEAD: "Head",
	Equipment.Slot.BODY: "Body",
	Equipment.Slot.PACK: "Pack",
}

var _inventory: Inventory
var _container: Inventory
var _trader: Trader
var _interactor: Interactor
var _hands: Array[HandSlot] = []
var _equipment: Equipment
var _health: Health
var _hotbar: Hotbar
var _hotbar_panel: HotbarPanel

var _tiles: Dictionary = {}
var _slot_boxes: Dictionary = {}

var _drag_data: ItemData
var _drag_entry: InventoryEntry
var _drag_side := NO_SIDE
var _drag_hand: HandSlot
var _drag_wear := Equipment.NO_SLOT
var _drag_hotbar := HotbarPanel.NO_SLOT
var _drag_rotated := false
var _drag_grab_cell := Vector2i.ZERO
var _drag_grab_pixels := Vector2.ZERO
var _ghost: Control
var _drop_hint: ColorRect

var _hover_source: Object
var _hover_data: ItemData
var _hover_durability := -1
var _mouse_down := false


func _ready() -> void:
	_tooltip_timer.wait_time = tooltip_delay
	_tooltip_timer.timeout.connect(_on_tooltip_delay_elapsed)
	hide()


func bind(inventory: Inventory) -> void:
	if _inventory == inventory:
		return
	if _inventory and _inventory.changed.is_connected(_rebuild):
		_inventory.changed.disconnect(_rebuild)
	_inventory = inventory
	if _inventory:
		_inventory.changed.connect(_rebuild)
	_rebuild()


func bind_equipment(hands: Array[HandSlot], interactor: Interactor) -> void:
	_hands = hands
	_interactor = interactor
	_slot_boxes.clear()
	for index in mini(_hands.size(), _hand_boxes.size()):
		var hand := _hands[index]
		_slot_boxes[hand] = _hand_boxes[index]
		_hand_labels[index].text = hand.display_name
		hand.item_held.connect(_rebuild.unbind(1))
		hand.item_released.connect(_rebuild.unbind(1))
	_rebuild()


func bind_loadout(equipment: Equipment) -> void:
	if _equipment and _equipment.changed.is_connected(_rebuild):
		_equipment.changed.disconnect(_rebuild)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(_rebuild)
	_figure.bind(_equipment)
	_rebuild()


func bind_health(health: Health) -> void:
	if _health and _health.changed.is_connected(_on_health_changed):
		_health.changed.disconnect(_on_health_changed)
	_health = health
	if _health:
		_health.changed.connect(_on_health_changed)
	_show_health()


func _on_health_changed(_current: int, _maximum: int) -> void:
	_show_health()


func _show_health() -> void:
	var current := _health.get_current() if _health else 0
	var maximum := _health.max_health if _health else 0
	_health_bar.max_value = maxi(maximum, 1)
	_health_bar.value = current
	_health_value.text = "%d / %d" % [current, maximum]


func bind_hotbar(hotbar: Hotbar, panel: HotbarPanel) -> void:
	_hotbar = hotbar
	_hotbar_panel = panel


func open_container(container: Inventory) -> void:
	if container == null or container == _inventory:
		return
	_bind_container(container)
	open()


func open_trade(trader: Trader) -> void:
	if trader == null:
		return
	_trader = trader
	_bind_container(trader.get_stock())
	_rebuild()
	open()


func is_trading() -> bool:
	return _trader != null and _container != null


func _bind_container(container: Inventory) -> void:
	if container == null:
		_trader = null
	if _container == container:
		return
	if _container and _container.changed.is_connected(_rebuild):
		_container.changed.disconnect(_rebuild)
	_container = container
	if _container:
		_container.changed.connect(_rebuild)
	_rebuild()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		if _is_dragging():
			_cancel_drag()
		else:
			close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event is InputEventMouseButton:
		_mouse_down = event.pressed
		if event.pressed:
			_clear_hover()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				transfer_at(event.position)
			elif event.pressed:
				_begin_drag(event.position)
			else:
				_end_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_rotate(event.position)
		if not event.pressed:
			_update_hover(event.position, true)
	elif event is InputEventMouseMotion:
		if _is_dragging():
			_update_drag(event.position)
		else:
			_update_hover(event.position, false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _inventory == null:
		return
	_rebuild()
	_show_health()
	if not visible:
		Sfx.play(open_sound)
	show()
	MouseGrab.release()


func close() -> void:
	if visible:
		Sfx.play(close_sound)
	_cancel_drag()
	_clear_hover()
	_bind_container(null)
	hide()
	MouseGrab.capture()


func _inventory_for(side: int) -> Inventory:
	return _container if side == Side.CONTAINER else _inventory


func _grid_for(side: int) -> Control:
	return _container_grid if side == Side.CONTAINER else _grid


func _visible_sides() -> Array[int]:
	var sides: Array[int] = [Side.PLAYER]
	if _container:
		sides.append(Side.CONTAINER)
	return sides


func _slot_at(pos: Vector2) -> Dictionary:
	for side in _visible_sides():
		var cell := _cell_at(side, pos)
		if cell != NO_CELL:
			return {"side": side, "cell": cell}
	return {}


func _is_dragging() -> bool:
	return _drag_data != null


func _drag_size() -> Vector2i:
	return _drag_data.footprint(_drag_rotated)


func _rotate(pos: Vector2) -> void:
	if _is_dragging():
		_rotate_drag(pos)
		return
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		_hotbar.clear(hotbar_index)
		return
	var slot := _slot_at(pos)
	if slot.is_empty():
		return
	var inventory := _inventory_for(slot["side"])
	var entry := inventory.get_entry_at(slot["cell"])
	if entry:
		inventory.rotate_item(entry)


func _rotate_drag(pos: Vector2) -> void:
	_drag_rotated = not _drag_rotated
	_drag_grab_cell = Vector2i(_drag_grab_cell.y, _drag_grab_cell.x)
	_drag_grab_pixels = Vector2(_drag_grab_pixels.y, _drag_grab_pixels.x)
	_ghost.queue_free()
	_ghost = _make_tile(_drag_data, _drag_rotated, _drag_durability())
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	_update_drag(pos)


func _begin_drag(pos: Vector2) -> void:
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		_begin_hotbar_drag(hotbar_index, pos)
		return
	var hand := _hand_at(pos)
	if hand:
		_begin_hand_drag(hand, pos)
		return
	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		_begin_wear_drag(wear, pos)
		return
	var slot := _slot_at(pos)
	if slot.is_empty():
		return
	var side: int = slot["side"]
	var cell: Vector2i = slot["cell"]
	var entry := _inventory_for(side).get_entry_at(cell)
	if entry == null:
		return
	_drag_entry = entry
	_drag_side = side
	_drag_data = entry.data
	_drag_rotated = entry.rotated
	_drag_grab_cell = cell - entry.origin
	_drag_grab_pixels = (
		pos - _grid_origin(side) - Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
	)

	_dim_tile(entry)
	_start_ghost(pos)


func _begin_hand_drag(hand: HandSlot, pos: Vector2) -> void:
	var data := hand.get_item_data()
	if _interactor == null or data == null:
		return
	_drag_hand = hand
	_grab_upright(data)
	_dim_tile(hand)
	_start_ghost(pos)


func _begin_wear_drag(slot: int, pos: Vector2) -> void:
	var data := _equipment.get_item(slot)
	if data == null:
		return
	_drag_wear = slot
	_grab_upright(data)
	_dim_tile(_wear_boxes[slot])
	_start_ghost(pos)


func _begin_hotbar_drag(index: int, pos: Vector2) -> void:
	var slot := _hotbar.get_slot(index)
	if slot == null or slot.entry == null:
		return
	_drag_hotbar = index
	_grab_upright(slot.data)
	_start_ghost(pos)


func _drag_durability() -> int:
	if _drag_entry:
		return _drag_entry.durability
	if _drag_hand:
		return _drag_hand.get_durability()
	if _drag_wear != Equipment.NO_SLOT:
		return _equipment.get_durability(_drag_wear)
	if _drag_hotbar != HotbarPanel.NO_SLOT:
		var slot := _hotbar.get_slot(_drag_hotbar)
		return slot.get_durability() if slot else -1
	return -1


func _grab_upright(data: ItemData) -> void:
	_drag_data = data
	_drag_rotated = false
	_drag_grab_cell = Vector2i.ZERO
	_drag_grab_pixels = Vector2(_span(data.grid_size.x), _span(data.grid_size.y)) * 0.5


func _start_ghost(pos: Vector2) -> void:
	Sfx.play(pick_sound)
	_ghost = _make_tile(_drag_data, _drag_rotated, _drag_durability())
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)

	_drop_hint = ColorRect.new()
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_hint)
	move_child(_drop_hint, _ghost.get_index())

	_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	_ghost.position = pos - _drag_grab_pixels
	_ghost.modulate = eject_color if _is_outside_window(pos) else Color(1, 1, 1, 0.75)

	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		var rect := _hotbar_panel.slot_rect(hotbar_index)
		_drop_hint.position = rect.position - global_position
		_drop_hint.size = rect.size
		_drop_hint.color = (
			valid_drop_color if _accepts_link(hotbar_index) else invalid_drop_color
		)
		_drop_hint.show()
		return

	var hand := _hand_at(pos)
	if hand:
		var box: Control = _slot_boxes[hand]
		_drop_hint.position = box.global_position - global_position
		_drop_hint.size = box.size
		_drop_hint.color = valid_drop_color if _accepts(hand) else invalid_drop_color
		_drop_hint.show()
		return

	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		var wear_box: Control = _wear_boxes[wear]
		_drop_hint.position = wear_box.global_position - global_position
		_drop_hint.size = wear_box.size
		_drop_hint.color = valid_drop_color if _accepts_wear(wear) else invalid_drop_color
		_drop_hint.show()
		return

	var slot := _slot_at(pos)
	if slot.is_empty() or _drag_hotbar != HotbarPanel.NO_SLOT:
		_drop_hint.hide()
		return
	var side: int = slot["side"]
	var cell: Vector2i = slot["cell"]
	var origin := cell - _drag_grab_cell
	var footprint := _drag_size()
	_drop_hint.position = _grid_origin(side) + Vector2(_offset(origin.x), _offset(origin.y))
	_drop_hint.size = Vector2(_span(footprint.x), _span(footprint.y))
	_drop_hint.color = valid_drop_color if _can_drop_at(side, cell) else invalid_drop_color
	_drop_hint.show()


func _end_drag(pos: Vector2) -> void:
	if not _is_dragging():
		return
	var entry := _drag_entry
	var from := _inventory_for(_drag_side)
	var from_hand := _drag_hand
	var from_wear := _drag_wear
	var from_hotbar := _drag_hotbar
	var rotated := _drag_rotated
	var grab := _drag_grab_cell
	var slot := _slot_at(pos)
	var target_hand := _hand_at(pos)
	var target_wear := _wear_at(pos)
	var wear_ok := _accepts_wear(target_wear)
	var target_hotbar := _hotbar_at(pos)
	var outside := _is_outside_window(pos)
	if is_trading() and (_drag_side == Side.CONTAINER or _slot_side(slot) == Side.CONTAINER):
		_end_trade_drag(slot, entry, from, rotated, grab)
		return
	_play_drop_sound(from_hotbar, target_hand, target_wear, target_hotbar, slot, outside)
	_cancel_drag()

	if from_hotbar != HotbarPanel.NO_SLOT:
		if target_hotbar != HotbarPanel.NO_SLOT:
			_hotbar.move_assignment(from_hotbar, target_hotbar)
		else:
			_hotbar.clear(from_hotbar)
		return
	if target_hotbar != HotbarPanel.NO_SLOT:
		if from_hand:
			_hotbar.assign_held(target_hotbar, from_hand)
		elif entry and from == _inventory:
			_hotbar.assign(target_hotbar, entry)
		return
	if target_hand:
		_drop_on_hand(target_hand, entry, from_hand)
		return
	if target_wear != Equipment.NO_SLOT:
		if wear_ok:
			_put_on(target_wear, from, entry)
		return
	if outside:
		if from_hand:
			_interactor.drop_hand(from_hand)
		elif from_wear != Equipment.NO_SLOT:
			_drop_worn(from_wear)
		else:
			drop_requested.emit(from, entry)
		return
	if slot.is_empty():
		return
	var to := _inventory_for(slot["side"])
	var cell: Vector2i = slot["cell"]
	if from_hand:
		_stow_hand_to_grid(from_hand, to, cell - grab, rotated)
		return
	if from_wear != Equipment.NO_SLOT:
		_take_off(from_wear, to, cell - grab, rotated)
		return
	_place_item(from, entry, to, cell - grab, rotated)


func _end_trade_drag(
	slot: Dictionary, entry: InventoryEntry, from: Inventory, rotated: bool, grab: Vector2i
) -> void:
	var buying := _drag_side == Side.CONTAINER and _slot_side(slot) == Side.PLAYER
	_cancel_drag()
	if not buying:
		if _slot_side(slot) == Side.CONTAINER and from == _container:
			Sfx.play(place_sound, -6.0)
		else:
			Sfx.play(invalid_sound)
		return
	if _trader.buy(entry, _inventory, slot["cell"] - grab, rotated):
		Sfx.play(place_sound)
	else:
		_refuse_tile(entry)


func _slot_side(slot: Dictionary) -> int:
	return slot["side"] if not slot.is_empty() else NO_SIDE


func _refuse_tile(entry: InventoryEntry) -> void:
	Sfx.play(invalid_sound)
	var tile := _tiles.get(entry) as Control
	if tile:
		tile.modulate = invalid_drop_color
		create_tween().tween_property(tile, "modulate", Color.WHITE, 0.4)


func _play_drop_sound(
	from_hotbar: int, target_hand: HandSlot, target_wear: int,
	target_hotbar: int, slot: Dictionary, outside: bool
) -> void:
	if target_hotbar != HotbarPanel.NO_SLOT:
		if from_hotbar != HotbarPanel.NO_SLOT or _accepts_link(target_hotbar):
			Sfx.play(place_sound)
		else:
			Sfx.play(invalid_sound)
	elif from_hotbar != HotbarPanel.NO_SLOT:
		Sfx.play(place_sound)
	elif target_hand:
		if target_hand != _drag_hand and not _accepts(target_hand):
			Sfx.play(invalid_sound)
	elif target_wear != Equipment.NO_SLOT:
		Sfx.play(equip_sound if _accepts_wear(target_wear) else invalid_sound)
	elif outside:
		Sfx.play(drop_sound)
	elif slot.is_empty():
		Sfx.play(place_sound, -6.0)
	elif not _can_drop_at(slot["side"], slot["cell"]):
		Sfx.play(invalid_sound)
	elif _drag_hand == null or _inventory_for(slot["side"]) != _inventory:
		Sfx.play(place_sound)


func transfer_at(pos: Vector2) -> bool:
	if _container == null or _is_dragging():
		return false
	var slot := _slot_at(pos)
	if slot.is_empty():
		return false
	var from := _inventory_for(slot["side"])
	var to := _container if from == _inventory else _inventory
	var entry := from.get_entry_at(slot["cell"])
	if entry == null:
		return false
	if is_trading():
		if from == _container and _trader.buy(entry, _inventory):
			Sfx.play(place_sound)
			return true
		_refuse_tile(entry)
		return false
	for rotated: bool in [entry.rotated, not entry.rotated]:
		var free := to.find_free_origin(entry.data.footprint(rotated))
		if free.x >= 0 and to.add_at(entry.data, free, entry.durability, rotated):
			from.remove(entry)
			Sfx.play(place_sound)
			return true
	Sfx.play(invalid_sound)
	var tile := _tiles.get(entry) as Control
	if tile:
		tile.modulate = invalid_drop_color
		create_tween().tween_property(tile, "modulate", Color.WHITE, 0.4)
	return false


func _place_item(
	from: Inventory, entry: InventoryEntry, to: Inventory, origin: Vector2i, rotated: bool
) -> void:
	if from == null or to == null or entry == null:
		return
	if from == to:
		to.move(entry, origin, rotated)
		return
	if not to.add_at(entry.data, origin, entry.durability, rotated):
		var free := to.find_free_origin(entry.data.footprint(rotated))
		if free.x < 0 or not to.add_at(entry.data, free, entry.durability, rotated):
			return
	from.remove(entry)


func _drop_on_hand(hand: HandSlot, entry: InventoryEntry, from_hand: HandSlot) -> void:
	if hand == null or hand == from_hand or not hand.is_free():
		return
	if from_hand:
		_hotbar.move_between_hands(from_hand, hand)
		return
	if entry == null:
		return
	_hotbar.hold_entry(entry, hand)


func _stow_hand_to_grid(
	hand: HandSlot, to: Inventory, origin: Vector2i, rotated: bool
) -> void:
	if to == null or hand.is_free():
		return
	if to == _inventory:
		_hotbar.put_away_hand(hand, origin, rotated)
		return
	_interactor.stow_held(hand, to, origin, rotated)


func _put_on(slot: int, from: Inventory, entry: InventoryEntry) -> void:
	if from == null or entry == null:
		return
	_equipment.swap_from(slot, from, entry)


func _take_off(slot: int, to: Inventory, origin: Vector2i, rotated: bool) -> void:
	var data := _equipment.get_item(slot)
	if to == null or data == null:
		return
	var durability := _equipment.get_durability(slot)
	if not to.add_at(data, origin, durability, rotated):
		var free := to.find_free_origin(data.footprint(rotated))
		if free.x < 0 or not to.add_at(data, free, durability, rotated):
			return
	_equipment.unequip(slot)


func _drop_worn(slot: int) -> void:
	if _interactor and _interactor.drop_item(
		_equipment.get_item(slot), _equipment.get_durability(slot)
	):
		_equipment.unequip(slot)


func _cancel_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _drop_hint:
		_drop_hint.queue_free()
		_drop_hint = null
	for key in [_drag_entry, _drag_hand, _wear_boxes.get(_drag_wear)]:
		var tile := _tiles.get(key) as Control
		if tile:
			tile.modulate.a = 1.0
	_drag_data = null
	_drag_entry = null
	_drag_side = NO_SIDE
	_drag_hand = null
	_drag_wear = Equipment.NO_SLOT
	_drag_hotbar = HotbarPanel.NO_SLOT
	_drag_rotated = false


func _accepts(hand: HandSlot) -> bool:
	if hand == null or _drag_data == null or hand == _drag_hand:
		return false
	if _drag_hotbar != HotbarPanel.NO_SLOT or _drag_wear != Equipment.NO_SLOT:
		return false
	return hand.is_free() and not _drag_data.world_scene_path.is_empty()


func _accepts_wear(slot: int) -> bool:
	if _equipment == null or _drag_data == null or slot == Equipment.NO_SLOT:
		return false
	if _drag_entry == null or slot == _drag_wear:
		return false
	if not _equipment.accepts(slot, _drag_data):
		return false
	return _equipment.can_swap_from(slot, _inventory_for(_drag_side), _drag_entry)


func _accepts_link(index: int) -> bool:
	if _hotbar == null:
		return false
	if _drag_hotbar != HotbarPanel.NO_SLOT:
		var target := _hotbar.get_slot(index)
		return index != _drag_hotbar and target != null and not target.is_held()
	if _drag_hand:
		return true
	return _drag_entry != null and _drag_side == Side.PLAYER


func _can_drop_at(side: int, cell: Vector2i) -> bool:
	var to := _inventory_for(side)
	var origin := cell - _drag_grab_cell
	var vacating := _drag_entry if side == _drag_side else null
	if is_trading() and (side == Side.CONTAINER or _drag_side == Side.CONTAINER):
		if side == Side.CONTAINER or not _trader.can_afford(_drag_entry, _inventory):
			return false
	return to.is_region_free(origin, _drag_size(), vacating)


func _update_hover(pos: Vector2, restart: bool) -> void:
	var hovered := _hover_at(pos)
	var source: Object = hovered.get("source")
	if source == _hover_source and not restart:
		if _tooltip.visible:
			_place_tooltip(pos)
		return
	var was_showing := _tooltip.visible
	_hover_source = source
	_hover_data = hovered.get("data") as ItemData
	_hover_durability = int(hovered.get("durability", -1))
	if _hover_data == null or _mouse_down:
		_tooltip.hide()
		_tooltip_timer.stop()
		return
	if was_showing:
		_tooltip_timer.stop()
		_tooltip.show_item(_hover_data, _hover_durability)
		_place_tooltip(pos)
		return
	_tooltip.hide()
	_tooltip_timer.start()


func _clear_hover() -> void:
	_hover_source = null
	_hover_data = null
	_hover_durability = -1
	_tooltip_timer.stop()
	_tooltip.hide()


func _on_tooltip_delay_elapsed() -> void:
	if _hover_data == null or _mouse_down or _is_dragging():
		return
	_tooltip.show_item(_hover_data, _hover_durability)
	_place_tooltip(get_local_mouse_position())


func _place_tooltip(pos: Vector2) -> void:
	var card := _tooltip.size
	var target := pos + tooltip_offset
	if target.x + card.x > size.x:
		target.x = pos.x - tooltip_offset.x - card.x
	if target.y + card.y > size.y:
		target.y = pos.y - tooltip_offset.y - card.y
	_tooltip.position = target.clamp(Vector2.ZERO, (size - card).max(Vector2.ZERO))


func _hover_at(pos: Vector2) -> Dictionary:
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		var link := _hotbar.get_slot(hotbar_index)
		if link == null or link.data == null:
			return {}
		return {"source": link, "data": link.data, "durability": link.get_durability()}
	var hand := _hand_at(pos)
	if hand:
		var held := hand.get_item_data()
		if held == null:
			return {}
		return {"source": hand, "data": held, "durability": hand.get_durability()}
	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		var worn := _equipment.get_item(wear)
		if worn == null:
			return {}
		return {
			"source": _wear_boxes[wear], "data": worn,
			"durability": _equipment.get_durability(wear),
		}
	var slot := _slot_at(pos)
	if slot.is_empty():
		return {}
	var entry := _inventory_for(slot["side"]).get_entry_at(slot["cell"])
	if entry == null:
		return {}
	return {"source": entry, "data": entry.data, "durability": entry.durability}


func _rebuild() -> void:
	if not is_node_ready() or _inventory == null:
		return
	_tiles.clear()
	_rebuild_grid(Side.PLAYER)
	_rebuild_nearby()
	_rebuild_equipment()


func _rebuild_nearby() -> void:
	_container_frame.visible = _container != null
	_equip_frame.visible = _container == null
	if _container:
		_rebuild_grid(Side.CONTAINER)
		return
	for child in _container_grid.get_children():
		child.queue_free()


func _rebuild_grid(side: int) -> void:
	var inventory := _inventory_for(side)
	var host := _grid_for(side)
	for child in host.get_children():
		child.queue_free()

	var cells := inventory.grid_size
	var size_text := "%d x %d" % [cells.x, cells.y]
	if side == Side.CONTAINER:
		_container_title.text = inventory.get_display_name()
		_container_size.text = size_text
		if is_trading():
			_container_size.text = "You have %d souls" % _trader.count_currency(_inventory)
	else:
		_size_label.text = size_text
	host.custom_minimum_size = Vector2(_span(cells.x), _span(cells.y))

	for y in cells.y:
		for x in cells.x:
			host.add_child(_make_cell(Vector2i(x, y)))
	for entry in inventory.get_entries():
		var tile := _make_tile(entry.data, entry.rotated, entry.durability)
		tile.position = Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
		if side == Side.CONTAINER and is_trading():
			tile.add_child(_make_price_badge(_trader.price_of(entry),
				_trader.can_afford(entry, _inventory)))
		host.add_child(tile)
		_tiles[entry] = tile


func _rebuild_equipment() -> void:
	for hand: HandSlot in _slot_boxes:
		var data := hand.get_item_data()
		_fill_slot(_slot_boxes[hand], hand, data, "empty", data != null, hand.get_durability())
	for slot in _wear_boxes:
		var worn := _equipment.get_item(slot) if _equipment else null
		var left := _equipment.get_durability(slot) if _equipment else -1
		_fill_slot(_wear_boxes[slot], _wear_boxes[slot], worn, WEAR_NAMES[slot], false, left)


func _fill_slot(
	box: Panel, key: Object, data: ItemData, empty_text: String, held: bool, durability := -1
) -> void:
	for child in box.get_children():
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = empty_cell_color
	style.set_border_width_all(2)
	style.border_color = held_border_color if held else slot_border_color
	box.add_theme_stylebox_override("panel", style)

	if data == null:
		var label := Label.new()
		label.text = empty_text
		label.modulate = Color(1, 1, 1, 0.3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var tile := _make_slot_tile(data, box.size, durability)
	box.add_child(tile)
	_tiles[key] = tile


func _make_slot_tile(data: ItemData, room: Vector2, durability := -1) -> Control:
	var rotated := false
	var cells := data.footprint(false)
	var span := Vector2(_span(cells.x), _span(cells.y))
	if span.x > room.x or span.y > room.y:
		var turned := data.footprint(true)
		var turned_span := Vector2(_span(turned.x), _span(turned.y))
		if turned_span.x <= room.x and turned_span.y <= room.y:
			rotated = true
			span = turned_span
	var tile := _make_tile(data, rotated, durability)
	var fit := minf(1.0, minf(room.x / span.x, room.y / span.y))
	tile.scale = Vector2(fit, fit)
	tile.position = ((room - span * fit) * 0.5).floor()
	return tile


func _make_cell(cell: Vector2i) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = empty_cell_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(_offset(cell.x), _offset(cell.y))
	rect.size = Vector2(cell_size, cell_size)
	return rect


func _make_tile(data: ItemData, rotated: bool = false, durability: int = -1) -> Control:
	var tile := Panel.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.clip_contents = true
	var cells := data.footprint(rotated)
	var footprint := Vector2(_span(cells.x), _span(cells.y))
	tile.size = footprint
	tile.custom_minimum_size = footprint

	var style := StyleBoxFlat.new()
	style.bg_color = type_color(data)
	style.set_border_width_all(2)
	style.border_color = item_border_color
	tile.add_theme_stylebox_override("panel", style)

	var content: Control
	if data.icon:
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content = icon
	else:
		var label := Label.new()
		label.text = data.display_name
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", item_text_color)
		content = label
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	if rotated and data.icon and cells.x != cells.y:
		var inner := Vector2(footprint.y, footprint.x) - Vector2(8, 8)
		content.size = inner
		content.pivot_offset = inner / 2.0
		content.position = (footprint - inner) / 2.0
		content.rotation = PI / 2.0
	else:
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	if data.is_weapon() and data.melee_damage() > 0:
		tile.add_child(_make_damage_badge(data.melee_damage()))
	var share := wear_share(data, durability)
	if share < 1.0:
		var track := ColorRect.new()
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.color = Color(0.06, 0.04, 0.03, 0.85)
		track.position = Vector2(3, footprint.y - 8)
		track.size = Vector2(footprint.x - 6, 5)
		tile.add_child(track)
		var wear := ColorRect.new()
		wear.name = "WearLine"
		wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wear.color = tile_worn_color if share < 0.5 else tile_wear_color
		wear.position = track.position + Vector2(1, 1)
		wear.size = Vector2(maxf(roundf((footprint.x - 8) * share), 2), 3)
		tile.add_child(wear)
	return tile


func type_color(data: ItemData) -> Color:
	match data.item_type:
		ItemData.Type.WEAPON:
			return weapon_color
		ItemData.Type.MASK:
			return mask_color
		ItemData.Type.HEAD, ItemData.Type.BODY, ItemData.Type.PACK:
			return wearable_color
	return item_color


static func wear_share(data: ItemData, durability: int) -> float:
	if data.durability <= 0 or durability < 0:
		return 1.0
	return clampf(float(durability) / data.durability, 0.0, 1.0)


func _make_damage_badge(damage: int) -> Label:
	var label := Label.new()
	label.name = "DamageBadge"
	label.text = str(damage)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", damage_text_color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(4, 1)
	return label


func _make_price_badge(price: int, affordable: bool) -> Label:
	var label := Label.new()
	label.name = "PriceBadge"
	label.text = "%d souls" % price if price != 1 else "1 soul"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color",
		price_color if affordable else price_short_color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 4)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return label


func _is_outside_window(pos: Vector2) -> bool:
	if _local_rect(_window).has_point(pos):
		return false
	if _hotbar_panel and _hotbar_panel.get_bar_rect().has_point(pos + global_position):
		return false
	return true


func _hand_at(pos: Vector2) -> HandSlot:
	if not _equip_frame.visible:
		return null
	for hand in _slot_boxes:
		if _local_rect(_slot_boxes[hand]).has_point(pos):
			return hand
	return null


func _wear_at(pos: Vector2) -> int:
	if _equipment == null or not _equip_frame.visible:
		return Equipment.NO_SLOT
	for slot in _wear_boxes:
		if _local_rect(_wear_boxes[slot]).has_point(pos):
			return slot
	return Equipment.NO_SLOT


func _hotbar_at(pos: Vector2) -> int:
	if _hotbar == null or _hotbar_panel == null:
		return HotbarPanel.NO_SLOT
	return _hotbar_panel.slot_index_at(pos + global_position)


func _dim_tile(key: Object) -> void:
	var tile := _tiles.get(key) as Control
	if tile:
		tile.modulate.a = 0.3


func _local_rect(control: Control) -> Rect2:
	return Rect2(control.global_position - global_position, control.size)


func _grid_origin(side: int) -> Vector2:
	return _grid_for(side).global_position - global_position


func _cell_at(side: int, pos: Vector2) -> Vector2i:
	var local := pos - _grid_origin(side)
	if local.x < 0.0 or local.y < 0.0:
		return NO_CELL
	var pitch := cell_size + cell_gap
	var cell := Vector2i(int(local.x) / pitch, int(local.y) / pitch)
	var cells := _inventory_for(side).grid_size
	if cell.x >= cells.x or cell.y >= cells.y:
		return NO_CELL
	return cell


func _offset(index: int) -> int:
	return index * (cell_size + cell_gap)


func _span(count: int) -> int:
	return count * cell_size + maxi(count - 1, 0) * cell_gap
