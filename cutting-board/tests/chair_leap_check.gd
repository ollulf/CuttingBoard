extends Node3D

## Headless checks for the walking chair as an enemy (scenes/characters/chair_creature.tscn):
## it goes for the player once it sees them and the player's CombatTracker takes it as
## a fight; its launch attack hurts only on the contact frame, a hit on its wind-up does
## not stop it, a player who steps aside during the leap takes nothing, and it waits out
## its cooldown between leaps. Prints PASS/FAIL per check and quits with the number of
## failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/chair_leap_check.tscn

const CREATURE := preload("res://scenes/characters/chair_creature.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const STEP := 1.0 / 60.0

var _failures := 0
var _slams: Array = []
## The player's health on every physics frame, and the frame each slam came on.
var _frame := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	await TestWorld.bake(TestWorld.add_nav_region(self))

	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.1, -7)
	var player_health := Health.find_in(player)
	var tracker: CombatTracker = player.get_node("%CombatTracker")

	var creature: CharacterBody3D = CREATURE.instantiate()
	add_child(creature)
	creature.global_position = Vector3(0, 0.05, 0)
	creature.slammed.connect(func(hit: bool) -> void:
		_slams.append({"hit": hit, "frame": _frame, "health": player_health.get_current()}))

	_check("the chair is hostile to the player",
		(creature.get_node("%Faction") as Faction).is_hostile_to(player))
	_check("named over its bar", CombatTracker.name_of(creature) == "Walking Chair")

	await _until(func() -> bool: return creature.get_attack_target() == player, 2.0)
	_check("goes for the player once seen", creature.get_attack_target() == player)
	await _until(func() -> bool: return tracker.is_targeted(), 1.0)
	_check("the player's tracker counts it as a fight",
		tracker.is_targeted() and tracker.is_in_combat())

	# First leap: the player stands still and takes it, on the slam and not before.
	var start_health := player_health.get_current()
	var hurt_before_slam := false
	var frames := 0
	while _slams.is_empty() and frames < 600:
		await get_tree().physics_frame
		_frame += 1
		frames += 1
		if _slams.is_empty() and player_health.get_current() != start_health:
			hurt_before_slam = true
	_check("leaps and slams within 10 s", not _slams.is_empty())
	if _slams.is_empty():
		_finish()
		return
	var first: Dictionary = _slams[0]
	_check("the slam hits the player standing still", first.hit)
	_check("no damage before the contact frame", not hurt_before_slam)
	_check("damage lands on the contact frame (%d -> %d)" % [start_health, first.health],
		start_health - first.health == creature.slam_damage)

	# The cooldown: no new wind-up until recovery and cooldown have passed.
	var waited := 0.0
	while creature.get_state() != creature.State.WIND_UP and waited < 10.0:
		await get_tree().physics_frame
		_frame += 1
		waited += STEP
	var least: float = creature.recover_time + creature.cooldown
	_check("waits out the cooldown before the next leap (%.2f s, at least %.2f)" % [waited, least],
		waited >= least - 0.05 and waited < 10.0)

	# A blow during the wind-up does not stop it.
	Health.find_in(creature).apply_damage(DamageInfo.new(5, player))
	await _until(func() -> bool: return creature.is_leaping(), 1.0)
	_check("a hit during the wind-up does not cancel the leap", creature.is_leaping())

	# The player steps aside as it leaps: the slam finds nobody.
	player.global_position += creature.global_basis.x * 3.0
	var before := player_health.get_current()
	await _until(func() -> bool: return _slams.size() >= 2, 2.0)
	_check("slams again", _slams.size() >= 2)
	if _slams.size() >= 2:
		_check("a dodged leap misses", not (_slams[1] as Dictionary).hit)
		_check("a dodged leap deals no damage", player_health.get_current() == before)
	_finish()


func _until(done: Callable, seconds: float) -> void:
	var waited := 0.0
	while not done.call() and waited < seconds:
		await get_tree().physics_frame
		_frame += 1
		waited += STEP


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1
