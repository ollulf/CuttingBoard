class_name InventoryPanel
extends Control

## The inventory screen: a grid of squares beside a column of equipment slots. It binds
## to any Inventory component, so the same screen serves the player, a chest or a wagon.
##
## Both halves store ItemData records, but they mean different things. A grid square is
## storage. An equipment slot is a loadout: the item assigned there is not in the
## player's hand yet — a click draws it, spawning the real world object, which is what
## keeps an equipped hammer identical to one picked up off the ground. So the hands stay
## free for carrying things while a weapon waits equipped.
##
## Items are dragged with the left mouse button: a plain drag carries the whole stack,
## Shift peels a single item off it, and a drag clear of the window drops into the world.

## Edge length of one inventory square, in pixels.
@export var cell_size := 44
## Gap drawn between squares, in pixels.
@export var cell_gap := 2
## Size of an equipment slot, measured in inventory squares.
@export var equip_slot_cells := Vector2i(3, 2)
@export var empty_cell_color := Color(1, 1, 1, 0.07)
@export var item_color := Color(0.86, 0.68, 0.36, 0.85)
@export var valid_drop_color := Color(0.45, 0.85, 0.45, 0.35)
@export var invalid_drop_color := Color(0.9, 0.35, 0.3, 0.35)
## Tint of the dragged ghost once it is clear of the window and would be dropped.
@export var eject_color := Color(1.0, 0.85, 0.55, 0.9)

const NO_CELL := Vector2i(-1, -1)

## Emitted when an item is dragged clear of the window. The panel does not know how to
## put things into the world, so whoever owns this inventory performs the drop and then
## takes the items off the stack.
signal drop_requested(entry: InventoryEntry, count: int)

@onready var _frame: Control = $Center/Row/Frame
@onready var _title: Label = $Center/Row/Frame/Margin/Rows/Title
@onready var _grid: Control = $Center/Row/Frame/Margin/Rows/Grid
@onready var _equip_frame: Control = $Center/Row/EquipFrame
@onready var _slots_box: VBoxContainer = $Center/Row/EquipFrame/Margin/Rows/Slots

var _inventory: Inventory
var _interactor: Interactor
var _hands: Array[HandSlot] = []

## Tiles by the entry or hand they were built for, so a dragged item can be dimmed.
var _tiles: Dictionary = {}
## The clickable box of each equipment slot, by hand.
var _slot_boxes: Dictionary = {}

## A drag carries one item, from either half of the screen: _drag_entry is set when it
## came out of the grid and _drag_hand when it came out of an equipment slot.
var _drag_data: ItemData
var _drag_entry: InventoryEntry
var _drag_hand: HandSlot
var _drag_count := 0
## Which square of the item the cursor grabbed, and where inside it, in pixels. The
## pixel offset is what keeps the ghost from snapping under the cursor on pick-up.
var _drag_grab_cell := Vector2i.ZERO
var _drag_grab_pixels := Vector2.ZERO
var _ghost: Control
var _drop_hint: ColorRect


func _ready() -> void:
	hide()


## Points the panel at an inventory and keeps it in step with that inventory's contents.
func bind(inventory: Inventory) -> void:
	if _inventory == inventory:
		return
	if _inventory and _inventory.changed.is_connected(_rebuild):
		_inventory.changed.disconnect(_rebuild)
	_inventory = inventory
	if _inventory:
		_inventory.changed.connect(_rebuild)
	_rebuild()


## Gives the panel the equipment slots to show. They are the wearer's own hand slots, and
## the interactor is what turns a record into a world object and back again.
func bind_equipment(hands: Array[HandSlot], interactor: Interactor) -> void:
	_hands = hands
	_interactor = interactor
	for hand in _hands:
		hand.item_held.connect(_rebuild.unbind(1))
		hand.item_released.connect(_rebuild.unbind(1))
		hand.equipped_changed.connect(_rebuild.unbind(1))
	_rebuild()


