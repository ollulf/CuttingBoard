extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const ROCK := preload("res://scenes/items/rock.tscn")

var _failures := 0
var _player: Node3D
var _player_health: Health


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(11)
	var region := _build_floor()
	await TestWorld.bake(region)
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(0, 0.05, 0)
	await _physics_frames(5)
	_player_health = _player.get_node("%Health")
	_player_health.max_health = 100000
	_player_health.reset()

	await _weapon_weights()
	await _fights_back()
	await _grudge_expires()
	await _thrown_rock()
	await _wounded_flees()
	await _bandit_hit()
	await _allies()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _weapon_weights() -> void:
	var villager := _spawn(VILLAGER, Vector3(20, 0.05, 20))
	await _physics_frames(3)
	var expected := {}
	var total := villager.bare_hands_weight
	for i in villager.weapon_pool.size():
		total += villager.weapon_weights[i]
	for i in villager.weapon_pool.size():
		expected[villager.weapon_pool[i].display_name] = villager.weapon_weights[i] / total
	expected["bare hands"] = villager.bare_hands_weight / total

	var counts := {}
	var draws := 6000
	for i in draws:
		var picked := villager.pick_random_weapon()
		var key := picked.display_name if picked else "bare hands"
		counts[key] = counts.get(key, 0) + 1
	var worst := 0.0
	var line := PackedStringArray()
	for key in expected:
		var share := float(counts.get(key, 0)) / draws
		worst = maxf(worst, absf(share - expected[key]))
		line.append("%s %.3f (want %.3f)" % [key, share, expected[key]])
	print("  %d draws: %s" % [draws, ", ".join(line)])
	_check("draws follow the weights (within 0.025)", worst < 0.025)
	villager.queue_free()

	var spawned: Array[Npc] = []
	for i in 50:
		spawned.append(_spawn(VILLAGER, Vector3(-25 + (i % 10) * 5, 0.05, 15 + (i / 10) * 2.5)))
	await _physics_frames(3)
	var seen := {}
	var all_valid := true
	for npc in spawned:
		var held := npc.hand_right.get_item_data()
		var rocks := 0
		for entry in npc.inventory.get_entries():
			if entry.data and entry.data.throwable:
				rocks += 1
		var key := ""
		if held:
			key = held.display_name
			all_valid = all_valid and held.is_weapon() and rocks == 1
		elif rocks == 2:
			key = "Rock"
		elif rocks == 1:
			key = "bare hands"
		else:
			all_valid = false
		seen[key] = seen.get(key, 0) + 1
		all_valid = all_valid and npc.hand_left.is_free()
	print("  50 spawns: %s" % [seen])
	_check("every spawn holds one pool weapon, extra rocks or nothing", all_valid)
	_check("spawns are not all alike", seen.size() >= 3)
	for npc in spawned:
		npc.queue_free()
	await _physics_frames(2)


func _fights_back() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	await _physics_frames(5)
	if not villager.hand_right.is_free():
		villager.hand_right.release().queue_free()
	villager.equip(load("res://resources/items/hammer.tres"), villager.hand_right)
	for entry in villager.inventory.get_entries():
		villager.inventory.remove(entry)
	_pin_player()
	await _wait(1.0)
	_check("a villager left alone does not attack the player", villager.get_attack_target() == null)

	_player_health.reset()
	villager.health.apply_damage(DamageInfo.new(5, _player))
	_check("hit by the player: holds a grudge", villager.has_grudge_against(_player))
	_check("hit by the player: the player is its target", villager.get_attack_target() == _player)
	var fought := false
	var hurt := false
	var waited := 0.0
	while waited < 8.0 and not hurt:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		_pin_player()
		var action := villager.brain.get_current_action()
		fought = fought or action is AttackTargetAction or action is ThrowAtTargetAction
		hurt = _player_health.get_current() < _player_health.max_health
	print("  fights back: player hurt after %.2f s (%d damage)" % [waited, _player_health.max_health - _player_health.get_current()])
	_check("hit by the player: attacks the player", fought)
	_check("hit by the player: hurts the player", hurt)
	villager.queue_free()
	await _physics_frames(2)


