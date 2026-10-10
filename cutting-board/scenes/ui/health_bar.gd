class_name HealthBar
extends Control

const BLOOD := Color("#b23a2e")
const BLOOD_HI := Color("#e6594d")
const FLAME := Color("#f0a838")
const STAT := Color("#c7c9db")
const BACKING := Color(0.027, 0.02, 0.039, 0.75)
const OUTLINE := Color(0.027, 0.02, 0.039, 0.95)
const RING := Color(0.859, 0.678, 0.361, 0.22)
const RING_BEAT := Color(0.902, 0.349, 0.302, 0.8)

const HEART: Array[String] = [
	".##.##.",
	"#######",
	"#######",
	".#####.",
	"..###..",
	"...#...",
]

@export var design_height := 360
@export var margin := Vector2i(10, 25)
@export var bar_size := Vector2i(86, 5)
@export var font_size := 8
@export_range(0.0, 1.0) var critical_ratio := 0.25
@export var hide_when_full := false
@export var follow_owner := true
@export_group("Timing")
@export var fill_time := 0.5
@export var fill_steps := 12
@export var trail_delay := 0.5
@export var trail_time := 1.2
@export var trail_steps := 16
@export var beat_period := 1.0
@export var fade_time := 0.4

var _health: Health
var _current := 0
var _maximum := 1
var _fill := 1.0
var _fill_from := 1.0
var _fill_to := 1.0
var _fill_t := 0.0
var _trail := 1.0
var _trail_from := 1.0
var _trail_to := 1.0
var _trail_t := 0.0
var _beat_t := 0.0
var _forced_visible := false
var _show_left := 0.0
var _fade: Tween
var _px := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	get_tree().root.size_changed.connect(_fit_to_window)
	_fit_to_window()
	if follow_owner:
		if _health == null:
			var found := _find_owner_health()
			if found:
				bind(found)
		var tracker := CombatTracker.find_for(self)
		if tracker:
			tracker.combat_changed.connect(set_forced_visible)
	_update_visibility(true)


func bind(health: Health) -> void:
	if _health == health:
		return
	if _health and _health.changed.is_connected(_on_changed):
		_health.changed.disconnect(_on_changed)
	_health = health
	if _health == null:
		return
	_health.changed.connect(_on_changed)
	if not _health.is_node_ready():
		await _health.ready
	_jump_to(_health.get_current(), _health.max_health)


func show_for(seconds: float) -> void:
	_show_left = maxf(_show_left, seconds)
	_update_visibility()
	set_process(true)


func set_forced_visible(forced: bool) -> void:
	_forced_visible = forced
	_update_visibility()


func is_critical() -> bool:
	return float(_current) / float(_maximum) < critical_ratio


func _on_changed(current: int, maximum: int) -> void:
	var ratio := _ratio_of(current, maximum)
	_trail_from = _trail if ratio < _trail else ratio
	_trail_to = ratio
	_trail_t = 0.0
	_fill_from = _fill
	_fill_to = ratio
	_fill_t = 0.0
	_current = current
	_maximum = maxi(maximum, 1)
	_update_visibility()
	set_process(true)
	queue_redraw()


func _jump_to(current: int, maximum: int) -> void:
	_current = current
	_maximum = maxi(maximum, 1)
	var ratio := _ratio_of(current, maximum)
	_fill = ratio
	_fill_from = ratio
	_fill_to = ratio
	_fill_t = fill_time
	_trail = ratio
	_trail_from = ratio
	_trail_to = ratio
	_trail_t = trail_delay + trail_time
	_update_visibility(true)
	set_process(is_critical())
	queue_redraw()


func _process(delta: float) -> void:
	_fill_t += delta
	_trail_t += delta
	_fill = _stepped(_fill_from, _fill_to, _fill_t / fill_time, fill_steps)
	_trail = _stepped(_trail_from, _trail_to, (_trail_t - trail_delay) / trail_time, trail_steps)
	_trail = maxf(_trail, _fill)
	if is_critical():
		_beat_t = fmod(_beat_t + delta, beat_period)
	if _show_left > 0.0:
		_show_left -= delta
		if _show_left <= 0.0:
			_update_visibility()
	var settled := _fill_t >= fill_time and _trail_t >= trail_delay + trail_time
	if settled and not is_critical() and _show_left <= 0.0:
		set_process(false)
	queue_redraw()


func _stepped(from: float, to: float, t: float, steps: int) -> float:
	var k := floorf(clampf(t, 0.0, 1.0) * steps) / maxf(steps, 1)
	return lerpf(from, to, k)


func _ratio_of(current: int, maximum: int) -> float:
	return clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)


func _update_visibility(instant := false) -> void:
	var wanted := (not hide_when_full or _forced_visible or _show_left > 0.0
		or _current < _maximum)
	var alpha := 1.0 if wanted else 0.0
	if _fade:
		_fade.kill()
	if instant or not is_inside_tree():
		modulate.a = alpha
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, fade_time)


func _fit_to_window() -> void:
	var window := get_tree().root.get_visible_rect().size
	_px = maxi(1, roundi(window.y / maxi(design_height, 1)))
	queue_redraw()


func _find_owner_health() -> Health:
	var node := get_parent()
	while node:
		for child in node.get_children():
			if child is Health:
				return child
		node = node.get_parent()
	return null


func _draw() -> void:
	var px := float(_px)
	var row_h := 12
	var top := size.y / px - margin.y - row_h
	var mid := top + row_h * 0.5
	var x := float(margin.x)

	var heart_top := floorf(mid - HEART.size() * 0.5)
	for r in HEART.size():
		for c in HEART[r].length():
			if HEART[r][c] == "#":
				_rect(x + c, heart_top + r, 1, 1, BLOOD_HI)
	x += 7 + 4

	var bar := Rect2(x, floorf(mid - bar_size.y * 0.5), bar_size.x, bar_size.y)
	var ring := RING_BEAT if is_critical() and _beat_t >= beat_period * 0.5 else RING
	_frame(bar.grow(2), ring)
	_frame(bar.grow(1), OUTLINE)
	_rect(bar.position.x, bar.position.y, bar.size.x, bar.size.y, BACKING)
	var trail_w := roundf(bar.size.x * _trail)
	var fill_w := roundf(bar.size.x * _fill)
	_rect(bar.position.x, bar.position.y, trail_w, bar.size.y, FLAME)
	if fill_w > 0:
		_rect(bar.position.x, bar.position.y, fill_w, bar.size.y, BLOOD)
		_rect(bar.position.x, bar.position.y, fill_w, 1, BLOOD_HI)
	x += bar_size.x + 4

	var font := get_theme_default_font()
	var fs := font_size * _px
	var baseline := mid * px + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(x * px, roundf(baseline)), str(_current),
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STAT)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	if w <= 0 or h <= 0:
		return
	draw_rect(Rect2(x * _px, y * _px, w * _px, h * _px), color)


func _frame(r: Rect2, color: Color) -> void:
	var p := r.position
	var s := r.size
	_rect(p.x, p.y, s.x, 1, color)
	_rect(p.x, p.y + s.y - 1, s.x, 1, color)
	_rect(p.x, p.y + 1, 1, s.y - 2, color)
	_rect(p.x + s.x - 1, p.y + 1, 1, s.y - 2, color)
