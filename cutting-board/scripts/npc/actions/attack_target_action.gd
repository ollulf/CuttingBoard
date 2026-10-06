class_name AttackTargetAction
extends NpcAction

## Goes after the enemy the NPC picks to fight (Npc.get_attack_target) and hits it. While the enemy is in sight it
## chases the enemy itself; once out of sight it heads for where the enemy was last
## seen, and gives up when memory lets the enemy go.

## How keen it is to fight any enemy it knows of. 0 never fights.
@export_range(0.0, 1.0) var aggression := 0.8
## Flat distance from which it swings, in metres. Keep it inside MeleeAttack.reach.
@export var attack_range := 1.3
## Closer than this, flat, it steps back while it keeps swinging, so it does not end
## up fighting from inside the enemy's body. Keep it below attack_range.
@export var min_distance := 0.9
## Seconds between blows.
@export var cooldown := 1.2
## Delay before the first blow once in range, so closing in is not an instant hit.
@export var windup := 0.4
## Seen this recently counts as in sight, and is chased at its true position.
@export var in_sight_window := 0.5

var _target: Node3D
var _until_blow := 0.0


func score(npc: Npc) -> float:
	return aggression if npc.get_attack_target() else 0.0


func enter(npc: Npc) -> void:
	_target = npc.get_attack_target()
	_until_blow = windup


func exit(npc: Npc) -> void:
	npc.locomotion.stop()
	npc.locomotion.clear_facing()
	_target = null


func tick(npc: Npc, delta: float) -> void:
	# Re-picked every frame, so a closer enemy — or the player turning up — is not
	# ignored in favour of whoever the fight started with.
	_target = npc.get_attack_target()
	if _target == null:
		npc.locomotion.stop()
		return

	var in_sight := npc.memory.seconds_since_seen(_target) <= in_sight_window
	var goal := _target.global_position if in_sight else npc.memory.last_seen_position(_target)

	var distance := npc.flat_distance_to(goal)
	if in_sight and distance <= attack_range:
		npc.locomotion.face(goal)
		if distance < min_distance:
			_step_back(npc, goal)
		else:
			npc.locomotion.stop()
		_until_blow -= delta
		if _until_blow <= 0.0:
			npc.strike_at(_target)
			_until_blow = cooldown
		return

	npc.locomotion.clear_facing()
	npc.locomotion.move_to(goal, true)
	# Stepping out of range and back resets the wind-up rather than landing a free hit.
	_until_blow = maxf(_until_blow, windup)


## Backs off from `goal` at a walk, still facing it. The point aimed for is a full
## arrival distance behind the stand-off, so Locomotion does not count it reached
## before the gap has really opened.
func _step_back(npc: Npc, goal: Vector3) -> void:
	var away := npc.global_position - goal
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = npc.global_basis.z
	var step := min_distance - away.length() + npc.locomotion.arrive_distance
	npc.locomotion.move_to(npc.global_position + away.normalized() * step)
