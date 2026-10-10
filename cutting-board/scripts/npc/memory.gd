class_name Memory
extends Node

@export var forget_after := 8.0

var _entries := {}


func remember(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_entries[actor] = {"position": actor.global_position, "time": _now()}


func remember_at(actor: Node3D, position: Vector3) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_entries[actor] = {"position": position, "time": _now()}


func forget(actor: Node3D) -> void:
	_entries.erase(actor)


func clear() -> void:
	_entries.clear()


func knows(actor: Node3D) -> bool:
	_prune()
	return _entries.has(actor)


func get_known() -> Array[Node3D]:
	_prune()
	var known: Array[Node3D] = []
	for actor in _entries:
		known.append(actor)
	return known


func last_seen_position(actor: Node3D) -> Vector3:
	var entry: Dictionary = _entries.get(actor, {})
	return entry.get("position", Vector3.ZERO)


func seconds_since_seen(actor: Node3D) -> float:
	var entry: Dictionary = _entries.get(actor, {})
	if entry.is_empty():
		return INF
	return _now() - float(entry["time"])


func _prune() -> void:
	var now := _now()
	for actor in _entries.keys():
		if not is_instance_valid(actor) or now - float(_entries[actor]["time"]) > forget_after:
			_entries.erase(actor)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