## The panel handles its own key so the toggle still works once the panel has released
## the mouse — the player controller ignores input while the cursor is free.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		# Escape backs out of a drag first, and only closes the panel when idle.
		if _is_dragging():
			_cancel_drag()
		else:
			close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position, event.shift_pressed)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _is_dragging():
		_update_drag(event.position)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _inventory == null:
		return
	_rebuild()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_cancel_drag()
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Dragging ---------------------------------------------------------------------

func _is_dragging() -> bool:
	return _drag_data != null


## Shift peels one item off a stack; without it, or on a stack of one, the whole stack
## travels. An equipped item is always dragged whole — there is only ever one of it.
func _begin_drag(pos: Vector2, split: bool) -> void:
	var hand := _hand_at(pos)
	if hand:
		_begin_hand_drag(hand, pos)
		return
	var cell := _cell_at(pos)
	if cell == NO_CELL:
		return
	var entry := _inventory.get_entry_at(cell)
	if entry == null:
		return
	_drag_entry = entry
	_drag_data = entry.data
	_drag_count = 1 if split and entry.count > 1 else entry.count
	_drag_grab_cell = cell - entry.origin
	_drag_grab_pixels = pos - _grid_origin() - Vector2(_offset(entry.origin.x), _offset(entry.origin.y))

	var tile := _tiles.get(entry) as Control
	if tile:
		# A whole-stack drag leaves an empty hole; a split leaves the remainder visible.
		tile.modulate.a = 0.3 if _drag_count == entry.count else 1.0
	_start_ghost(pos)


func _begin_hand_drag(hand: HandSlot, pos: Vector2) -> void:
	if _interactor == null or hand.equipped == null:
		return
	var data: ItemData = hand.equipped
	if data == null:
		return
	_drag_hand = hand
	_drag_data = data
	_drag_count = 1
	_drag_grab_cell = Vector2i.ZERO
	# Grabbed in the middle, since an equipment slot has no square the cursor landed on.
	_drag_grab_pixels = Vector2(_span(data.grid_size.x), _span(data.grid_size.y)) * 0.5
	var tile := _tiles.get(hand) as Control
	if tile:
		tile.modulate.a = 0.3
	_start_ghost(pos)


func _start_ghost(pos: Vector2) -> void:
	_ghost = _make_tile(_drag_data, _drag_count)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)

	_drop_hint = ColorRect.new()
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_hint)
	move_child(_drop_hint, _ghost.get_index())

	_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	_ghost.position = pos - _drag_grab_pixels
	# Clear of the window the item is on its way out, so the ghost says so.
	_ghost.modulate = eject_color if _is_outside_window(pos) else Color(1, 1, 1, 0.75)

	var hand := _hand_at(pos)
	if hand:
		var box: Control = _slot_boxes[hand]
		_drop_hint.position = box.global_position - global_position
		_drop_hint.size = box.size
		_drop_hint.color = valid_drop_color if _accepts(hand, _drag_data, _drag_hand) else invalid_drop_color
		_drop_hint.show()
		return

	var cell := _cell_at(pos)
	if cell == NO_CELL:
		_drop_hint.hide()
		return
	var origin := cell - _drag_grab_cell
	var size := _drag_data.grid_size
	_drop_hint.position = _grid_origin() + Vector2(_offset(origin.x), _offset(origin.y))
	_drop_hint.size = Vector2(_span(size.x), _span(size.y))
	_drop_hint.color = valid_drop_color if _can_drop_at(cell) else invalid_drop_color
	_drop_hint.show()


