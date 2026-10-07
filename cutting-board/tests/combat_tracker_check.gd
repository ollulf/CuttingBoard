extends Node3D

## Headless checks for CombatTracker and the HUD bars it drives. Prints PASS/FAIL per
## check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/combat_tracker_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const DUMMY := preload("res://scenes/characters/training_dummy.tscn")
const ROCK := preload("res://scenes/items/rock.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var player := PLAYER.instantiate()
	add_child(player)
	var dummy := DUMMY.instantiate()
	add_child(dummy)
	dummy.position = Vector3(0, 0, -20)
	var villager := VILLAGER.instantiate()
	add_child(villager)
	villager.position = Vector3(20, 0, 0)
	await _frames(3)

	var tracker: CombatTracker = player.get_node("%CombatTracker")
	tracker.linger = 0.6
	tracker.dead_target_hold = 0.3
	var health_bar: HealthBar = player.find_child("HealthBar", true, false)
	var target_bar: TargetBar = player.find_child("TargetBar", true, false)
	health_bar.hide_when_full = true
	health_bar.fade_time = 0.01
	target_bar.fade_time = 0.01
	health_bar.set_forced_visible(false)
	await _wait(0.1)

	_check("quiet at the start", not tracker.is_in_combat() and tracker.get_target() == null)
	_check("player bar hidden at full health out of combat", health_bar.modulate.a < 0.01)
	_check("target bar hidden out of combat", target_bar.modulate.a < 0.01)

	# The player's blow on the dummy.
	Health.find_in(dummy).apply_damage(DamageInfo.new(10, player))
	await _wait(0.1)
	_check("hitting something starts a fight", tracker.is_in_combat())
	_check("what was hit is the target", tracker.get_target() == dummy)
	_check("target bar shows", target_bar.modulate.a > 0.99)
	_check("player bar pinned on screen in combat at full health", health_bar.modulate.a > 0.99)
	_check("dummy named from its node", CombatTracker.name_of(dummy) == "Training Dummy")

	# A rock let go of by the player's hand and landing on the villager is the player's.
	var rock := ROCK.instantiate()
	add_child(rock)
	var hand: HandSlot = player.get_node("%HandSlotRight")
	hand.item_released.emit(rock)
	Health.find_in(villager).apply_damage(DamageInfo.new(10, rock))
	await _wait(0.05)
	_check("a thrown item's hit counts as the thrower's", tracker.get_target() == villager)
	_check("villager named from its own name", villager.name_pool.has(CombatTracker.name_of(villager)))

	# Someone else's fight is not the player's.
	Health.find_in(dummy).apply_damage(DamageInfo.new(5, villager))
	await _wait(0.05)
	_check("hits between others do not change the target", tracker.get_target() == villager)

	# Killing the target: the bar stays a moment, then goes.
	Health.find_in(villager).apply_damage(DamageInfo.new(999, player))
	await _wait(0.1)
	_check("dead target held briefly", tracker.get_target() == villager)
	await _wait(0.4)
	_check("dead target let go", tracker.get_target() == null)
	_check("target bar hidden once the target is gone", target_bar.modulate.a < 0.01)
	_check("still in combat right after the kill", tracker.is_in_combat())

	await _wait(0.6)
	_check("combat ends after linger", not tracker.is_in_combat())
	_check("player bar released after combat", health_bar.modulate.a < 0.01)

	# The dummy "dies" and stands back up: its empty bar stays and fills back up.
	tracker.linger = 3.0
	dummy.reset_delay = 0.8
	var dummy_health := Health.find_in(dummy)
	dummy_health.apply_damage(DamageInfo.new(999, player))
	await _wait(0.5)
	_check("dead dummy kept as the target past the hold", tracker.get_target() == dummy
		and target_bar.modulate.a > 0.99 and target_bar.get_target_name() == "Training Dummy")
	_check("its bar shows it empty", dummy_health.get_current() == 0 and target_bar._fill_to == 0.0)
	await _wait(0.7)
	_check("reset dummy still the target", tracker.get_target() == dummy)
	_check("its bar fills back up", dummy_health.is_alive() and target_bar._fill_to == 1.0)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
