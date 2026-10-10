class_name GrudgeBook
extends RefCounted

var _until := {}


func hold(actor: Node3D, seconds: float) -> void:
	_until[actor] = now() + seconds


func get_held(memory: Memory) -> Array[Node3D]:
	var time := now()
	var held: Array[Node3D] = []
	for actor in _until.keys():
		if (not is_instance_valid(actor) or time > float(_until[actor])
				or not Health.is_node_alive(actor) or not memory.knows(actor)):
			_until.erase(actor)
			continue
		held.append(actor)
	return held


func drop(actor: Node3D) -> void:
	_until.erase(actor)


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0
