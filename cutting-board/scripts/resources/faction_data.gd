class_name FactionData
extends Resource

@export var id: StringName
@export var display_name: String
@export var hostile_to: Array[StringName] = []
@export var priority_targets: Array[StringName] = []


func is_hostile_to(other: FactionData) -> bool:
	return other != null and hostile_to.has(other.id)
