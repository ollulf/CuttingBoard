class_name DamageNumber
extends Label3D

@export var lifetime := 0.9
@export var rise := 0.9
@export var scatter := 0.25
@export var punch := 1.5
@export_range(0.0, 1.0) var hold := 0.35


func pop(amount: int, at: Vector3, color: Color) -> void:
	text = str(amount)
	modulate = color
	global_position = at + Vector3(
		randf_range(-scatter, scatter), randf_range(0.0, scatter), randf_range(-scatter, scatter)
	)
	scale = Vector3.ONE * punch

	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "global_position", global_position + Vector3.UP * rise, lifetime) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, lifetime * 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * (1.0 - hold)) \
		.set_delay(lifetime * hold)
	tween.chain().tween_callback(queue_free)
