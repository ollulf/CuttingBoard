class_name AttackTargetAction
extends NpcAction

@export_range(0.0, 1.0) var aggression := 0.8
@export_range(0.0, 1.0) var retaliation := 0.75
@export var attack_range := 1.3
@export var min_distance := 0.9
@export var cooldown := 1.2
@export var windup := 0.4
@export var in_sight_window := 0.5
@export var give_up_after := 20.0
@export var leash_distance := 30.0

const MIN_STEP_BACK := 0.15

var _target: Node3D
var _until_blow := 0.0
var _chasing_for := 0.0


func score(npc: Npc) -> float:
	return npc.fight_score(npc.get_attack_target(), aggression, retaliation)


func enter(npc: Npc) -> void:
	_target = npc.get_attack_target()
	_until_blow = windup
	_chasing_for = 0.0


func exit(npc: Npc) -> void:
	npc.locomotion.stop()
	npc.locomotion.clear_facing()
	_target = null


func tick(npc: Npc, delta: float) -> void:
	var target := npc.get_attack_target()
	if target != _target:
		_chasing_for = 0.0
	_target = target
	if _target == null:
		npc.locomotion.stop()
		return

	var in_sight := npc.memory.seconds_since_seen(_target) <= in_sight_window
	var goal := _target.global_position if in_sight else npc.memory.last_seen_position(_target)

	var distance := npc.flat_distance_to(goal)
	if in_sight and distance <= attack_range:
		_chasing_for = 0.0
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

	_chasing_for += delta
	if ((give_up_after > 0.0 and _chasing_for > give_up_after)
			or (leash_distance > 0.0 and npc.flat_distance_to(npc.home) > leash_distance)):
		npc.give_up_on(_target)
		_target = null
		_chasing_for = 0.0
		npc.locomotion.stop()
		return
	npc.locomotion.clear_facing()
	npc.locomotion.move_to(goal, true)
	_until_blow = maxf(_until_blow, windup)


func _step_back(npc: Npc, goal: Vector3) -> void:
	var away := npc.global_position - goal
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = npc.global_basis.z
	var step := min_distance - away.length() + npc.locomotion.arrive_distance
	var point := npc.locomotion.walkable_point(npc.global_position + away.normalized() * step)
	var gained := Vector2(point.x - goal.x, point.z - goal.z).length() - away.length()
	if gained < MIN_STEP_BACK:
		npc.locomotion.stop()
		return
	npc.locomotion.move_to(point)
