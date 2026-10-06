class_name HotbarPanel
extends Control

## The bar across the bottom of the screen: two groups of three numbered squares, one
## group per hand. It is on screen the whole time, inventory open or shut, because what
## it is for is knowing at a glance what 1 to 6 will put in your hands.
##
## The bar only draws; it holds nothing and takes no input. Assigning items to it is
## done by dragging them there from the inventory screen, which owns the mouse while it
## is open, and which hit-tests against the squares this panel reports. That is why
## every control here ignores the mouse: a square that swallowed clicks would break the
## drag it is meant to receive.

## Sizes are window pixels at 1280x720, where each pixel of the 640x360 retro screen is
## two of them; everything here is a multiple of two so the bar's lines and text sit on
## that grid and stay as crisp as the world behind them.

## Edge length of one hotbar square, in pixels.
@export var slot_size := 36
## Space between neighbouring squares. The outline is drawn just outside each square,
## so at this gap two outlines meet and read as one double line.
@export var slot_gap := 4
## Gap between the left hand's group of squares and the right hand's.
@export var group_gap := 28
## Space between a hand's squares and its caption beneath them.
@export var caption_gap := 4
## Cubix is drawn on whole pixels at multiples of 8; 16 puts one font pixel on one
## screen pixel.
@export var font_size := 16
## A square, and a square whose item is out in the hand right now.
@export var slot_style: StyleBox = preload("res://resources/ui/hotbar_slot.tres")
@export var held_slot_style: StyleBox = preload("res://resources/ui/hotbar_slot_held.tres")
@export var item_color := Color(0.86, 0.68, 0.36, 0.85)
@export var key_color := Color(1, 1, 1, 0.55)
@export var caption_color := Color(1, 1, 1, 0.45)

const NO_SLOT := -1

@onready var _groups: HBoxContainer = %Groups

var _hotbar: Hotbar
## The drawn square of each slot, by slot index, so the inventory screen can hit-test
## and highlight them without knowing how the bar is laid out.
var _boxes: Array[Control] = []


func _ready() -> void:
	_groups.add_theme_constant_override("separation", group_gap)


## Points the bar at a hotbar and keeps it in step with it.
func bind(hotbar: Hotbar) -> void:
	if _hotbar == hotbar:
		return
	if _hotbar and _hotbar.changed.is_connected(_rebuild):
		_hotbar.changed.disconnect(_rebuild)
	_hotbar = hotbar
	if _hotbar:
		_hotbar.changed.connect(_rebuild)
	_rebuild()


## The slot under a point in screen coordinates, or NO_SLOT where there is none.
func slot_index_at(global_pos: Vector2) -> int:
	for index in _boxes.size():
		if slot_rect(index).has_point(global_pos):
			return index
	return NO_SLOT


## One square's rectangle in screen coordinates, for drawing a drop hint over it.
func slot_rect(index: int) -> Rect2:
	if index < 0 or index >= _boxes.size():
		return Rect2()
	var box := _boxes[index]
	return Rect2(box.global_position, box.size)


## The whole bar's rectangle in screen coordinates. The inventory screen counts this as
## part of its window, so dragging an item down onto the bar is an assignment rather
## than a throw out into the world.
func get_bar_rect() -> Rect2:
	if _boxes.is_empty():
		return Rect2()
	var rect := slot_rect(0)
	for index in range(1, _boxes.size()):
		rect = rect.merge(slot_rect(index))
	return rect.grow(10.0)


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in _groups.get_children():
		child.queue_free()
	_boxes.clear()
	if _hotbar == null:
		return

	var per_hand := Hotbar.SLOTS_PER_HAND
	_boxes.resize(_hotbar.slot_count())
	for first in range(0, _hotbar.slot_count(), per_hand):
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", caption_gap)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", slot_gap)
		for index in range(first, mini(first + per_hand, _hotbar.slot_count())):
			var box := _make_slot(index)
			row.add_child(box)
			_boxes[index] = box
		column.add_child(row)

		var caption := Label.new()
		caption.text = _hotbar.get_hand_name(first)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", font_size)
		caption.add_theme_color_override("font_color", caption_color)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)

		_groups.add_child(column)


## One square: the key it answers to in the corner, and whatever it is linked to filling
## the rest of it. A square whose item is in hand right now is outlined, which is the
## only state the bar has to tell apart — everything else is simply "assigned or not".
func _make_slot(index: int) -> Control:
	var slot := _hotbar.get_slot(index)
	var held := slot != null and slot.is_held()

	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(slot_size, slot_size)
	# The styles draw their outline in their expand margin, outside the square, so the
	# square itself — what the inventory screen hit-tests — is the dark fill alone.
	box.add_theme_stylebox_override("panel", held_slot_style if held else slot_style)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(centre)
	if slot and slot.data:
		centre.add_child(_make_item(slot.data))

	var key := Label.new()
	key.text = str(index + 1)
	key.add_theme_font_size_override("font_size", font_size)
	key.add_theme_color_override("font_color", key_color)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A second child of the PanelContainer, which lays both out over the same rectangle,
	# so the number sits in the corner on top of the item rather than beside it.
	box.add_child(key)
	return box


## The item's face on the bar: its icon, or its name where it has none, filling the
## square but for a one-pixel frame of the dark fill around it.
func _make_item(data: ItemData) -> Control:
	var inner := slot_size - 4
	if data.icon:
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.custom_minimum_size = Vector2(inner, inner)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(inner, inner)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = item_color
	style.anti_aliasing = false
	style.set_content_margin_all(0)
	tile.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = data.display_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Along the bottom, clear of the key number in the top corner.
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	# Half the bar's text size, the smallest Cubix still draws on whole pixels: a name
	# at full size would not fit across one square.
	label.add_theme_font_size_override("font_size", roundi(font_size * 0.5))
	label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(label)
	return tile
