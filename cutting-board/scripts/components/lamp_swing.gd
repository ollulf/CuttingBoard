class_name LampSwing
extends Node3D

@export_range(0.0, 15.0) var max_angle := 3.5
@export var period := 3.0
@export_range(0.0, 0.5) var period_jitter := 0.2
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
	var cross := sin(_time * _cross_speed) * sin(_time * 0.21 + 1.3) * cross_share
	rotation = _base_rotation + Vector3(sin(_time * _speed) * limit, 0.0, cross * limit)


func current_angle() -> float:
	return rad_to_deg(Quaternion.from_euler(_base_rotation).angle_to(Quaternion.from_euler(rotation)))
