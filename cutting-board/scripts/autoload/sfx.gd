extends Node

## Plays SoundBanks for the whole game, autoloaded as Sfx.
##
## Gameplay code never makes its own one-shot players: it hands a bank to play() — heard
## the same wherever the listener is, for the player's own body and the interface — or
## to play_at() for a sound out in the world, which is positioned, falls away with
## distance and dulls with it. The players come from two fixed pools, so a burst of
## sounds costs no node churn; when every player in a pool is busy, the one that has been
## playing longest is cut off for the new sound.
##
## Looping sounds that belong to a place — a lantern's crackle, the night itself — are
## not played through here; they are ordinary players in the scenes they belong to.

## Players in each pool: how many sounds of each kind can be heard at once.
const FLAT_VOICES := 12
const SPATIAL_VOICES := 32

## Prints every play to the output, with the game time and the bank's file, which is a
## quick way to see what a scene is really setting off.
var log_plays := false

var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
## When each bank last played, on _clock, for SoundBank.cooldown. Game time rather than
## the wall clock, so cooldowns hold in a Movie Maker recording too.
var _last_played := {}
var _clock := 0.0


func _ready() -> void:
	# The interface keeps making sound while the game is paused.
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


## Plays a take from `bank` without position. `volume_db` is added to the bank's own
## level and `pitch_scale` multiplies its pitch. Returns the player, or null when nothing
## was played: no bank, an empty bank, or a bank still cooling down.
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


## Plays a take from `bank` at `position` in the world, heard from wherever the current
## camera is. Takes the same adjustments as play(). A sound too far from the camera to be
## heard at all is not played, so the footsteps of a whole village do not tie up players.
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
	# The distance law keeps getting louder inside unit_size — a punch at arm's length
	# would land far over its bank's level, a swing at the camera at full scale. max_db
	# caps the level after attenuation, so capped at the play's own volume a sound
	# reaches full level at unit_size and stays there however close it gets.
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


## A player that is not playing, or failing that the one that has been playing longest.
func _free_player(pool: Array) -> Node:
	var oldest: Node = pool[0]
	for player in pool:
		if not player.playing:
			oldest = player
			break
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	# Moved to the back, so the pool is roughly in order of when each player started.
	pool.erase(oldest)
	pool.append(oldest)
	return oldest
