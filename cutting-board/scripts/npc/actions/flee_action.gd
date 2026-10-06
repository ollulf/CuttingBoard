class_name FleeAction
extends NpcAction

## Runs from the nearest enemy it knows of. Two things make it appealing: a timid NPC
## wants to get away from any enemy that comes close, and even a brave one wants out
## once badly hurt. Which of the two an NPC listens to is set by its exports, so the
## same action makes a villager bolt on sight and a bandit only break off when losing.

## How readily it runs from an enemy that is merely near. 0 never, 1 always.
@export_range(0.0, 1.0) var cowardice := 1.0
## Beyond this distance an enemy is not worth running from, unless badly hurt.
@export var safe_distance := 12.0
## At or below this share of health left, it runs from any enemy it knows of.
@export_range(0.0, 1.0) var flee_below_health := 0.25
@export_range(0.0, 1.0) var wounded_score := 0.9
## How far ahead each leg of the escape aims, in metres.
@export var leg_distance := 6.0
## Seconds between re-aiming the escape, so it bends away from a chasing enemy.
@export var reaim_interval := 0.5

var _reaim := 0.0


func score(npc: Npc) -> float:
	var threat := npc.nearest_hostile()
	if threat == null:
		return 0.0
	if npc.health.get_ratio() <= flee_below_health:
		return wounded_score
	var distance := npc.flat_distance_to(npc.memory.last_seen_position(threat))
	if distance >= safe_distance:
		return 0.0
	# Closer is more urgent: half-keen at the edge of the safe distance, fully at arm's length.
	return cowardice * lerpf(0.5, 1.0, 1.0 - distance / safe_distance)


func enter(npc: Npc) -> void:
	npc.locomotion.clear_facing()
	_reaim = 0.0


func exit(npc: Npc) -> void:
	npc.locomotion.stop()


func tick(npc: Npc, delta: float) -> void:
	_reaim -= delta
	if _reaim > 0.0 and npc.locomotion.is_moving():
		return
	_reaim = reaim_interval
	var threat := npc.nearest_hostile()
	if threat == null:
		return
	var away := npc.global_position - npc.memory.last_seen_position(threat)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	npc.locomotion.move_to(npc.global_position + away.normalized() * leg_distance, true)