func _end_drag(pos: Vector2) -> void:
	if not _is_dragging():
		return
	var data := _drag_data
	var entry := _drag_entry
	var from_hand := _drag_hand
	var count := _drag_count
	var grab := _drag_grab_cell
	var cell := _cell_at(pos)
	var target_hand := _hand_at(pos)
	var outside := _is_outside_window(pos)
	_cancel_drag()

	if target_hand:
		_drop_on_hand(target_hand, data, entry, from_hand)
		return
	if outside:
		# Released clear of the window: out into the world it goes. An equipped item is
		# already a world object, so it is simply let go rather than rebuilt.
		if from_hand:
			_drop_equipped_to_world(from_hand, data)
		else:
			drop_requested.emit(entry, count)
		return
	if cell == NO_CELL:
		# Still over the window but off the grid — a miss, not a drop. The item stays.
		return
	if from_hand:
		_unequip_to_grid(from_hand, data, cell - grab)
		return
	# Dropping onto a matching stack pours into it; anywhere else is a plain relocation,
	# which silently fails and leaves the item put if the destination is blocked.
	var target := _inventory.get_entry_at(cell)
	if target and target != entry and _inventory.merge(entry, target, count):
		return
	_inventory.move_to(entry, cell - grab, count)


func _drop_on_hand(hand: HandSlot, data: ItemData, entry: InventoryEntry, from_hand: HandSlot) -> void:
	if not _accepts(hand, data, from_hand):
		return
	if from_hand:
		_interactor.move_equipped(from_hand, hand)
		return
	# Equipping takes exactly one off the stack, whatever the drag was carrying.
	if hand.equip(data):
		_inventory.remove(entry, 1)


## Banks an equipped item back into the grid, preferring the square it was dropped on
## and falling back to anywhere it fits. The slot is only cleared once the record is
## safely stored, so a full inventory leaves the item equipped rather than losing it.
func _unequip_to_grid(hand: HandSlot, data: ItemData, origin: Vector2i) -> void:
	if data == null:
		return
	if _inventory.add_at(data, origin) or _inventory.add(data):
		# Anything already drawn is destroyed: the record now lives in the grid.
		if hand.is_drawn():
			_interactor.consume_held(hand)
		hand.unequip()


## Dragging an equipped item clear of the window puts it into the world: a drawn object
## is simply let go, and one still waiting in the slot is rebuilt out there.
func _drop_equipped_to_world(hand: HandSlot, data: ItemData) -> void:
	if hand.is_drawn():
		_interactor.drop_hand(hand)
		return
	if _interactor.drop_item(data, 1) > 0:
		hand.unequip()


## Clears drag state and its overlays; safe to call when no drag is running.
func _cancel_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _drop_hint:
		_drop_hint.queue_free()
		_drop_hint = null
	for key in [_drag_entry, _drag_hand]:
		var tile := _tiles.get(key) as Control
		if tile:
			tile.modulate.a = 1.0
	_drag_data = null
	_drag_entry = null
	_drag_hand = null
	_drag_count = 0


## Whether an equipment slot will take this item: it must be empty and the item must be
## the type that slot equips.
func _accepts(hand: HandSlot, data: ItemData, from_hand: HandSlot) -> bool:
	if hand == null or data == null or hand == from_hand or hand.equipped != null:
		return false
	return data.item_type == hand.equips


func _can_drop_at(cell: Vector2i) -> bool:
	if _drag_hand:
		# Coming out of a hand, so nothing is vacating a square: it just has to fit.
		return _inventory.is_region_free(cell - _drag_grab_cell, _drag_data.grid_size)
	var target := _inventory.get_entry_at(cell)
	if target and target != _drag_entry and _inventory.can_merge(_drag_entry, target, _drag_count):
		return true
	# Only a whole-stack move may reuse the squares the item is leaving behind.
	var ignore := _drag_entry if _drag_count == _drag_entry.count else null
	return _inventory.is_region_free(cell - _drag_grab_cell, _drag_data.grid_size, ignore)


# --- Layout -----------------------------------------------------------------------

func _rebuild() -> void:
	if not is_node_ready() or _inventory == null:
		return
	_tiles.clear()
	_rebuild_grid()
	_rebuild_equipment()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var grid := _inventory.grid_size
	_title.text = "Inventory  (%d x %d)    drag to move · shift-drag takes one · drag out to drop" % [grid.x, grid.y]
	_grid.custom_minimum_size = Vector2(_span(grid.x), _span(grid.y))

	for y in grid.y:
		for x in grid.x:
			_grid.add_child(_make_cell(Vector2i(x, y)))
	for entry in _inventory.get_entries():
		var tile := _make_tile(entry.data, entry.count)
		tile.position = Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
		_grid.add_child(tile)
		_tiles[entry] = tile


