class_name FunhouseMirror
extends CanvasLayer

@export var enabled := true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply()
@export_range(0.0, 2.0) var intensity := 1.0
@export_range(0.0, 1.0) var low_ripple := 0.5
@export var min_kick := 4.0
@export var max_kick := 10.0
@export_range(0.0, 1.0) var squash_share := 0.1

const STEPS_PER_SECOND := 120.0

@onready var _lens: ColorRect = %Lens

var _overlay: HurtOverlay
var _bulge := 0.0
var _bulge_speed := 0.0
var _squash := 0.0
var _squash_speed := 0.0
var _centre := Vector2(0.5, 0.5)
var _wobble := 0.0
var _time := 0.0


func _ready() -> void:
	_apply()


func bind(overlay: HurtOverlay) -> void:
	_overlay = overlay
	_overlay.struck.connect(_on_struck)
	_overlay.mended.connect(_on_mended)


func _process(delta: float) -> void:
	if _overlay == null:
		return
	_time += delta
	var steps := maxi(1, ceili(delta * STEPS_PER_SECOND - 0.000001))
	for i in steps:
		_step(delta / steps)
	_apply()


func _step(dt: float) -> void:
	var low := _overlay.get_low() * lerpf(0.4, 1.0, _overlay.get_danger()) * low_ripple
	var target := maxf(low, _overlay.get_flash() * 0.5)
	var rate := 3.0 if target > _wobble else 1.0
	_wobble += (target - _wobble) * (1.0 - exp(-rate * dt))
	_bulge_speed += -_bulge * 160.0 * dt
	_bulge_speed *= exp(-5.0 * dt)
	_bulge += _bulge_speed * dt
	_squash_speed += -_squash * 120.0 * dt
	_squash_speed *= exp(-4.0 * dt)
	_squash += _squash_speed * dt


func _apply() -> void:
	var strength := intensity if enabled else 0.0
	var wobble := _wobble * strength
	var bulge := _bulge * 0.35 * strength
	var squash := _squash * strength
	var flash := _overlay.get_flash() if _overlay else 0.0
	var fringe := (_wobble * 3.0 + flash * 3.0) * strength
	visible = (
		strength > 0.0
		and (wobble > 0.003 or absf(bulge) > 0.002 or absf(squash) > 0.002 or fringe > 0.05)
	)
	if not visible:
		return
	var material := _lens.material as ShaderMaterial
	material.set_shader_parameter("bulge", bulge)
	material.set_shader_parameter("bulge_centre", _centre)
	material.set_shader_parameter("squash", squash)
	material.set_shader_parameter("wobble", wobble)
	material.set_shader_parameter("time", _time)
	material.set_shader_parameter("fringe", fringe)
	_match_retro_screen(material)


func _on_struck(share: float) -> void:
	var hardness := clampf(share * 3.3, 0.0, 1.0)
	_bulge_speed += lerpf(min_kick, max_kick, hardness)
	_centre = Vector2(randf_range(0.3, 0.7), randf_range(0.35, 0.65))
	_squash_speed += 6.0 * smoothstep(squash_share, squash_share * 2.0, share)


func _on_mended() -> void:
	_squash_speed -= 3.0


func _match_retro_screen(material: ShaderMaterial) -> void:
	var pixel_size := 1.0
	var offset := Vector2.ZERO
	if PsxScreen.enabled:
		var rect: Rect2 = PsxScreen.get_display_rect()
		var render := PsxScreen.get_render_size()
		pixel_size = maxf(1.0, rect.size.y / maxf(render.y, 1.0))
		offset = rect.position
	material.set_shader_parameter("pixel_size", pixel_size)
	material.set_shader_parameter("grid_offset", offset)
