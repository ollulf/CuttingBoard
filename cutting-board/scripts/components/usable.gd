class_name Usable
extends Node

## Lets an object respond to an "interact" action without being carried (levers, chests, campfires).

@export var uses_remaining := -1 ## -1 = infinite

signal used(by: Node)

func use(by: Node) -> void:
	if uses_remaining == 0:
		return
	if uses_remaining > 0:
		uses_remaining -= 1
	used.emit(by)
