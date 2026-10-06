class_name Memory
extends Node

## What an NPC knows about the actors around it: who it has noticed, where it last saw
## them and when. The brain decides from this, never from the true state of the world,
## so an NPC that lost sight of the player goes to where the player *was*.
##
## Deliberately plain — no opinions here; grudges are the Npc's own (Npc.hold_grudge),
## and end when this forgets their target. An entry is refreshed each time
## the actor is noticed again and simply fades once it has gone unnoticed for long enough.

## Seconds an actor stays remembered after it was last noticed.
@export var forget_after := 8.0

## actor -> {"position": Vector3, "time": float}
var _entries := {}


## Notes that `actor` is here right now.
func remember(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_entries[actor] = {"position": actor.global_position, "time": _now()}


func forget(actor: Node3D) -> void:
	_entries.erase(actor)


func knows(actor: Node3D) -> bool:
	_prune()
	return _entries.has(actor)


## Every actor currently remembered, dropping the ones that have faded or been freed.
func get_known() -> Array[Node3D]:
	_prune()
	var known: Array[Node3D] = []
	for actor in _entries:
		known.append(actor)
	return known


## Where `actor` was when last noticed. Only meaningful for an actor this knows.
func last_seen_position(actor: Node3D) -> Vector3:
	var entry: Dictionary = _entries.get(actor, {})
	return entry.get("position", Vector3.ZERO)


## How long ago `actor` was last noticed, or INF for one this does not know.
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
