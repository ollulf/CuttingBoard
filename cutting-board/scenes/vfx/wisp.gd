extends Node3D

## A will-o'-wisp: a small amber light that drifts aimlessly over the ground near where
## it was placed, bobbing, and never strays far. It is cheap on purpose (one billboard
## and one small light) so a meadow can hold several.

## How far from its starting point the wisp wanders, in metres.
@export var wander_radius := 6.0
## Wandering speed, in metres per second (roughly).
@export var drift_speed := 0.35
## Height it floats at above its starting point, and how far it bobs around that.
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
	# Two decorrelated noise tracks give a slow, looping-free path within the radius.
	var offset := Vector2(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time + 500.0))
	offset = offset * 1.8 * wander_radius
	offset = offset.limit_length(wander_radius)
	var bob := sin(_time / maxf(drift_speed, 0.01) * bob_speed) * bob_height
	position = _home + Vector3(offset.x, hover_height + bob, offset.y)
