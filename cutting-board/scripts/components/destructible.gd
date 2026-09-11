class_name Destructible
extends Node

## Durability that depletes as the object takes damage. Author durability per item; the
## intended scale is roughly 500 for a hand-sized rock and 50 for a pot. Flip
## indestructible rather than authoring a huge value: it pins durability at the maximum
## and skips the bookkeeping entirely.

signal destroyed

const MAX_DURABILITY := 9999

@export var indestructible := false
@export_range(0, 9999) var durability := 100


func _ready() -> void:
	# Applied here rather than in a setter on indestructible, because exported values
	# are restored in no guaranteed order while a scene loads.
	if indestructible:
		durability = MAX_DURABILITY


func damage(amount: int) -> void:
	if indestructible:
		return
	durability = clampi(durability - amount, 0, MAX_DURABILITY)
	if durability == 0:
		destroyed.emit()
		get_parent().queue_free()
