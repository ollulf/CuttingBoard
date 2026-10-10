class_name HurtOverlay
extends ColorRect

signal struck(share: float)
signal mended

@export_range(0.0, 1.0) var low_ratio := 0.3
@export_range(0.0, 1.0) var critical_ratio := 0.1
@export var flash_per_damage := 2.0
@export_range(0.0, 1.0) var min_flash := 0.35
@export var flash_fade := 0.45
@export var low_pulse_rate := 0.8
@export var critical_pulse_rate := 1.6

var _health: Health
var _flash := 0.0
var _low := 0.0
var _low_target := 0.0
var _pulse_rate := 0.0
var _phase := 0.0
var _danger := 0.0
var _last_current := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


func bind(health: Health) -> void:
	_health = health
	_health.damaged.connect(_on_damaged)
	_health.changed.connect(_on_changed)
	_health.died.connect(_on_died)
	_on_changed(_health.get_current(), _health.max_health)


func _process(delta: float) -> void:
	_flash *= exp(-delta / flash_fade)
	if _flash < 0.01:
		_flash = 0.0
	_low = move_toward(_low, _low_target, delta * 0.8)
	_phase = fmod(_phase + delta * _pulse_rate, 1.0)
	_apply()


func get_flash() -> float:
	return _flash


func get_low() -> float:
	return _low


func get_danger() -> float:
	return _danger


func _apply() -> void:
	var pulse := 0.8 + 0.2 * cos(_phase * TAU)
	var amount := clampf(maxf(_flash, _low * pulse), 0.0, 1.0)
	visible = amount > 0.0
	if not visible:
		return
	material.set_shader_parameter("amount", amount)
	_match_retro_screen()


func _on_damaged(info: DamageInfo) -> void:
	var share := float(info.amount) / maxf(float(_health.max_health), 1.0)
	_flash = clampf(maxf(_flash, min_flash + share * flash_per_damage), 0.0, 1.0)
	struck.emit(clampf(share, 0.0, 1.0))


func _on_changed(current: int, maximum: int) -> void:
	var ratio := float(current) / maxf(float(maximum), 1.0)
	var rose := _last_current >= 0 and current > _last_current
	_last_current = current
	if rose:
		mended.emit()
	if ratio >= low_ratio or current <= 0:
		_low_target = 0.0
		_danger = 0.0
		if ratio >= 1.0:
			_flash = 0.0
			_low = 0.0
		return
	_danger = clampf(inverse_lerp(low_ratio, critical_ratio, ratio), 0.0, 1.0)
	_low_target = lerpf(0.45, 1.0, _danger)
	_pulse_rate = lerpf(low_pulse_rate, critical_pulse_rate, _danger)
	_low = maxf(_low, _low_target * 0.8)


func _on_died(_info: DamageInfo) -> void:
	_low_target = 0.0
	_low = 0.0
	_danger = 0.0
	_flash = 1.0


func _match_retro_screen() -> void:
	var retro := PsxScreen.enabled
	var blocks := 1.0
	if retro:
		var render := PsxScreen.get_render_size()
		blocks = maxf(1.0, roundf(get_viewport_rect().size.y / maxf(render.y, 1.0)))
	material.set_shader_parameter("pixel_size", blocks)
	material.set_shader_parameter("dither", retro)
