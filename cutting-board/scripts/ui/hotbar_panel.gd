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
## The worn-mask square between the hands: its bare-face glyph and its wear bar.
@export var bare_face_color := Color(1, 1, 1, 0.25)
@export var wear_color := Color(0.85, 0.3, 0.2, 0.9)

const NO_SLOT := -1

@onready var _groups: HBoxContainer = %Groups

var _hotbar: Hotbar
## The drawn square of each slot, by slot index, so the inventory screen can hit-test
## and highlight them without knowing how the bar is laid out.
var _boxes: Array[Control] = []
var _equipment: Equipment
## The square between the two hands showing the face the player wears. Built once and
## put back between the groups on every rebuild; it is not one of _boxes, so nothing can
## be dragged onto it.
var _mask_box: PanelContainer
var _mask_icon: TextureRect
var _mask_shadow: TextureRect
var _bare_label: Control
var _wear_bar: ColorRect


func _ready() -> void:
	_groups.add_theme_constant_override("separation", group_gap)
	_build_mask_box()


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


## Shows the face in this loadout's Mask slot between the hands, kept in step with it.
func bind_equipment(equipment: Equipment) -> void:
	if _equipment == equipment:
		return
	if _equipment and _equipment.changed.is_connected(_refresh_mask):
		_equipment.changed.disconnect(_refresh_mask)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(_refresh_mask)
	_refresh_mask()


## The texture the mask square shows, or null for a bare face.
func get_mask_texture() -> Texture2D:
	return _mask_icon.texture if _mask_icon and _mask_icon.visible else null


func is_bare_face() -> bool:
	return _bare_label != null and _bare_label.visible


func is_mask_worn_down() -> bool:
	return _wear_bar != null and _wear_bar.visible


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
	if _mask_box.get_parent() == _groups:
		_groups.remove_child(_mask_box)
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
		if first == 0:
			_groups.add_child(_mask_box)


## One square: the key it answers to in the corner, and whatever it is linked to filling
## the rest of it. A square whose item is in hand right now is outlined, which is the
## only state the bar has to tell apart â€” everything else is simply "assigned or not".
func _make_slot(index: int) -> Control:
	var slot := _hotbar.get_slot(index)
	var held := slot != null and slot.is_held()

	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(slot_size, slot_size)
	# The styles draw their outline in their expand margin, outside the square, so the
	# square itself â€” what the inventory screen hit-tests â€” is the dark fill alone.
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


## The worn-mask marker: just the face's icon floating between the hands (no slot frame,
## it is a readout, not a button), a faint face outline for a bare face, and a thin red
## line under the icon once the mask is under half its wear.
func _build_mask_box() -> void:
	_mask_box = PanelContainer.new()
	_mask_box.name = "MaskBox"
	_mask_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_box.custom_minimum_size = Vector2(slot_size, slot_size)
	# Level with the squares, clear of the captions under them.
	_mask_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mask_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# A dark copy of the icon, nudged down-right, keeps it readable on bright ground.
	var shadow_holder := MarginContainer.new()
	shadow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_holder.add_theme_constant_override("margin_left", 1)
	shadow_holder.add_theme_constant_override("margin_top", 1)
	_mask_shadow = _make_mask_rect()
	_mask_shadow.modulate = Color(0, 0, 0, 0.45)
	shadow_holder.add_child(_mask_shadow)
	_mask_box.add_child(shadow_holder)

	_mask_icon = _make_mask_rect()
	_mask_box.add_child(_mask_icon)

	_bare_label = Control.new()
	_bare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bare_label.draw.connect(_draw_bare_face)
	_mask_box.add_child(_bare_label)

	_wear_bar = ColorRect.new()
	_wear_bar.color = wear_color
	_wear_bar.custom_minimum_size = Vector2(0, 1)
	_wear_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wear_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	_wear_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_box.add_child(_wear_bar)
	_refresh_mask()


func _make_mask_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(slot_size - 4, slot_size - 4)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A faint face outline (head and two eyes), centred in the marker.
func _draw_bare_face() -> void:
	var c := _bare_label.size / 2.0
	var r := minf(_bare_label.size.x, _bare_label.size.y) * 0.3
	var eye := maxf(r * 0.12, 0.75)
	_bare_label.draw_arc(c, r, 0.0, TAU, 24, bare_face_color, 1.0)
	_bare_label.draw_circle(c + Vector2(-r * 0.38, -r * 0.15), eye, bare_face_color)
	_bare_label.draw_circle(c + Vector2(r * 0.38, -r * 0.15), eye, bare_face_color)


func _refresh_mask() -> void:
	if _mask_box == null:
		return
	var mask: ItemData = _equipment.get_item(Equipment.Slot.MASK) if _equipment else null
	_mask_icon.texture = mask.icon if mask else null
	_mask_icon.visible = mask != null
	_mask_shadow.texture = _mask_icon.texture
	_mask_shadow.visible = mask != null
	_bare_label.visible = mask == null
	var share := 1.0
	if mask and mask.durability > 0:
		share = clampf(float(_equipment.get_durability(Equipment.Slot.MASK)) / mask.durability, 0.0, 1.0)
	_wear_bar.visible = share < 0.5
	_wear_bar.custom_minimum_size.x = roundi((slot_size - 8) * share)
