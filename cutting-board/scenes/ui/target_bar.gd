class_name TargetBar
extends HealthBar

## The enemy's health at the top centre while fighting, Gothic style: its name over a
## thin blood bar. It is the player's HealthBar pointed at someone else, so a blow lands
## the same way on both — the bar drops, the lost chunk lingers in flame and drains.
##
## Which enemy, and when, is the player's CombatTracker's call; this only shows it. When
## the tracker lets the target go the bar fades out still showing its last state, so a
## kill reads as the bar running out before it disappears.
##
## Out of combat the same bar names the NPC the player walks up to and looks at, tinted
## by its attitude: blood for a hostile one, neutral gray for a friendly one. A combat target
## always wins over it.

const NAME_FONT := preload("res://assets/fonts/Cubix_Mystical.ttf")
const NAME_COLOR := Color("#d9c9a0")
const FRIEND := Color("#8a8580")
const FRIEND_HI := Color("#b4aea6")

## Distance of the name from the top edge, in render pixels.
@export var top := 12
## Gap between the name and the bar.
@export var name_gap := 3

var _target_name := ""
var _has_target := false
var _friendly := false
var _tracker: CombatTracker


func _ready() -> void:
	super()
	_tracker = CombatTracker.find_for(self)
	if _tracker:
		_tracker.target_changed.connect(_refresh.unbind(1))
		_tracker.nearby_changed.connect(_refresh.unbind(1))
		_refresh()


## Shows the combat target, or else the NPC close by, or fades out with neither.
func _refresh() -> void:
	var target := _tracker.get_target()
	if target:
		show_target(target)
	else:
		show_target(_tracker.get_nearby(), true)


## Puts `target`'s name and health up, or fades the bar out for null. `by_attitude`
## tints the bar gray when `target` is no enemy of the player.
func show_target(target: Node3D, by_attitude := false) -> void:
	_has_target = target != null
	if _has_target:
		_target_name = CombatTracker.name_of(target)
		_friendly = by_attitude and not _is_hostile(target)
		bind(Health.find_in(target))
	_update_visibility()
	queue_redraw()


func is_friendly() -> bool:
	return _has_target and _friendly


func get_target_name() -> String:
	return _target_name if _has_target else ""


## Whether `target` is out for the player: an enemy side, or a grudge against it.
func _is_hostile(target: Node3D) -> bool:
	var player := _tracker.get_parent()
	var faction := Faction.find_in(target)
	if faction and faction.is_hostile_to(player):
		return true
	return target is Npc and (target as Npc).has_grudge_against(player as Node3D)


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
		_rect(bar.position.x, bar.position.y, fill_w, bar.size.y, FRIEND if _friendly else BLOOD)
		_rect(bar.position.x, bar.position.y, fill_w, 1, FRIEND_HI if _friendly else BLOOD_HI)