func _grudge_expires() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	villager.grudge_duration = 1.5
	await _physics_frames(5)
	villager.health.apply_damage(DamageInfo.new(5, _player))
	await _wait(0.6)
	_check("grudge: fighting while it lasts", _is_fighting(villager))
	var waited := 0.0
	var wall_start := Time.get_ticks_msec()
	while waited < 3.0 or Time.get_ticks_msec() - wall_start < 3000:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		_pin_player()
	_check("grudge: gone after its duration", not villager.has_grudge_against(_player))
	_check("grudge: the player is no longer a target", villager.get_attack_target() == null)
	_check("grudge: stopped fighting", not _is_fighting(villager))
	_check("grudge: player still remembered, just not fought", villager.memory.knows(_player))

	var bandit := _spawn(BANDIT, Vector3(4, 0.05, -3))
	await _physics_frames(3)
	bandit.brain.shut_down()
	villager.grudge_duration = 30.0
	villager.health.apply_damage(DamageInfo.new(5, bandit))
	_check("grudge: held against a bandit", villager.has_grudge_against(bandit))
	bandit.health.apply_damage(DamageInfo.new(9999, _player))
	_check("grudge: ends when the attacker dies", not villager.has_grudge_against(bandit))
	villager.queue_free()
	bandit.queue_free()
	await _physics_frames(2)


func _thrown_rock() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -6))
	await _physics_frames(5)
	villager.brain.shut_down()
	var rock := ROCK.instantiate() as Node3D
	add_child(rock)
	var hand: HandSlot = _player.get_node("%HandSlotRight")
	if not hand.is_free():
		hand.release().queue_free()
	hand.hold(rock)
	var thrown := hand.release()
	thrown.reparent(self)
	var info := DamageInfo.new(5, thrown)
	_check("thrown rock: attacker is the thrower", info.get_attacker() == _player)
	villager.health.apply_damage(info)
	_check("thrown rock: villager holds a grudge against the thrower", villager.has_grudge_against(_player))
	_check("thrown rock: no grudge against the rock", not villager.has_grudge_against(thrown))

	thrown.set_meta(HandSlot.RELEASED_AT_META, Time.get_ticks_msec() / 1000.0 - 10.0)
	_check("old throw: credited to nobody but the rock", DamageInfo.new(5, thrown).get_attacker() == thrown)
	thrown.queue_free()
	villager.queue_free()
	await _physics_frames(2)


func _wounded_flees() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	await _physics_frames(5)
	villager.health.apply_damage(DamageInfo.new(roundi(villager.health.max_health * 0.85), _player))
	await _wait(0.8)
	_pin_player()
	_check("wounded: still holds the grudge", villager.has_grudge_against(_player))
	_check("wounded: flees instead of fighting", villager.brain.get_current_action() is FleeAction)
	villager.queue_free()
	await _physics_frames(2)


func _bandit_hit() -> void:
	_player.global_position = Vector3(25, 0.05, -25)
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	var bandit := _spawn(BANDIT, Vector3(0, 0.05, -6))
	await _physics_frames(5)
	bandit.brain.shut_down()
	villager.memory.remember(bandit)
	await _wait(0.6)
	_check("bandit near: villager flees as before", villager.brain.get_current_action() is FleeAction)
	villager.health.apply_damage(DamageInfo.new(5, bandit))
	await _wait(0.6)
	_check("bandit hit it: villager fights the bandit", _is_fighting(villager) and villager.get_attack_target() == bandit)
	villager.queue_free()
	bandit.queue_free()
	_player.global_position = Vector3(0, 0.05, 0)
	await _physics_frames(2)


func _allies() -> void:
	var victim := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	var near := _spawn(VILLAGER, Vector3(2, 0.05, -3))
	var far := _spawn(VILLAGER, Vector3(-12, 0.05, -3))
	await _physics_frames(5)
	for npc in [victim, near, far]:
		npc.brain.shut_down()
	near.memory.remember(victim)
	far.memory.remember(victim)
	victim.health.apply_damage(DamageInfo.new(5, _player))
	_check("allies: one watching close by joins in", near.has_grudge_against(_player))
	_check("allies: one far off does not", not far.has_grudge_against(_player))

	near.memory.remember(victim)
	victim.health.apply_damage(DamageInfo.new(5, far))
	_check("own side: the victim takes no grudge against the villager", not victim.has_grudge_against(far))
	_check("own side: nobody else takes it up", not near.has_grudge_against(far))
	for npc in [victim, near, far]:
		npc.queue_free()
	await _physics_frames(2)


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _is_fighting(npc: Npc) -> bool:
	var action := npc.brain.get_current_action()
	return action is AttackTargetAction or action is ThrowAtTargetAction


func _pin_player() -> void:
	_player.global_position = Vector3(0, _player.global_position.y, 0)


func _build_floor() -> NavigationRegion3D:
	TestWorld.add_floor(self, 80)
	return TestWorld.add_nav_region(self)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
