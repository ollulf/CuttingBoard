class_name TargetBar
extends HealthBar

## The enemy's health at the top centre while fighting, Gothic style: its name over a
## thin blood bar. It is the player's HealthBar pointed at someone else, so a blow lands
## the same way on both — the bar drops, the lost chunk lingers in flame and drains.
##
## Which enemy, and when, is the player's CombatTracker's call; this only shows it. When
## the tracker lets the target go the bar fades out still showing its last state, so a
## kill reads as the bar running out before it disappears.

const NAME_FONT := preload("res://assets/fonts/Cubix_Mystical.ttf")
const NAME_COLOR := Color("#d9c9a0")

## Distance of the name from the top edge, in render pixels.
@export var top := 12
## Gap between the name and the bar.
@export var name_gap := 3

var _target_name := ""
var _has_target := false


func _ready() -> void:
	super()
	var tracker := CombatTracker.find_for(self)
	if tracker:
		tracker.target_changed.connect(show_target)
		show_target(tracker.get_target())


## Puts `target`'s name and health up, or fades the bar out for null.
func show_target(target: Node3D) -> void:
	_has_target = target != null
	if _has_target:
		_target_name = CombatTracker.name_of(target)
		bind(Health.find_in(target))
	_update_visibility()
	queue_redraw()


func _update_visibility(instant := false) -> void:
	var alpha := 1.0 if _has_target else 0.0
	if _fade:
		_fade.kill()
	if instant or not is_inside_tree():
		modulate.a = alpha
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, fade_time)


func _draw() -> void:
	var px := float(_px)
	var font: Font = NAME_FONT
	var fs := font_size * _px
	var bar_x := floorf((size.x / px - bar_size.x) * 0.5)

	# Name, centred over the bar, with a one-pixel shadow so it reads over a bright sky.
	var name_h := font_size + 1
	var baseline := (top + name_h * 0.5) * px + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var origin := Vector2(0.0, roundf(baseline))
	draw_string(font, origin + Vector2(px, px), _target_name, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, fs, OUTLINE)
	draw_string(font, origin, _target_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, NAME_COLOR)

	# Bar: the same frame, trail and fill as the player's, wider and thinner.
	var bar := Rect2(bar_x, top + name_h + name_gap, bar_size.x, bar_size.y)
	_frame(bar.grow(2), RING)
	_frame(bar.grow(1), OUTLINE)
	_rect(bar.position.x, bar.position.y, bar.size.x, bar.size.y, BACKING)
	var trail_w := roundf(bar.size.x * _trail)
	var fill_w := roundf(bar.size.x * _fill)
	_rect(bar.position.x, bar.position.y, trail_w, bar.size.y, FLAME)
	if fill_w > 0:
		_rect(bar.position.x, bar.position.y, fill_w, bar.size.y, BLOOD)
		_rect(bar.position.x, bar.position.y, fill_w, 1, BLOOD_HI)
