class_name AmbientSound
extends AudioStreamPlayer3D

@export var random_start := true


func _ready() -> void:
	if stream == null:
		return
	play(randf() * stream.get_length() if random_start else 0.0)
