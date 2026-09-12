class_name InventoryPanel
extends Control

## Full-screen view of one Inventory's grid. It binds to any Inventory component, so the
## same panel serves the player, a chest or a wagon; only the grid dimensions differ.
## Items are dragged with the left mouse button: a plain drag carries the whole stack,
## holding Shift peels a single item off it.

## Edge length of one inventory square, in pixels.
@export var cell_size := 44
## Gap drawn between squares, in pixels.
@export var cell_gap := 2
@export var empty_cell_color := Color(1, 1, 1, 0.07)
@export var item_color := Color(0.86, 0.68, 0.36, 0.85)
@export var valid_drop_color := Color(0.45, 0.85, 0.45, 0.35)
@export var invalid_drop_color := Color(0.9, 0.35, 0.3, 0.35)

const NO_CELL := Vector2i(-1, -1)

@onready var _title: Label = $Center/Frame/Margin/Rows/Title
@onready var _grid: Control = $Center/Frame/Margin/Rows/Grid

var _inventory: Inventory
## Tiles by the entry they were built for, so a dragged item can be dimmed in place.
var _tiles: Dictionary = {}

var _drag_entry: InventoryEntry
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
	return _drag_entry != null


## Shift peels one item off; without it, or on a stack of one, the whole stack travels.
func _begin_drag(pos: Vector2, split: bool) -> void:
	var cell := _cell_at(pos)
	if cell == NO_CELL:
		return
	var entry := _inventory.get_entry_at(cell)
	if entry == null:
		return
	_drag_entry = entry
	_drag_count = 1 if split and entry.count > 1 else entry.count
	_drag_grab_cell = cell - entry.origin
	_drag_grab_pixels = pos - _grid_origin() - Vector2(_offset(entry.origin.x), _offset(entry.origin.y))

	var tile := _tiles.get(entry) as Control
	if tile:
		# A whole-stack drag leaves an empty hole; a split leaves the remainder visible.
		tile.modulate.a = 0.3 if _drag_count == entry.count else 1.0

	_ghost = _make_tile(entry.data, _drag_count)
	_ghost.modulate.a = 0.75
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)

	_drop_hint = ColorRect.new()
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_hint)
	move_child(_drop_hint, _ghost.get_index())

	_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	_ghost.position = pos - _drag_grab_pixels

	var cell := _cell_at(pos)
	if cell == NO_CELL:
		_drop_hint.hide()
		return
	var origin := cell - _drag_grab_cell
	var size := _drag_entry.get_size()
	_drop_hint.position = _grid_origin() + Vector2(_offset(origin.x), _offset(origin.y))
	_drop_hint.size = Vector2(_span(size.x), _span(size.y))
	_drop_hint.color = valid_drop_color if _can_drop_at(cell) else invalid_drop_color
	_drop_hint.show()


func _end_drag(pos: Vector2) -> void:
	if not _is_dragging():
		return
	var entry := _drag_entry
	var count := _drag_count
	var grab := _drag_grab_cell
	var cell := _cell_at(pos)
	_cancel_drag()
	if cell == NO_CELL:
		return
	# Dropping onto a matching stack pours into it; anywhere else is a plain relocation,
	# which silently fails and leaves the item put if the destination is blocked.
	var target := _inventory.get_entry_at(cell)
	if target and target != entry and _inventory.merge(entry, target, count):
		return
	_inventory.move_to(entry, cell - grab, count)


## Clears drag state and its overlays; safe to call when no drag is running.
func _cancel_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _drop_hint:
		_drop_hint.queue_free()
		_drop_hint = null
	var tile := _tiles.get(_drag_entry) as Control
	if tile:
		tile.modulate.a = 1.0
	_drag_entry = null
	_drag_count = 0


func _can_drop_at(cell: Vector2i) -> bool:
	var target := _inventory.get_entry_at(cell)
	if target and target != _drag_entry and _inventory.can_merge(_drag_entry, target, _drag_count):
		return true
	# Only a whole-stack move may reuse the squares the item is leaving behind.
	var ignore := _drag_entry if _drag_count == _drag_entry.count else null
	return _inventory.is_region_free(cell - _drag_grab_cell, _drag_entry.get_size(), ignore)


# --- Layout -----------------------------------------------------------------------

func _rebuild() -> void:
	if not is_node_ready() or _inventory == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	_tiles.clear()

	var grid := _inventory.grid_size
	_title.text = "Inventory  (%d x %d)    drag to move · shift-drag takes one" % [grid.x, grid.y]
	_grid.custom_minimum_size = Vector2(_span(grid.x), _span(grid.y))

	for y in grid.y:
		for x in grid.x:
			_grid.add_child(_make_cell(Vector2i(x, y)))
	for entry in _inventory.get_entries():
		var tile := _make_tile(entry.data, entry.count)
		tile.position = Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
		_grid.add_child(tile)
		_tiles[entry] = tile


func _make_cell(cell: Vector2i) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = empty_cell_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(_offset(cell.x), _offset(cell.y))
	rect.size = Vector2(cell_size, cell_size)
	return rect


## Builds one item tile sized to its footprint. Callers place it: the grid positions it
## on a cell, a drag hands it to the cursor.
func _make_tile(data: ItemData, count: int) -> Control:
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tile covers its whole footprint including the gaps between the squares it spans.
	tile.size = Vector2(_span(data.grid_size.x), _span(data.grid_size.y))

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
