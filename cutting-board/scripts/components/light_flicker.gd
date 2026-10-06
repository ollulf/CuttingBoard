class_name LightFlicker
extends Light3D

## Makes a light breathe like a flame: its energy wanders around the value it was given
## in the scene, with a slow sway and a quicker flutter on top. Every light starts at a
## random point in the pattern, so a row of lanterns never flickers in step.

## How far the energy dips and rises, as a fraction of the authored energy.
@export_range(0.0, 1.0) var amount := 0.18
## Speed of the slow sway and of the flutter, in cycles per second (roughly).
@export var sway_speed := 0.7
@export var flutter_speed := 7.0
## Share of the flicker that is flutter rather than sway.
@export_range(0.0, 1.0) var flutter_share := 0.35

var _base_energy := 1.0
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta
	var sway := _noise.get_noise_1d(_time * sway_speed)
	var flutter := _noise.get_noise_1d(1000.0 + _time * flutter_speed)
	# FastNoiseLite's simplex sits mostly within -0.6..0.6; scale it to about -1..1.
	var wobble := clampf(lerpf(sway, flutter, flutter_share) * 1.7, -1.0, 1.0)
	var factor := 1.0 + wobble * amount
	light_energy = _base_energy * factor
