class_name DamageNumber
extends Label3D

## One floating number, thrown up from the point where a hit landed and gone again a
## second later. It animates itself and frees itself: whoever spawns it only has to say
## how much, where, and in what colour.

## Seconds from appearing to gone.
@export var lifetime := 0.9
## How far the number climbs over its life, in metres.
@export var rise := 0.9
## Random sideways offset applied at birth, so several hits in one spot do not stack
## into an unreadable pile.
@export var scatter := 0.25
## How much bigger the number starts before settling, which is what gives the pop.
@export var punch := 1.5
## Fraction of the lifetime spent fully opaque before the fade begins.
@export_range(0.0, 1.0) var hold := 0.35


## Places the number and starts its animation. Called after the node is in the tree,
## because the rise is animated in global space from wherever it was put.
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
