class_name HurtOverlay
extends ColorRect

## The screen's edges going red when the player is hurt: a flash on every hit, as strong
## as the hit was hard, that fades out again; and while health is low, a red edge that
## stays and slowly pulses, stronger and quicker the closer death is. The look itself is
## in hurt_vignette.gdshader; this only decides how much of it to show.
##
## The same numbers drive the other hurt effects, such as the FunhouseMirror warping the
## world: they read the flash and the lingering level from here and listen for `struck`
## and `mended`, so every effect agrees on how bad a hit was and how close death is.

## A hit landed; `share` is the part of max health it took, 0..1.
signal struck(share: float)
## Health went up again: a heal, or a reset to full.
signal mended

## Below this share of health the edge stays red between hits.
@export_range(0.0, 1.0) var low_ratio := 0.3
## At or below this share it is at full strength and pulses at heartbeat pace.
@export_range(0.0, 1.0) var critical_ratio := 0.1
## How strong a hit's flash is: the share of max health it took, times this, on top of
## the smallest flash any hit gets.
@export var flash_per_damage := 2.0
@export_range(0.0, 1.0) var min_flash := 0.35
## Seconds for a flash to fade to about a third.
@export var flash_fade := 0.45
## Pulses per second while low, and at critical.
@export var low_pulse_rate := 0.8
@export var critical_pulse_rate := 1.6

var _health: Health
var _flash := 0.0
## How much of the lingering edge to show, eased towards what the health calls for so
## that healing fades it out rather than switching it off.
var _low := 0.0
var _low_target := 0.0
var _pulse_rate := 0.0
var _phase := 0.0
## 0 just under low_ratio, 1 at critical_ratio and below; 0 while not low at all.
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


## The current hit flash, 0..1, fading after each hit.
func get_flash() -> float:
	return _flash


## How much of the lingering low-health level is showing, 0..1, without the pulse.
func get_low() -> float:
	return _low


## How close to critical the health is, 0..1; see `_danger`.
func get_danger() -> float:
	return _danger


func _apply() -> void:
	# The pulse dips to 60% of the lingering strength and back; a flash rides on top.
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
			# Back to full is a reset or a full heal; nothing is left to show.
			_flash = 0.0
			_low = 0.0
		return
	_danger = clampf(inverse_lerp(low_ratio, critical_ratio, ratio), 0.0, 1.0)
	_low_target = lerpf(0.45, 1.0, _danger)
	_pulse_rate = lerpf(low_pulse_rate, critical_pulse_rate, _danger)
	# Dropping into low health shows the edge at once instead of easing up to it.
	_low = maxf(_low, _low_target * 0.8)


## The killing blow still flashes, then the lingering edge lets go: the camera pulls back
## to watch the body, and that should not happen through a red haze.
func _on_died(_info: DamageInfo) -> void:
	_low_target = 0.0
	_low = 0.0
	_danger = 0.0
	_flash = 1.0


## Dithers in blocks of the retro screen's pixels while it is on, and smoothly when off.
func _match_retro_screen() -> void:
	var retro := PsxScreen.enabled
	var blocks := 1.0
	if retro:
		var render := PsxScreen.get_render_size()
		blocks = maxf(1.0, roundf(get_viewport_rect().size.y / maxf(render.y, 1.0)))
	material.set_shader_parameter("pixel_size", blocks)
	material.set_shader_parameter("dither", retro)
