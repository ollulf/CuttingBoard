class_name AmbientSound
extends AudioStreamPlayer3D

## A looping sound that belongs to a place — a lantern's flame, the crowd at the fair —
## heard from where it is. It starts by itself, from a random point in its loop, so a row
## of lanterns built from the same scene never crackles in step. The stream is expected
## to loop already; the synthesised ambience loops are marked as loops in their WAVs.

## Starting point in the loop: random so copies drift apart, or the start for a sound
## that has to begin from its beginning.
@export var random_start := true


func _ready() -> void:
	if stream == null:
		return
	play(randf() * stream.get_length() if random_start else 0.0)
