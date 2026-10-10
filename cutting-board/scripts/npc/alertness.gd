class_name Alertness
extends Node

signal meter_changed(fraction: float)

enum State { UNAWARE, WATCHING, SEARCHING, CALLING }

@export var watch_time := 7.0
@export var close_range := 3.0
@export var near_range := 5.0
@export var grace := 1.5
@export var drain_rate := 0.5
@export var search_time := 4.0
@export var call_time := 1.0
@export var unanswered_pause := 1.0

var state := State.UNAWARE
var target: Node3D
var meter := 0.0
var last_seen_position := Vector3.ZERO

var _since_seen := 0.0
var _left := 0.0

@onready var _npc: Npc = owner


func wants_to_watch(actor: Node3D) -> bool:
	if watch_time <= 0.0 or not _npc.faction.is_hostile_to(actor):
		return false
	if _npc.memory.knows(actor) or _npc.has_grudge_against(actor):
		return false
	if (state == State.WATCHING or state == State.CALLING) and is_instance_valid(target):
		return actor == target
	return true


func see(actor: Node3D) -> void:
	if state == State.UNAWARE or state == State.SEARCHING or actor != target:
		state = State.WATCHING
		target = actor
		meter = 0.0
	last_seen_position = actor.global_position
	_since_seen = 0.0
	if state == State.WATCHING and _npc.flat_distance_to(actor.global_position) <= close_range:
		raise_alarm(actor, true)


func raise_alarm(actor: Node3D, short := false) -> void:
	if state == State.CALLING:
		return
	target = actor
	if state == State.UNAWARE or state == State.SEARCHING:
		last_seen_position = actor.global_position
	state = State.CALLING
	meter = watch_time
	meter_changed.emit(1.0)
	var answered := _npc.call_for_help(actor, last_seen_position)
	_left = 0.0 if short else call_time + (0.0 if answered else unanswered_pause)
	if short:
		_finish_call()


func calm() -> void:
	state = State.UNAWARE
	target = null
	meter = 0.0
	meter_changed.emit(0.0)


func is_busy() -> bool:
	return state != State.UNAWARE


func _physics_process(delta: float) -> void:
	match state:
		State.WATCHING:
			_watch(delta)
		State.SEARCHING:
			_left -= delta
			if _left <= 0.0 or not Health.is_node_alive(target):
				calm()
		State.CALLING:
			_left -= delta
			if _left <= 0.0:
				_finish_call()


func _watch(delta: float) -> void:
	if not Health.is_node_alive(target):
		calm()
		return
	_since_seen += delta
	if _since_seen <= _npc.sight.interval + 0.05:
		var rate := 2.0 if _npc.flat_distance_to(last_seen_position) < near_range else 1.0
		meter = minf(meter + delta * rate, watch_time)
	elif _since_seen > grace:
		meter = maxf(meter - delta * drain_rate, 0.0)
	meter_changed.emit(meter / watch_time)
	if meter >= watch_time:
		raise_alarm(target)
	elif meter <= 0.0:
		state = State.SEARCHING
		_left = search_time


func _finish_call() -> void:
	if Health.is_node_alive(target):
		_npc.memory.remember_at(target, last_seen_position)
	calm()
