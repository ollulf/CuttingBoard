extends Node3D

## Headless checks for NPC grudges and villagers' random weapons: a villager hit by the
## player turns on the player and hurts back, the grudge runs out, a thrown rock is
## credited to its thrower, a badly hurt villager still runs, being hit by a bandit makes
## a villager fight rather than flee, allies standing by step in, and the weapons drawn
## at spawn follow their weights. Prints PASS/FAIL per check and quits with the number
## of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/villager_retaliation_check.tscn

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
	await _bake(region)
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


## The weighted pool: many draws match the weights, and fifty real spawns each end up
## with one of the pool's loadouts.
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

	# Real spawns: the hand holds the pick, a rock pick goes in the pockets.
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


## The player hits a villager: it holds a grudge, goes after the player and lands blows.
func _fights_back() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	await _physics_frames(5)
	# A known weapon, so the blows are the same every run.
	if not villager.hand_right.is_free():
		villager.hand_right.release().queue_free()
	villager.equip(load("res://resources/items/hammer.tres"), villager.hand_right)
	# Pockets emptied, so the player is hurt by a hammer blow rather than a thrown rock.
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


## A short grudge runs out while the player is still in plain sight, and the villager
## goes back to leaving the player be.
func _grudge_expires() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -3))
	villager.grudge_duration = 1.5
	await _physics_frames(5)
	villager.health.apply_damage(DamageInfo.new(5, _player))
	await _wait(0.6)
	_check("grudge: fighting while it lasts", _is_fighting(villager))
	var waited := 0.0
	while waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		_pin_player()
	_check("grudge: gone after its duration", not villager.has_grudge_against(_player))
	_check("grudge: the player is no longer a target", villager.get_attack_target() == null)
	_check("grudge: stopped fighting", not _is_fighting(villager))
	_check("grudge: player still remembered, just not fought", villager.memory.knows(_player))

	# Ending with the attacker's death.
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


## A rock let go of by the player's hand and landing on a villager is the player's hit;
## one thrown long ago is nobody's.
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


## Badly hurt, a villager runs from whoever it holds a grudge against.
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


## A bandit nearby scares a villager off; a bandit that hits it gets fought.
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


## A villager next to one that is hit, and watching it, takes up the grudge; one far
## off does not, and a villager hitting a villager rallies nobody.
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
	_check("own side: the victim holds a grudge against the villager", victim.has_grudge_against(far))
	_check("own side: nobody else takes it up", not near.has_grudge_against(far))
	for npc in [victim, near, far]:
		npc.queue_free()
	await _physics_frames(2)


# --- Helpers ----------------------------------------------------------------------------


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _is_fighting(npc: Npc) -> bool:
	var action := npc.brain.get_current_action()
	return action is AttackTargetAction or action is ThrowAtTargetAction


## Keeps the player standing where it was put, facing nobody in particular.
func _pin_player() -> void:
	_player.global_position = Vector3(0, _player.global_position.y, 0)


func _build_floor() -> NavigationRegion3D:
	var floor_body := StaticBody3D.new()
	floor_body.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)
	return region


func _bake(region: NavigationRegion3D) -> void:
	region.bake_navigation_mesh(false)
	var map := get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			break


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
