class_name StaminaBar
extends Control

const FILL := Color("#c9a24e")
const FILL_HI := Color("#ecc874")
const EMPTY := Color("#8a6a2e")
const BACKING := Color(0.027, 0.02, 0.039, 0.75)
const OUTLINE := Color(0.027, 0.02, 0.039, 0.95)

@export var design_height := 360
@export var margin := Vector2i(21, 22)
@export var bar_size := Vector2i(86, 2)
@export var fade_time := 0.4

var _stamina: Stamina
var _ratio := 1.0
var _fade: Tween
var _px := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.size_changed.connect(_fit_to_window)
	_fit_to_window()
	_stamina = _find_owner_stamina()
	if _stamina:
		_stamina.changed.connect(_on_changed)
	modulate.a = 0.0


func _on_changed(current: float, maximum: float) -> void:
	var was_full := _ratio >= 1.0
	_ratio = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	var full := _ratio >= 1.0
	if full != was_full:
		if _fade:
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0 if full else 1.0, fade_time)
	queue_redraw()


func _fit_to_window() -> void:
	var window := get_tree().root.get_visible_rect().size
	_px = maxi(1, roundi(window.y / maxi(design_height, 1)))
	queue_redraw()


func _find_owner_stamina() -> Stamina:
	var node := get_parent()
	while node:
		for child in node.get_children():
			if child is Stamina:
				return child
		node = node.get_parent()
	return null


func _draw() -> void:
	var bar := Rect2(margin.x, size.y / _px - margin.y, bar_size.x, bar_size.y)
	_rect(bar.grow(1), OUTLINE)
	_rect(bar, BACKING)
	var fill_w := roundf(bar.size.x * _ratio)
	if fill_w > 0:
		var color := FILL if _ratio > 0.2 else EMPTY
		_rect(Rect2(bar.position, Vector2(fill_w, bar.size.y)), color)
		_rect(Rect2(bar.position, Vector2(fill_w, 1)), FILL_HI if _ratio > 0.2 else color)


func _rect(r: Rect2, color: Color) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	draw_rect(Rect2(r.position * _px, r.size * _px), color)
