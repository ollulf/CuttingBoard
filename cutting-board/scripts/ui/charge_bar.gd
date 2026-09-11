class_name ChargeBar
extends Node3D

## World-space charge meter that sits at a hand pivot and fills as a throw is wound up.

@onready var _fill: MeshInstance3D = %Fill


func _ready() -> void:
	hide()
	# The bar lives under the hand it visualises, so it can subscribe directly. It still
	# works standalone for anything that drives set_ratio() itself.
	var hand := get_parent() as HandSlot
	if hand:
		hand.charge_changed.connect(set_ratio)


func set_ratio(ratio: float) -> void:
	visible = ratio > 0.0
	if not visible:
		return
	_fill.scale.x = ratio