func _rebuild_equipment() -> void:
	for child in _slots_box.get_children():
		child.queue_free()
	_slot_boxes.clear()
	_equip_frame.visible = not _hands.is_empty()

	for hand in _hands:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)

		var label := Label.new()
		# The caption says when the assigned item is out in the hand rather than waiting.
		label.text = hand.display_name + ("  (in hand)" if hand.is_drawn() else "")
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)

		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(_span(equip_slot_cells.x), _span(equip_slot_cells.y))
		var style := StyleBoxFlat.new()
		style.bg_color = empty_cell_color
		style.set_corner_radius_all(4)
		box.add_theme_stylebox_override("panel", style)

		var centre := CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(centre)

		var data: ItemData = hand.equipped
		if data:
			var tile := _make_tile(data, 1)
			centre.add_child(tile)
			_tiles[hand] = tile
		else:
			var empty := Label.new()
			empty.text = ItemData.Type.keys()[hand.equips].to_lower()
			empty.modulate = Color(1, 1, 1, 0.35)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			centre.add_child(empty)

		column.add_child(box)
		_slots_box.add_child(column)
		_slot_boxes[hand] = box


func _make_cell(cell: Vector2i) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = empty_cell_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(_offset(cell.x), _offset(cell.y))
	rect.size = Vector2(cell_size, cell_size)
	return rect


## Builds one item tile sized to its footprint. Callers place it: the grid positions it
## on a cell, an equipment slot centres it, a drag hands it to the cursor. Both the size
## and the minimum are set, since only one of the two is honoured in each of those.
func _make_tile(data: ItemData, count: int) -> Control:
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tile covers its whole footprint including the gaps between the squares it spans.
	var footprint := Vector2(_span(data.grid_size.x), _span(data.grid_size.y))
	tile.size = footprint
	tile.custom_minimum_size = footprint

	var style := StyleBoxFlat.new()
	style.bg_color = item_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", style)

	if data.icon:
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
	else:
		var label := Label.new()
		label.text = data.display_name
		if count > 1:
			label.text += " x%d" % count
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
	return tile


## True when a panel-local point lies beyond the whole window, equipment column
## included. The test is the frames rather than the grid, so releasing on a margin or a
## title is a harmless miss while only a deliberate drag clear of the window throws an
## item away.
func _is_outside_window(pos: Vector2) -> bool:
	if _local_rect(_frame).has_point(pos):
		return false
	return not (_equip_frame.visible and _local_rect(_equip_frame).has_point(pos))


## The equipment slot under a panel-local point, or null if there is none.
func _hand_at(pos: Vector2) -> HandSlot:
	for hand in _slot_boxes:
		if _local_rect(_slot_boxes[hand]).has_point(pos):
			return hand
	return null


func _local_rect(control: Control) -> Rect2:
	return Rect2(control.global_position - global_position, control.size)


## The grid's top-left corner in this panel's coordinates, which is what mouse positions
## arriving in _gui_input are measured against.
func _grid_origin() -> Vector2:
	return _grid.global_position - global_position


## The square under a panel-local point, or NO_CELL when the point is off the grid.
func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - _grid_origin()
	if local.x < 0.0 or local.y < 0.0:
		return NO_CELL
	var pitch := cell_size + cell_gap
	var cell := Vector2i(int(local.x) / pitch, int(local.y) / pitch)
	var grid := _inventory.grid_size
	if cell.x >= grid.x or cell.y >= grid.y:
		return NO_CELL
	return cell


## Pixel offset of a cell index, and the pixel span of a run of cells.
func _offset(index: int) -> int:
	return index * (cell_size + cell_gap)


func _span(count: int) -> int:
	return count * cell_size + maxi(count - 1, 0) * cell_gap
