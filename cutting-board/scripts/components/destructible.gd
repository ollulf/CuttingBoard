class_name Destructible
extends Node

@export var health := 1.0

signal destroyed

func damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		destroyed.emit()
		get_parent().queue_free()
