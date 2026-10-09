extends Node3D

## Headless checks for an NPC's watch and call for help (Alertness, Npc.call_for_help): a
## bandit watches the player 5 s before calling; a bandit ally in range answers and learns
## where the player is, while a villager and a bandit out of range do not; breaking sight
## drains the watch with no call; killing the watcher stops the call; a player in a bandit
## mask is not watched. Prints PASS/FAIL per check and quits with the number of failures
## as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/npc_call_for_help_check.tscn

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const PLAYER_FACTION := preload("res://resources/factions/player.tres")
const BANDIT_FACTION := preload("res://resources/factions/bandits.tres")

var _failures := 0
## Every call made in the current case: [caller, answers].
var _calls: Array = []
## Every NPC that answered a call in the current case.
var _answered: Array[Npc] = []


func _ready() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0, -0.5, 0)
	add_child(floor)
	_run.call_deferred()


func _run() -> void:
	await _watch_then_call()
	await _broken_sight_no_call()
	await _killed_watcher_no_call()
	await _same_mask_not_watched()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _watch_then_call() -> void:
	var player := _player(Vector3(0, 0, -8))
	var watcher := _npc(BANDIT, Vector3(0, 0, 0), 0.0, 140.0)
	var ally := _npc(BANDIT, Vector3(0, 0, 6), PI, 1.0)
	var villager := _npc(VILLAGER, Vector3(-4, 0, 5), PI, 1.0)
	var far := _npc(BANDIT, Vector3(0, 0, 25), PI, 1.0)
	await _seconds(3.0)
	_check("watching after 3 s, not yet fighting",
			watcher.alertness.state == Alertness.State.WATCHING and not watcher.memory.knows(player))
	_check("no call before 5 s", _calls.is_empty())
	await _seconds(3.5)
	_check("called for help after 5 s in sight", _calls.size() == 1 and _calls[0][0] == watcher)
	_check("one answer (the bandit ally)", _calls.size() == 1 and _calls[0][1] == 1)
	_check("the same-faction ally answered", _answered.has(ally))
	_check("the ally knows where the player is", ally.memory.knows(player)
			and ally.memory.last_seen_position(player).distance_to(player.global_position) < 1.0)
	_check("the villager did not answer", not _answered.has(villager))
	_check("the bandit 25 m away did not hear it", not _answered.has(far) and not far.memory.knows(player))
	# The call lasts call_time, and the Brain thinks a few times a second.
	await _seconds(1.5)
	_check("the watcher fights after the call", watcher.memory.knows(player)
			and watcher.is_in_combat())
	await _clear([player, watcher, ally, villager, far])


func _broken_sight_no_call() -> void:
	var player := _player(Vector3(0, 0, -8))
	var watcher := _npc(BANDIT, Vector3(0, 0, 0), 0.0, 140.0)
	var ally := _npc(BANDIT, Vector3(0, 0, 6), PI, 1.0)
	await _seconds(2.0)
	var meter := watcher.alertness.meter
	_check("watch meter rising (%.2f)" % meter, meter > 1.0)
	player.global_position = Vector3(0, 0, -80)
	await _seconds(1.2)
	_check("meter holds during the grace", is_equal_approx(watcher.alertness.meter, meter)
			or watcher.alertness.meter >= meter - 0.05)
	await _seconds(4.5)
	_check("meter drained, searching the last seen spot",
			watcher.alertness.state == Alertness.State.SEARCHING)
	await _seconds(4.5)
	_check("gave up: unaware again", watcher.alertness.state == Alertness.State.UNAWARE)
	_check("no call when sight was broken", _calls.is_empty() and not ally.memory.knows(player))
	_check("watcher does not fight", not watcher.memory.knows(player))
	await _clear([player, watcher, ally])


func _killed_watcher_no_call() -> void:
	var player := _player(Vector3(0, 0, -8))
	var watcher := _npc(BANDIT, Vector3(0, 0, 0), 0.0, 140.0)
	var ally := _npc(BANDIT, Vector3(0, 0, 6), PI, 1.0)
	await _seconds(2.0)
	watcher.health.apply_damage(DamageInfo.new(10000))
	await _seconds(5.0)
	_check("killed during the watch: no call", _calls.is_empty() and not ally.memory.knows(player))
	await _clear([player, watcher, ally])


func _same_mask_not_watched() -> void:
	var player := _player(Vector3(0, 0, -8))
	Faction.find_in(player).data = BANDIT_FACTION
	var watcher := _npc(BANDIT, Vector3(0, 0, 0), 0.0, 140.0)
	await _seconds(2.0)
	_check("a player in a bandit's mask is not watched by bandits",
			watcher.alertness.state == Alertness.State.UNAWARE and _calls.is_empty())
	await _clear([player, watcher])


## A stand-in for the player: an actor of the player faction, with no body.
func _player(at: Vector3) -> Node3D:
	var player := Node3D.new()
	var faction := Faction.new()
	faction.name = "Faction"
	faction.data = PLAYER_FACTION
	player.add_child(faction)
	add_child(player)
	player.global_position = at
	return player


func _npc(scene: PackedScene, at: Vector3, yaw: float, fov: float) -> Npc:
	var npc := scene.instantiate() as Npc
	add_child(npc)
	npc.global_position = at
	npc.rotation.y = yaw
	npc.home = at
	npc.sight.field_of_view = fov
	npc.called_for_help.connect(func(_t: Node3D, answers: int) -> void: _calls.append([npc, answers]))
	npc.answering.connect(func(_c: Npc, _t: Node3D) -> void: _answered.append(npc))
	return npc


func _clear(nodes: Array) -> void:
	for node in nodes:
		node.queue_free()
	_calls.clear()
	_answered.clear()
	await get_tree().physics_frame


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
