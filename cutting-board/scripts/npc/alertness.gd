class_name Alertness
extends Node

## How an NPC goes from noticing an enemy to raising the alarm. A hostile actor it does
## not know of yet is not fought at once: the NPC stops and watches it, and a meter fills
## while it stays in sight. Full, the NPC calls for help (Npc.call_for_help) and only then
## learns of the enemy in Memory, which is what starts the fight. Lost from sight, the
## meter waits a moment, then drains; empty, the NPC searches where it last saw the enemy
## and gives up without calling. WatchAction plays all of this out on the body.
##
## Only hostile actors are watched, and hostility follows the worn mask, so a player in a
## bandit's face walks past bandits unwatched.

signal meter_changed(fraction: float)

enum State { UNAWARE, WATCHING, SEARCHING, CALLING }

## Seconds of being seen before the NPC calls for help. 0 turns watching off: an enemy
## is fought (or fled) the moment it is seen, as before.
@export var watch_time := 7.0
## An enemy this close ends the watch at once with a short call.
@export var close_range := 3.0
## The meter fills twice as fast for an enemy closer than this.
@export var near_range := 5.0
## Seconds out of sight before the meter starts to drain, so a quick peek back does not
## start the watch over.
@export var grace := 1.5
## How fast the meter drains out of sight, against how fast it filled.
@export var drain_rate := 0.5
## Seconds spent looking around the last seen spot before giving up.
@export var search_time := 4.0
## Seconds the call lasts before the NPC attacks.
@export var call_time := 1.0
## Extra seconds of silence after a call nobody answered, before it attacks alone.
@export var unanswered_pause := 1.0

var state := State.UNAWARE
## The actor being watched, searched for or called about.
var target: Node3D
## Seconds of watching built up, 0 to watch_time.
var meter := 0.0
var last_seen_position := Vector3.ZERO

var _since_seen := 0.0
## Seconds left of the search or the call.
var _left := 0.0

@onready var _npc: Npc = owner


## Whether a sighting of `actor` should be watched rather than fought straight away.
func wants_to_watch(actor: Node3D) -> bool:
	if watch_time <= 0.0 or not _npc.faction.is_hostile_to(actor):
		return false
	if _npc.memory.knows(actor) or _npc.has_grudge_against(actor):
		return false
	# One at a time: another enemy is fought straight away rather than watched too.
	if (state == State.WATCHING or state == State.CALLING) and is_instance_valid(target):
		return actor == target
	return true


## Sight saw `actor`, one wants_to_watch said yes to.
func see(actor: Node3D) -> void:
	if state == State.UNAWARE or state == State.SEARCHING or actor != target:
		state = State.WATCHING
		target = actor
		meter = 0.0
	last_seen_position = actor.global_position
	_since_seen = 0.0
	if state == State.WATCHING and _npc.flat_distance_to(actor.global_position) <= close_range:
		raise_alarm(actor, true)


## Calls for help about `actor` and turns on it. `short` skips the call's wait, for an
## enemy already at arm's length or one that has just struck.
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


## Drops whatever is being watched, without a call: the NPC died, or heard an ally call
## about it and is coming anyway.
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
	# Seen on Sight's latest look: Sight only looks every interval.
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


## The call is over: the NPC now knows of its enemy, and the fight starts.
func _finish_call() -> void:
	if Health.is_node_alive(target):
		_npc.memory.remember_at(target, last_seen_position)
	calm()
