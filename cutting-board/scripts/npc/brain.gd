class_name Brain
extends Node

signal action_changed(action: NpcAction)

@export var think_interval := 0.25
@export var commitment_bonus := 0.1

var _npc: Npc
var _current: NpcAction
var _timer := 0.0


func setup(npc: Npc) -> void:
	_npc = npc
	_timer = randf() * think_interval


func get_current_action() -> NpcAction:
	return _current


func shut_down() -> void:
	_switch_to(null)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _npc == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer += think_interval
		_think()
	if _current:
		_current.tick(_npc, delta)


func _think() -> void:
	var best: NpcAction = null
	var best_score := 0.0
	for child in get_children():
		var action := child as NpcAction
		if action == null:
			continue
		var score := action.score(_npc)
		if score <= 0.0:
			continue
		if action == _current:
			score += commitment_bonus
		if score > best_score:
			best = action
			best_score = score
	if best != _current:
		_switch_to(best)


func _switch_to(action: NpcAction) -> void:
	if _current:
		_current.exit(_npc)
	_current = action
	if _current:
		_current.enter(_npc)
	action_changed.emit(_current)
