class_name Usable
extends Node

@export var uses_remaining := -1
@export var held_verb := ""
@export var use_action: StringName = &""

signal used(by: Node)
signal use_beat(beat_name: StringName, by: Node)
signal wasted(by: Node)

var can_use := Callable()


func use(by: Node) -> bool:
	if not can_be_used_by(by):
		return false
	if uses_remaining > 0:
		uses_remaining -= 1
	used.emit(by)
	return true


func can_be_used_by(by: Node) -> bool:
	if uses_remaining == 0:
		return false
	return not can_use.is_valid() or can_use.call(by)


func waste(by: Node) -> void:
	if uses_remaining > 0:
		uses_remaining -= 1
	wasted.emit(by)


func get_prompt(_by: Node) -> String:
	return ""


func is_used_in_hand() -> bool:
	return not held_verb.is_empty()


func is_timed() -> bool:
	return not use_action.is_empty()


static func find_in(node: Node) -> Usable:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Usable") as Usable
