class_name LampSwing
extends Node3D

## Lets a hanging lamp sway gently in the breeze. Put this on a pivot node at the hook,
## with the lamp body and its light under it, so both move together. The pivot rocks
## around its resting rotation on two axes: a main swing and a fainter cross sway. Every
## lamp picks a random phase and a slightly different period, so a row never swings in step.

## Peak angle of the main swing, in degrees.
@export_range(0.0, 15.0) var max_angle := 3.5
## Length of one full swing, in seconds; each lamp varies it by up to `period_jitter`.
@export var period := 3.0
@export_range(0.0, 0.5) var period_jitter := 0.2
## Strength of the cross sway, as a fraction of the main swing.
@export_range(0.0, 1.0) var cross_share := 0.35

var _base_rotation := Vector3.ZERO
var _time := 0.0
var _speed := 1.0
var _cross_speed := 1.0


func _ready() -> void:
	_base_rotation = rotation
	_time = randf() * 100.0
	var swing_period := period * (1.0 + randf_range(-period_jitter, period_jitter))
	_speed = TAU / swing_period
	_cross_speed = _speed * randf_range(0.6, 0.8)


func _process(delta: float) -> void:
	_time += delta
	var limit := deg_to_rad(max_angle)
	# The cross sway is slower and fades in and out, so the path never repeats exactly.
	var cross := sin(_time * _cross_speed) * sin(_time * 0.21 + 1.3) * cross_share
	rotation = _base_rotation + Vector3(sin(_time * _speed) * limit, 0.0, cross * limit)


## The swing's current angle away from rest, in degrees (used by tests).
func current_angle() -> float:
	return rad_to_deg(Quaternion.from_euler(_base_rotation).angle_to(Quaternion.from_euler(rotation)))
