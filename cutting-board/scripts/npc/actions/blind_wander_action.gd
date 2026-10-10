class_name BlindWanderAction
extends NpcAction

@export var blind_speed := 0.8
@export var step_min := 0.8
@export var step_max := 2.5
@export var stray_radius := 5.0
@export var pause_min := 0.6
@export var pause_max := 2.0
@export_range(0.0, 1.0) var look_around_chance := 0.4
@export var give_up_after := 4.0

var anchor := Vector3.ZERO

var _pause := 0.0
var _walking_for := 0.0


func score(_npc: Npc) -> float:
	return 1.0


func enter(npc: Npc) -> void:
	anchor = npc.global_position
	npc.locomotion.walk_speed = minf(npc.locomotion.walk_speed, blind_speed)
	npc.locomotion.clear_facing()
	npc.locomotion.stop()
	_pause = randf_range(pause_min, pause_max)


func exit(npc: Npc) -> void:
	npc.locomotion.stop()


func tick(npc: Npc, delta: float) -> void:
	if npc.locomotion.is_moving():
		_walking_for += delta
		if _walking_for > give_up_after:
			npc.locomotion.stop()
		return
	_pause -= delta
	if _pause > 0.0:
		return
	_pause = randf_range(pause_min, pause_max)
	if randf() < look_around_chance:
		_look_around(npc)
	else:
		_stumble_on(npc)


func _look_around(npc: Npc) -> void:
	var angle := randf() * TAU
	npc.locomotion.face(npc.global_position + Vector3(cos(angle), 0.0, sin(angle)))


func _stumble_on(npc: Npc) -> void:
	npc.locomotion.clear_facing()
	_walking_for = 0.0
	var angle := randf() * TAU
	var step := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(step_min, step_max)
	var goal := npc.global_position + step
	var stray := Vector3(goal.x - anchor.x, 0.0, goal.z - anchor.z)
	if stray.length() > stray_radius:
		goal = npc.global_position - step
	npc.locomotion.move_to(goal)
