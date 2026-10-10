class_name MendOverlay
extends ColorRect

@export var glow_per_heal := 1.5
@export_range(0.0, 1.0) var min_glow := 0.2
@export_range(0.0, 1.0) var max_glow := 0.45
@export var glow_fade := 0.5

var _health: Health
var _glow := 0.0
var _last_current := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


func bind(health: Health) -> void:
	_health = health
	_health.changed.connect(_on_changed)
	_last_current = _health.get_current()


func _process(delta: float) -> void:
	_glow *= exp(-delta / glow_fade)
	if _glow < 0.01:
		_glow = 0.0
	_apply()


func get_glow() -> float:
	return _glow


func _apply() -> void:
	visible = _glow > 0.0
	if not visible:
		return
	material.set_shader_parameter("amount", _glow)
	var retro := PsxScreen.enabled
	var blocks := 1.0
	if retro:
		var render := PsxScreen.get_render_size()
		blocks = maxf(1.0, roundf(get_viewport_rect().size.y / maxf(render.y, 1.0)))
	material.set_shader_parameter("pixel_size", blocks)
	material.set_shader_parameter("dither", retro)


func _on_changed(current: int, maximum: int) -> void:
	var gained := current - _last_current
	_last_current = current
	if current <= 0:
		_glow = 0.0
		return
	if gained <= 0:
		return
	var share := float(gained) / maxf(float(maximum), 1.0)
	_glow = clampf(maxf(_glow, min_glow + share * glow_per_heal), 0.0, max_glow)
