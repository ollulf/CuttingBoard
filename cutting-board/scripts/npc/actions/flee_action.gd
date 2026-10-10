class_name FleeAction
extends NpcAction

@export_range(0.0, 1.0) var cowardice := 1.0
@export var safe_distance := 12.0
@export_range(0.0, 1.0) var flee_below_health := 0.25
@export_range(0.0, 1.0) var wounded_score := 0.9
@export var leg_distance := 6.0
@export var reaim_interval := 0.5

var _reaim := 0.0


func score(npc: Npc) -> float:
	if npc.nearest_hostile() == null:
		return 0.0
	if npc.health.get_ratio() <= flee_below_health:
		return wounded_score
	var threat := npc.nearest_hostile(false)
	if threat == null:
		return 0.0
	var distance := npc.flat_distance_to(npc.memory.last_seen_position(threat))
	if distance >= safe_distance:
		return 0.0
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
	var threat := npc.nearest_hostile(npc.health.get_ratio() <= flee_below_health)
	if threat == null:
		return
	var away := npc.global_position - npc.memory.last_seen_position(threat)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	npc.locomotion.move_to(npc.global_position + away.normalized() * leg_distance, true)
