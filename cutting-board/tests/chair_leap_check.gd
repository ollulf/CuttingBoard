extends Node3D

const CREATURE := preload("res://scenes/characters/chair_creature.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const STEP := 1.0 / 60.0

var _failures := 0
var _slams: Array = []
var _frame := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	await TestWorld.bake(TestWorld.add_nav_region(self))

	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.1, -6.3)
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

	var start_health := player_health.get_current()
	var hurt_before_slam := false
	var frames := 0
	var launch_distance := -1.0
	while _slams.is_empty() and frames < 600:
		await get_tree().physics_frame
		_frame += 1
		frames += 1
		if launch_distance < 0.0 and creature.get_state() == creature.State.WIND_UP:
			launch_distance = _flat_distance(creature, player)
		if _slams.is_empty() and player_health.get_current() != start_health:
			hurt_before_slam = true
	_check("launches from about 6 m (%.2f m)" % launch_distance, launch_distance >= 5.5)
	_check("leaps and slams within 10 s", not _slams.is_empty())
	if _slams.is_empty():
		_finish()
		return
	var first: Dictionary = _slams[0]
	_check("the slam hits the player standing still", first.hit)
	_check("no damage before the contact frame", not hurt_before_slam)
	_check("damage lands on the contact frame (%d -> %d)" % [start_health, first.health],
		start_health - first.health == creature.slam_damage)

	var waited := 0.0
	while creature.get_state() != creature.State.WIND_UP and waited < 10.0:
		await get_tree().physics_frame
		_frame += 1
		waited += STEP
	var least: float = creature.recover_time + creature.cooldown
	_check("waits out the cooldown before the next leap (%.2f s, at least %.2f)" % [waited, least],
		waited >= least - 0.05 and waited < 10.0)

	Health.find_in(creature).apply_damage(DamageInfo.new(5, player))
	await _until(func() -> bool: return creature.is_leaping(), 1.0)
	_check("a hit during the wind-up does not cancel the leap", creature.is_leaping())

	player.global_position += creature.global_basis.x * 3.0
	var before := player_health.get_current()
	await _until(func() -> bool: return _slams.size() >= 2, 2.0)
	_check("slams again", _slams.size() >= 2)
	if _slams.size() >= 2:
		_check("a dodged leap misses", not (_slams[1] as Dictionary).hit)
		_check("a dodged leap deals no damage", player_health.get_current() == before)
	creature.queue_free()
	await _check_wall(player)
	_check_edge()
	await _check_loot(player)
	_finish()


func _check_wall(player: Node3D) -> void:
	player.global_position = Vector3(15, 0.1, -6)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.4)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(15, 1.5, -3)
	var creature: CharacterBody3D = CREATURE.instantiate()
	add_child(creature)
	creature.global_position = Vector3(15, 0.05, 0)
	await get_tree().physics_frame
	creature._target = player
	creature._wind_up()
	creature._launch()
	var count := _slams.size()
	creature.slammed.connect(func(hit: bool) -> void: _slams.append({"hit": hit}))
	await _until(func() -> bool: return _slams.size() > count, 2.0)
	_check("a leap into a wall comes down", _slams.size() > count)
	_check("the wall stops it (z %.2f)" % creature.global_position.z,
		creature.global_position.z > -3.0 + 0.2)
	creature.queue_free()
	wall.queue_free()


func _check_edge() -> void:
	var creature: CharacterBody3D = CREATURE.instantiate()
	add_child(creature)
	creature.global_position = Vector3(-27.5, 0.05, 10)
	var run: float = creature.leap_run(Vector3.LEFT, 6.0)
	_check("a leap toward a drop is cut short (%.2f m of 6)" % run, run < 2.5)
	var inland: float = creature.leap_run(Vector3.RIGHT, 6.0)
	_check("a leap over open ground keeps its length (%.2f m)" % inland, is_equal_approx(inland, 6.0))
	creature.queue_free()


func _check_loot(player: Node3D) -> void:
	player.global_position = Vector3(-15, 0.1, -15)
	var creature: CharacterBody3D = CREATURE.instantiate()
	creature.no_loot_weight = 0.0
	add_child(creature)
	creature.global_position = Vector3(-15, 0.05, 15)
	await get_tree().physics_frame
	var pockets: Inventory = creature.inventory
	_check("it carries something (%d item(s))" % pockets.get_entries().size(),
		not pockets.is_empty())
	var interactor: Interactor = player.get_node("%Interactor")
	_check("nothing to search while it lives", interactor._container_of(creature) == null)
	Health.find_in(creature).apply_damage(DamageInfo.new(1000, player))
	await TestWorld.physics_frames(self, 30)
	_check("the body keeps its items", not pockets.is_empty())
	_check("the body can be searched", interactor._container_of(creature) == pockets)
	var ray := PhysicsRayQueryParameters3D.create(
		creature.global_position + Vector3(0.2, 3, 0.2), creature.global_position + Vector3(0.2, -1, 0.2))
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	_check("the interaction ray finds the body", hit.get("collider") == creature)
	var pack: Inventory = player.get_node("%Inventory")
	for entry in pack.get_entries().duplicate():
		pack.remove(entry)
	var taken := 0
	for entry in pockets.get_entries().duplicate():
		if pack.add(entry.data, entry.durability):
			pockets.remove(entry)
			taken += 1
	_check("the player takes them (%d)" % taken, taken > 0 and pockets.is_empty())


func _flat_distance(a: Node3D, b: Node3D) -> float:
	var off := b.global_position - a.global_position
	return Vector2(off.x, off.z).length()


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
