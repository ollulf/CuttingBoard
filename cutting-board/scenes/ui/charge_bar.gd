class_name ChargeBar
extends Node3D

@onready var _fill: MeshInstance3D = %Fill


func _ready() -> void:
	hide()
	var hand := get_parent() as HandSlot
	if hand:
		hand.charge_changed.connect(set_ratio)


func set_ratio(ratio: float) -> void:
	visible = ratio > 0.0
	if not visible:
		return
	_fill.scale.x = ratio
