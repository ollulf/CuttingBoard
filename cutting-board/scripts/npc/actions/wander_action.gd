class_name WanderAction
extends NpcAction

## Idles about the NPC's home: walks to a random spot nearby, stands a while, picks
## another. It scores low and flat, which makes it what an NPC does when nothing else
## wants to happen.

@export_range(0.0, 1.0) var base_score := 0.1
## How far from home a stroll can take the NPC, in metres.
@export var radius := 8.0
@export var pause_min := 1.0
@export var pause_max := 4.0
## A stroll that has not arrived after this many seconds is given up, so an NPC that
## picked a spot it cannot reach does not walk into a wall forever.
@export var give_up_after := 10.0

var _pause := 0.0
var _walking_for := 0.0


func score(_npc: Npc) -> float:
	return base_score


func enter(npc: Npc) -> void:
	npc.locomotion.clear_facing()
	_pick_spot(npc)


func exit(npc: Npc) -> void:
	npc.locomotion.stop()


func tick(npc: Npc, delta: float) -> void:
	if npc.locomotion.is_moving():
		_walking_for += delta
		if _walking_for > give_up_after:
			npc.locomotion.stop()
		return
	_pause -= delta
	if _pause <= 0.0:
		_pick_spot(npc)


func _pick_spot(npc: Npc) -> void:
	_pause = randf_range(pause_min, pause_max)
	_walking_for = 0.0
	# Far from home — back from a chase it gave up — it walks straight home first, and
	# is given the time the longer walk takes.
	var away := npc.flat_distance_to(npc.home)
	if away > radius:
		npc.locomotion.move_to(npc.home)
		_walking_for = -away / npc.locomotion.walk_speed
		return
	var angle := randf() * TAU
	var distance := randf_range(radius * 0.3, radius)
	npc.locomotion.move_to(npc.home + Vector3(cos(angle), 0.0, sin(angle)) * distance)
