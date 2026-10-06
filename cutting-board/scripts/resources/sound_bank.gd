class_name SoundBank
extends Resource

## One sound as the game asks for it — "a footstep", "a punch landing" — rather than as a
## file. A bank holds interchangeable takes of the sound and how to play them: each play
## picks a take at random (never the same one twice running) and nudges its pitch and
## level a little, so a sound heard over and over never repeats exactly.
##
## Banks are played through the Sfx autoload, which owns the actual players. They live in
## resources/audio, one per sound, and are shared: a component points an export at the
## bank instead of owning an AudioStreamPlayer of its own.

## The takes to choose between.
@export var streams: Array[AudioStream] = []
## Level of the bank as a whole, in dB. This is where sounds are balanced against each
## other; the files themselves are all normalised to about the same peak.
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
## How far each play's level may stray either side of volume_db, in dB.
@export_range(0.0, 12.0, 0.5) var volume_jitter_db := 1.5
## Playback speed and pitch, 1 as recorded.
@export_range(0.25, 4.0, 0.01) var pitch := 1.0
## How far each play's pitch may stray either side of `pitch`, as a fraction of it.
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.06
## The audio bus the sound plays on: SFX, Voices, UI or Ambience.
@export var bus: StringName = &"SFX"
## Shortest time between two plays of this bank, in seconds. A play asked for sooner is
## dropped, which keeps a pile of things landing at once from stacking into one loud
## burst. 0 lets every play through.
@export_range(0.0, 2.0, 0.01) var cooldown := 0.0

@export_group("3D")
## Distance, in metres, within which a positional play is heard at full volume before it
## starts to fall away. Larger carries further.
@export_range(0.1, 50.0, 0.1) var unit_size := 3.0
## Distance beyond which a positional play is not heard at all, in metres.
@export_range(1.0, 200.0, 1.0) var max_distance := 30.0

var _last_index := -1


## A take at random, avoiding the one picked last time when there is any choice.
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
