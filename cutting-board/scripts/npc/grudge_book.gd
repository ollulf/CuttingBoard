class_name GrudgeBook
extends RefCounted

## Who an NPC holds a grudge against, and until when. Npc keeps one and asks it; the
## rules for when a grudge starts (being hit, an ally being hit) stay with the Npc.

## actor -> time (seconds) the grudge against it runs out.
var _until := {}


## Holds a grudge against `actor` for `seconds` from now, replacing the end of one
## already held.
func hold(actor: Node3D, seconds: float) -> void:
	_until[actor] = now() + seconds


## Everyone still held a grudge against. A grudge is dropped once it has run out, once
## its target is dead or gone, and once `memory` has let the target go.
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


## Lets the grudge against `actor` go before it runs out.
func drop(actor: Node3D) -> void:
	_until.erase(actor)


## The clock grudges run on, in seconds.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0
