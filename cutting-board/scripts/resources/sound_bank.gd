class_name SoundBank
extends Resource

@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
@export_range(0.0, 12.0, 0.5) var volume_jitter_db := 1.5
@export_range(0.25, 4.0, 0.01) var pitch := 1.0
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.06
@export var bus: StringName = &"SFX"
@export_range(0.0, 2.0, 0.01) var cooldown := 0.0

@export_group("3D")
@export_range(0.1, 50.0, 0.1) var unit_size := 3.0
@export_range(1.0, 200.0, 1.0) var max_distance := 30.0

var _last_index := -1


func pick() -> AudioStream:
	if streams.is_empty():
		return null
	var index := randi() % streams.size()
	if streams.size() > 1 and index == _last_index:
		index = (index + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last_index = index
	return streams[index]


func random_pitch() -> float:
	return pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))


func random_volume_db() -> float:
	return volume_db + randf_range(-volume_jitter_db, volume_jitter_db)
