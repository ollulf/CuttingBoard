extends Node

const FLAT_VOICES := 12
const SPATIAL_VOICES := 32

var log_plays := false

var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _last_played := {}
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in FLAT_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_flat.append(player)
	for i in SPATIAL_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		_spatial.append(player)


func play(bank: SoundBank, volume_db := 0.0, pitch_scale := 1.0) -> AudioStreamPlayer:
	if not _allowed(bank):
		return null
	var player := _free_player(_flat) as AudioStreamPlayer
	player.stream = bank.pick()
	player.bus = bank.bus
	player.volume_db = bank.random_volume_db() + volume_db
	player.pitch_scale = bank.random_pitch() * pitch_scale
	player.play()
	return player


func play_at(
	bank: SoundBank, position: Vector3, volume_db := 0.0, pitch_scale := 1.0
) -> AudioStreamPlayer3D:
	if bank == null:
		return null
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(position) > bank.max_distance:
		return null
	if not _allowed(bank):
		return null
	var player := _free_player(_spatial) as AudioStreamPlayer3D
	player.global_position = position
	player.stream = bank.pick()
	player.bus = bank.bus
	player.unit_size = bank.unit_size
	player.max_distance = bank.max_distance
	player.volume_db = bank.random_volume_db() + volume_db
	player.max_db = player.volume_db
	player.pitch_scale = bank.random_pitch() * pitch_scale
	player.play()
	return player


func _allowed(bank: SoundBank) -> bool:
	if bank == null or bank.streams.is_empty():
		return false
	if bank.cooldown > 0.0 and _clock - float(_last_played.get(bank, -INF)) < bank.cooldown:
		return false
	_last_played[bank] = _clock
	if log_plays:
		print("%7.2f  %s" % [_clock, bank.resource_path.get_file().get_basename()])
	return true


func _process(delta: float) -> void:
	_clock += delta


func _free_player(pool: Array) -> Node:
	var oldest: Node = pool[0]
	for player in pool:
		if not player.playing:
			oldest = player
			break
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	pool.erase(oldest)
	pool.append(oldest)
	return oldest
