extends Node3D

## Headless checks that an attacker never hurts itself: a bandit swinging point-blank
## must hit its target and not its own limbs, a rock thrown back through its own body
## must not land on it, and a bandit left to fight the player must keep a stand-off
## rather than closing into the player's body. Prints PASS/FAIL per check and quits with
## the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/self_hit_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const ROCK := preload("res://resources/items/rock.tres")

## Seconds of free fighting between the bandit and the player.
@export var fight_seconds := 20.0

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	await _point_blank_swings()
	await _throw_through_own_body()
	await _free_fight()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## The bandit stands still and swings at a villager placed all around it, from inside
## its capsule out to the edge of its reach.
func _point_blank_swings() -> void:
	var bandit: Npc = BANDIT.instantiate()
	var villager: Npc = VILLAGER.instantiate()
	add_child(bandit)
	add_child(villager)
	await _frames(5)
	bandit.brain.shut_down()
	villager.brain.shut_down()
	_tough(bandit.health)
	_tough(villager.health)
	var self_hits := _count_hits(bandit.health, bandit)
	var target_hits := _count_hits(villager.health, bandit)

	var swings := 0
	for step in 10:
		var distance := 0.4 + step * 0.1
		for angle in [-40.0, -20.0, 0.0, 20.0, 40.0]:
			bandit.global_position = Vector3.ZERO
			bandit.velocity = Vector3.ZERO
			bandit.rotation.y = 0.0
			var offset := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle)) * distance
			villager.global_position = offset
			villager.velocity = Vector3.ZERO
			bandit.locomotion.face(offset)
			await _physics_frames(2)
			# Swing again as soon as each blow has landed, so a blow lands while the
			# last one's flinch is still playing out on both bodies.
			for i in 3:
				bandit.strike_at(villager)
				swings += 1
				while bandit.is_striking():
					await _physics_frames(1)
			_tough(bandit.health)
			_tough(villager.health)

	print("  point-blank: %d swings, %d on the target, %d on itself" % [
		swings, target_hits[0], self_hits[0]
	])
	_check("bandit never hits itself point-blank", self_hits[0] == 0)
	_check("bandit hits the target point-blank", target_hits[0] > swings / 2)
	bandit.queue_free()
	villager.queue_free()
	await _frames(2)


## A rock thrown straight back through the thrower's own torso — the worst case for a
## throw that leaves a hand at the body's side.
func _throw_through_own_body() -> void:
	var bandit: Npc = BANDIT.instantiate()
	add_child(bandit)
	await _frames(5)
	bandit.brain.shut_down()
	_tough(bandit.health)
	var self_hits := _count_hits(bandit.health, null)
	for i in 6:
		var hand := bandit.hand_left
		if not hand.is_free():
			bandit.stow(hand)
		bandit.equip(ROCK, hand)
		await _physics_frames(2)
		var launch := (bandit.global_position + Vector3.UP * 1.2 - hand.global_position)
		bandit.throw_from(hand, launch.normalized() * 14.0)
		await _physics_frames(20)
	print("  thrown through own body: %d hits on itself" % self_hits[0])
	_check("a thrown rock never hits its thrower", self_hits[0] == 0)
	bandit.queue_free()
	await _frames(2)


## The bandit's own brain against the player, who stands still: it should land blows,
## never hurt itself, and not end up standing inside the player.
func _free_fight() -> void:
	var player := PLAYER.instantiate()
	var bandit: Npc = BANDIT.instantiate()
	add_child(player)
	add_child(bandit)
	player.global_position = Vector3.ZERO
	bandit.global_position = Vector3(0, 0, -6)
	await _frames(5)
	var player_health: Health = player.get_node("%Health")
	_tough(player_health)
	_tough(bandit.health)
	bandit.memory.remember(player)
	var self_hits := _count_hits(bandit.health, bandit)
	var player_hits := _count_hits(player_health, bandit)

	var closest := INF
	var close_time := 0.0
	var elapsed := 0.0
	while elapsed < fight_seconds:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		# Something else could wander the player off; keep them where they stand.
		player.global_position = Vector3.ZERO
		var distance := bandit.flat_distance_to(player.global_position)
		# The approach is not the stand-off: only count from the first blow on.
		if player_hits[0] > 0:
			closest = minf(closest, distance)
			if distance < 0.85:
				close_time += delta
		_tough(player_health)
		_tough(bandit.health)

	print("  free fight: %d blows on the player, %d on itself, closest %.2f m, %.2f s inside 0.85 m" % [
		player_hits[0], self_hits[0], closest, close_time
	])
	_check("bandit never hits itself in a fight", self_hits[0] == 0)
	_check("bandit lands blows on the player", player_hits[0] >= 5)
	_check("bandit does not linger inside the player's body", close_time < 0.5)
	player.queue_free()
	bandit.queue_free()


## Counts hits on `health`, from `source` or from anything when it is null. The count is
## boxed in an array so the lambda can write to it.
func _count_hits(health: Health, source: Node) -> Array[int]:
	var count: Array[int] = [0]
	health.damaged.connect(
		func(info: DamageInfo) -> void:
			if source == null or info.source == source:
				count[0] += 1
	)
	return count


## Enough health that nothing in the test can kill it.
func _tough(health: Health) -> void:
	health.max_health = 100000
	health.reset()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
