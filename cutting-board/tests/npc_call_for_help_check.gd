extends Node3D

## Headless checks for an NPC's watch and call for help (Alertness, Npc.call_for_help): a
## bandit watches the player 7 s before calling; a bandit ally in range answers and learns
## where the player really is, while a villager and a bandit out of range do not; breaking
## sight drains the watch with no call; killing the watcher stops the call; a player in a
## bandit mask is not watched. Also the chase limit (AttackTargetAction.give_up_after,
## leash_distance): a chase out of reach for too long, or too far from home, is given up,
## the player left alone a while and the NPC walks home. Prints PASS/FAIL per check and quits with the number of failures
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
	await _answer_learns_true_position()
	await _chase_given_up_after_time()
	await _chase_given_up_past_leash()
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
	await _seconds(3.0)
	_check("no call before 7 s", _calls.is_empty())
	await _seconds(1.5)
	_check("called for help after 7 s in sight", _calls.size() == 1 and _calls[0][0] == watcher)
	_check("one answer (the bandit ally)", _calls.size() == 1 and _calls[0][1] == 1)
	_check("the same-faction ally answered", _answered.has(ally))
	_check("the ally knows where the player really is", ally.memory.knows(player)
			and ally.memory.last_seen_position(player).distance_to(player.global_position) < 0.5
			and ally.memory.seconds_since_seen(player) < 1.0)
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
	player.global_position = Vector3(0, 0, -80)
	# Sight only looks every interval, so the meter may still rise a little before the
	# watcher notices the player is gone; read it once that is over.
	await _seconds(0.4)
	var meter := watcher.alertness.meter
	_check("watch meter rising (%.2f)" % meter, meter > 1.0)
	await _seconds(0.8)
	_check("meter holds during the grace", watcher.alertness.meter >= meter - 0.05)
	# Grace, then the meter drains at drain_rate: wait for it with some slack, rather
	# than on a fixed clock that a fuller meter overruns.
	var drained := await _wait_until(func() -> bool:
		return watcher.alertness.state != Alertness.State.WATCHING, 8.0)
	_check("meter drained, searching the last seen spot",
			drained and watcher.alertness.state == Alertness.State.SEARCHING)
	var gave_up := await _wait_until(func() -> bool:
		return watcher.alertness.state == Alertness.State.UNAWARE,
		watcher.alertness.search_time + 1.0)
	_check("gave up: unaware again", gave_up)
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


func _answer_learns_true_position() -> void:
	var player := _player(Vector3(10, 0, -10))
	var caller := _npc(BANDIT, Vector3(0, 0, 0), PI, 1.0)
	var ally := _npc(BANDIT, Vector3(0, 0, 6), PI, 1.0)
	await _seconds(0.5)
	# Called about a spot the player has long left.
	caller.call_for_help(player, Vector3(-5, 0, -5))
	_check("an answering ally learns where the player really is, not the caller's spot",
			ally.memory.knows(player)
			and ally.memory.last_seen_position(player).distance_to(player.global_position) < 0.5)
	# Lets the answer's shout go off before the ally is freed.
	await _seconds(1.5)
	await _clear([player, caller, ally])


## A bandit that sees the player straight away (no watch, no rocks) chases a player who
## keeps out of reach; it gives up after give_up_after s and walks back home.
func _chase_given_up_after_time() -> void:
	var player := _player(Vector3(0, 0, -6))
	var chaser := _chaser(Vector3(0, 0, 0), 3.0, 0.0)
	var attack := _attack_action(chaser)
	var gave_up := false
	var start := chaser.global_position
	# Stays 6 m ahead of the chaser, out of reach but in sight.
	for i in roundi(10.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if not gave_up:
			player.global_position = chaser.global_position + Vector3(0, 0, -6)
		if chaser.has_given_up_on(player):
			gave_up = true
			break
	_check("chased before giving up (%.1f m)" % chaser.flat_distance_to(start),
			chaser.flat_distance_to(start) > 1.0)
	_check("gave up the chase after give_up_after s out of reach",
			gave_up and not chaser.memory.knows(player))
	await _seconds(1.0)
	_check("ignores the player it gave up on while it still sees him",
			not chaser.memory.knows(player) and chaser.alertness.state == Alertness.State.UNAWARE
			and not chaser.brain.get_current_action() == attack)
	var home := await _wait_until(func() -> bool:
		return chaser.flat_distance_to(chaser.home) < 1.5, 20.0)
	_check("walked back home (%.1f m off, %s)" % [chaser.flat_distance_to(chaser.home), chaser.brain.get_current_action()], home)
	await _clear([player, chaser])


## The same, but the chase is cut short by the leash: too far from home.
func _chase_given_up_past_leash() -> void:
	var player := _player(Vector3(0, 0, -6))
	var chaser := _chaser(Vector3(30, 0, 30), 0.0, 10.0)
	var gave_up_at := Vector3.INF
	for i in roundi(8.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		player.global_position = chaser.global_position + Vector3(0, 0, -6)
		if chaser.has_given_up_on(player):
			gave_up_at = chaser.global_position
			break
	player.global_position = Vector3(0, 0, -100)
	_check("gave up the chase at the leash (%.1f m from home)" % chaser.home.distance_to(gave_up_at),
			gave_up_at != Vector3.INF and chaser.home.distance_to(gave_up_at) < 12.0)
	var home := await _wait_until(func() -> bool:
		return chaser.flat_distance_to(chaser.home) < 1.5, 20.0)
	_check("walked back home from the leash (%.1f m off, %s)" % [chaser.flat_distance_to(chaser.home), chaser.brain.get_current_action()], home)
	await _clear([player, chaser])


func _chaser(at: Vector3, give_up_after: float, leash: float) -> Npc:
	var npc := BANDIT.instantiate() as Npc
	npc.starting_items = []
	npc.extra_items = []
	add_child(npc)
	npc.global_position = at
	npc.home = at
	npc.alertness.watch_time = 0.0
	# Longer than any case here: the cooldown runs on the wall clock, which a loaded
	# machine running the test slower than real time would otherwise outlast.
	npc.give_up_cooldown = 60.0
	var attack := _attack_action(npc)
	attack.give_up_after = give_up_after
	attack.leash_distance = leash
	return npc


func _attack_action(npc: Npc) -> AttackTargetAction:
	for child in npc.brain.get_children():
		if child is AttackTargetAction:
			return child
	return null


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
	# No strolling: a stroll that sets off away from the player before Sight's first look
	# turns its back on him, and the watch never starts (this made the test flaky).
	for child in npc.brain.get_children():
		if child is WanderAction:
			child.base_score = 0.0
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


## Waits until `condition` holds, for at most `timeout` seconds; returns whether it did.
func _wait_until(condition: Callable, timeout: float) -> bool:
	for i in roundi(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
