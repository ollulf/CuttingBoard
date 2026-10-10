class_name HotbarPanel
extends Control

@export var slot_size := 36
@export var slot_gap := 4
@export var group_gap := 28
@export var caption_gap := 4
@export var font_size := 16
@export var slot_style: StyleBox = preload("res://resources/ui/hotbar_slot.tres")
@export var held_slot_style: StyleBox = preload("res://resources/ui/hotbar_slot_held.tres")
@export var item_color := Color(0.86, 0.68, 0.36, 0.85)
@export var key_color := Color(1, 1, 1, 0.55)
@export var caption_color := Color(1, 1, 1, 0.45)
@export var mask_scale := 2
@export var wear_color := Color(0.85, 0.3, 0.2, 0.9)
@export var slot_wear_color := Color(0.9, 0.8, 0.55, 0.8)

const NO_SLOT := -1

@onready var _groups: HBoxContainer = %Groups

var _hotbar: Hotbar
var _boxes: Array[Control] = []
var _equipment: Equipment
var _mask_box: PanelContainer
var _mask_icon: TextureRect
var _mask_shadow: TextureRect
var _wear_bar: ColorRect
var _slot_wear: Array[ColorRect] = []


func _ready() -> void:
	_groups.add_theme_constant_override("separation", group_gap)
	_build_mask_box()


func bind(hotbar: Hotbar) -> void:
	if _hotbar == hotbar:
		return
	if _hotbar and _hotbar.changed.is_connected(_rebuild):
		_hotbar.changed.disconnect(_rebuild)
	_hotbar = hotbar
	if _hotbar:
		_hotbar.changed.connect(_rebuild)
	_rebuild()


func bind_equipment(equipment: Equipment) -> void:
	if _equipment == equipment:
		return
	if _equipment and _equipment.changed.is_connected(_refresh_mask):
		_equipment.changed.disconnect(_refresh_mask)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(_refresh_mask)
	_refresh_mask()


func get_mask_texture() -> Texture2D:
	return _mask_icon.texture if _mask_icon and _mask_icon.visible else null


func is_bare_face() -> bool:
	return _mask_icon != null and not _mask_icon.visible


func is_mask_worn_down() -> bool:
	return _wear_bar != null and _wear_bar.visible


func slot_index_at(global_pos: Vector2) -> int:
	for index in _boxes.size():
		if slot_rect(index).has_point(global_pos):
			return index
	return NO_SLOT


func slot_rect(index: int) -> Rect2:
	if index < 0 or index >= _boxes.size():
		return Rect2()
	var box := _boxes[index]
	return Rect2(box.global_position, box.size)


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
	_slot_wear.clear()
	if _hotbar == null:
		return

	var per_hand := Hotbar.SLOTS_PER_HAND
	_boxes.resize(_hotbar.slot_count())
	_slot_wear.resize(_hotbar.slot_count())
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


func _make_slot(index: int) -> Control:
	var slot := _hotbar.get_slot(index)
	var held := slot != null and slot.is_held()

	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(slot_size, slot_size)
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
	box.add_child(key)

	var wear := ColorRect.new()
	wear.custom_minimum_size = Vector2(0, 2)
	wear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wear.size_flags_vertical = Control.SIZE_SHRINK_END
	wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(wear)
	_slot_wear[index] = wear
	_refresh_slot_wear(index)
	return box


func _process(_delta: float) -> void:
	for index in _slot_wear.size():
		_refresh_slot_wear(index)


func get_slot_wear(index: int) -> float:
	var slot := _hotbar.get_slot(index) if _hotbar else null
	if slot == null or slot.data == null or slot.data.durability <= 0:
		return 1.0
	var left := slot.get_durability()
	return clampf(float(left) / slot.data.durability, 0.0, 1.0) if left >= 0 else 1.0


func _refresh_slot_wear(index: int) -> void:
	var wear := _slot_wear[index] if index < _slot_wear.size() else null
	if wear == null:
		return
	var share := get_slot_wear(index)
	wear.visible = share < 1.0
	wear.color = wear_color if share < 0.5 else slot_wear_color
	wear.custom_minimum_size.x = maxi(roundi((slot_size - 4) * share), 2)


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
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.add_theme_font_size_override("font_size", roundi(font_size * 0.5))
	label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(label)
	return tile


func _build_mask_box() -> void:
	var side := slot_size * mask_scale
	_mask_box = PanelContainer.new()
	_mask_box.name = "MaskBox"
	_mask_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_box.custom_minimum_size = Vector2(side, side)
	_mask_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mask_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var shadow_holder := MarginContainer.new()
	shadow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_holder.add_theme_constant_override("margin_left", mask_scale)
	shadow_holder.add_theme_constant_override("margin_top", mask_scale)
	_mask_shadow = _make_mask_rect(side)
	_mask_shadow.modulate = Color(0, 0, 0, 0.45)
	shadow_holder.add_child(_mask_shadow)
	_mask_box.add_child(shadow_holder)

	_mask_icon = _make_mask_rect(side)
	_mask_box.add_child(_mask_icon)

	_wear_bar = ColorRect.new()
	_wear_bar.color = wear_color
	_wear_bar.custom_minimum_size = Vector2(0, mask_scale)
	_wear_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wear_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	_wear_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_box.add_child(_wear_bar)
	_refresh_mask()


func _make_mask_rect(side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(side - 4 * mask_scale, side - 4 * mask_scale)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _refresh_mask() -> void:
	if _mask_box == null:
		return
	var mask: ItemData = _equipment.get_item(Equipment.Slot.MASK) if _equipment else null
	_mask_icon.texture = mask.icon if mask else null
	_mask_icon.visible = mask != null
	_mask_shadow.texture = _mask_icon.texture
	_mask_shadow.visible = mask != null
	var share := 1.0
	if mask and mask.durability > 0:
		share = clampf(float(_equipment.get_durability(Equipment.Slot.MASK)) / mask.durability, 0.0, 1.0)
	_wear_bar.visible = share < 0.5
	_wear_bar.custom_minimum_size.x = roundi((slot_size - 8) * mask_scale * share)
