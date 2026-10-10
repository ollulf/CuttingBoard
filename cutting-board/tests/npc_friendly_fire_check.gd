extends Node3D

## Headless checks for friendly fire: a bandit hit by another bandit (a swing or a
## thrown rock) takes no grudge, keeps its target and rallies nobody; a villager hit by
## a bandit still fights back; the player wearing a bandit mask still counts as hostile.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/npc_friendly_fire_check.tscn

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const ROCK := preload("res://scenes/items/rock.tscn")

var _failures := 0
var _player: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 80)
	await TestWorld.bake(TestWorld.add_nav_region(self))
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(30, 0.05, 30)
	var player_health: Health = _player.get_node("%Health")
	player_health.max_health = 100000
	player_health.reset()
	await _physics_frames(5)

	await _bandit_hits_bandit()
	await _villager_hit_by_bandit()
	await _disguised_player()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _bandit_hits_bandit() -> void:
	var a := _spawn(BANDIT, Vector3(0, 0.05, 0))
	var b := _spawn(BANDIT, Vector3(2, 0.05, 0))
	var c := _spawn(BANDIT, Vector3(0, 0.05, 2))
	var villager := _spawn(VILLAGER, Vector3(6, 0.05, 0))
	await _physics_frames(5)
	a.brain.shut_down()
	villager.brain.shut_down()
	b.memory.remember(villager)
	c.memory.remember(b)
	await _wait(0.5)
	var target_before := b.get_attack_target()
	b.health.apply_damage(DamageInfo.new(5, a))
	_check("bandit hit by bandit: still takes the damage", b.health.get_current() < b.health.max_health)
	_check("bandit hit by bandit: no grudge", not b.has_grudge_against(a))
	_check("bandit hit by bandit: nobody rallies against it", not c.has_grudge_against(a))
	await _wait(0.6)
	_check("bandit hit by bandit: keeps its target", b.get_attack_target() == target_before and b.get_attack_target() != a)

	# A rock thrown by a teammate is credited to it, and still forgiven.
	var rock := ROCK.instantiate() as Node3D
	add_child(rock)
	var hand: HandSlot = a.hand_left
	if not hand.is_free():
		hand.release().queue_free()
	hand.hold(rock)
	var thrown := hand.release()
	thrown.reparent(self)
	var info := DamageInfo.new(5, thrown)
	_check("thrown rock: credited to the bandit", info.get_attacker() == a)
	b.health.apply_damage(info)
	_check("thrown rock by a teammate: no grudge", not b.has_grudge_against(a))
	thrown.queue_free()
	for npc in [a, b, c, villager]:
		npc.queue_free()
	await _physics_frames(2)


func _villager_hit_by_bandit() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, 0))
	var bandit := _spawn(BANDIT, Vector3(0, 0.05, -3))
	await _physics_frames(5)
	bandit.brain.shut_down()
	villager.health.apply_damage(DamageInfo.new(5, bandit))
	await _wait(0.6)
	_check("villager hit by bandit: holds a grudge", villager.has_grudge_against(bandit))
	_check("villager hit by bandit: fights it", villager.get_attack_target() == bandit)
	villager.queue_free()
	bandit.queue_free()
	await _physics_frames(2)


func _disguised_player() -> void:
	var bandit := _spawn(BANDIT, Vector3(30, 0.05, 27))
	await _physics_frames(5)
	# Disguise: the player's faction takes on the bandits' data, as a worn mask does.
	var theirs := Faction.find_in(_player)
	theirs.data = bandit.faction.data
	bandit.health.apply_damage(DamageInfo.new(5, _player))
	_check("disguised player: a hit still earns a grudge", bandit.has_grudge_against(_player))
	bandit.queue_free()
	await _physics_frames(2)


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
