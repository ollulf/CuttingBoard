extends Node3D

@export var wander_radius := 6.0
@export var drift_speed := 0.35
@export var hover_height := 1.4
@export var bob_height := 0.35
@export var bob_speed := 0.9

var _home := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_home = position
	_noise.seed = randi()
	_noise.frequency = 0.15
	_time = randf() * 1000.0


func _process(delta: float) -> void:
	_time += delta * drift_speed
	var offset := Vector2(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time + 500.0))
	offset = offset * 1.8 * wander_radius
	offset = offset.limit_length(wander_radius)
	var bob := sin(_time / maxf(drift_speed, 0.01) * bob_speed) * bob_height
	position = _home + Vector3(offset.x, hover_height + bob, offset.y)
