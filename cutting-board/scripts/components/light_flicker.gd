class_name LightFlicker
extends Light3D

@export_range(0.0, 1.0) var amount := 0.18
@export var sway_speed := 0.7
@export var flutter_speed := 7.0
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
	var wobble := clampf(lerpf(sway, flutter, flutter_share) * 1.7, -1.0, 1.0)
	var factor := 1.0 + wobble * amount
	light_energy = _base_energy * factor
