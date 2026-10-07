extends Node3D

## Headless checks that an NPC comes to rest where it was sent: once it has arrived it
## must stand still — no creeping, no turning on the spot, no flicking between walking
## and standing. Covers a point on open ground, a point the navigation mesh cannot reach
## (inside a block, as a wander spot can be), a wandering villager left to its brain, and
## a bandit fighting a target that stands still. Prints PASS/FAIL per check and quits
## with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/npc_arrival_check.tscn

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")

## Where the solid block stands that no path can enter.
const BLOCK_CENTER := Vector3(6, 0, 6)
const BLOCK_SIZE := Vector3(3, 2, 3)

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var region := _build_floor()
	await TestWorld.bake(region)
	await _send_to(Vector3(4, 0, -3), "open ground")
	await _send_to(Vector3(-5, 0, 2), "open ground, far")
	await _send_to(BLOCK_CENTER, "inside a block")
	await _send_to(BLOCK_CENTER + Vector3(1.8, 0, 0), "against a block")
	await _wander()
	await _fight()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## Sends a villager with its brain off to `goal` and watches it for a few seconds once
## it has come to a halt, or stopped making headway.
func _send_to(goal: Vector3, label: String) -> void:
	var npc: Npc = VILLAGER.instantiate()
	add_child(npc)
	npc.global_position = Vector3(0, 0.05, 0)
	await _physics_frames(5)
	npc.brain.shut_down()
	npc.locomotion.move_to(goal)

	# Arrived: Locomotion gave up moving, or the body has covered no ground for a second.
	var trail: Array[Vector3] = []
	var waited := 0.0
	while waited < 12.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		trail.append(npc.global_position)
		if not npc.locomotion.is_moving():
			break
		if trail.size() > 60 and _flat(trail[-1] - trail[-61]).length() < 0.3:
			break
	await _physics_frames(15)
	var stats := await _watch(npc, 3.0)
	print("  %s: arrived after %.2f s, %.2f m from the goal; then %s" % [
		label, waited, _flat(npc.global_position - goal).length(), _describe(stats)
	])
	_check_still(stats, label)
	npc.queue_free()
	await _physics_frames(2)


## A villager left to wander on its own: every pause between strolls must be a real rest.
func _wander() -> void:
	# The same strolls every run. Home is right beside the block and the strolls are
	# short, so a good share of them are aimed into it.
	seed(7)
	var npc: Npc = VILLAGER.instantiate()
	npc.position = BLOCK_CENTER + Vector3(BLOCK_SIZE.x * 0.5 + 1.0, 0.05, 0)
	(npc.get_node("Brain/Wander") as WanderAction).radius = 4.0
	add_child(npc)
	var animator: BodyAnimator = npc.get_node("%BodyAnimator")
	var blocked_strolls := 0
	var total := {path = 0.0, turn = 0.0, toggles = 0, gait = 0.0, frames = 0}
	var last_pos := npc.global_position
	var last_yaw := npc.rotation.y
	var last_moving := npc.locomotion.is_moving()
	# Seconds since Locomotion last started or stopped.
	var since := 0.0
	var elapsed := 0.0
	var dithering := 0.0
	var trail: Array[Vector3] = []
	while elapsed < 40.0:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		var moving := npc.locomotion.is_moving()
		trail.append(npc.global_position)
		if moving != last_moving:
			since = 0.0
			total.toggles += 1
			if moving and _in_block(npc.locomotion._target):
				blocked_strolls += 1
		else:
			since += delta
		# Trying to walk for a whole second but getting nowhere: walking on the spot.
		if moving and since > 1.0 and trail.size() > 60 and _flat(trail[-1] - trail[-61]).length() < 0.3:
			dithering += delta
		# The first moments of a rest are the body slowing down; after that it stands.
		if not moving and since > 0.3:
			total.path += _flat(npc.global_position - last_pos).length()
			total.turn += absf(angle_difference(last_yaw, npc.rotation.y))
			if since > 1.0:
				total.gait = maxf(total.gait, animator._gait)
			total.frames += 1
		last_moving = moving
		last_pos = npc.global_position
		last_yaw = npc.rotation.y
	print("  wander: %d starts/stops in 40 s, %d strolls aimed into the block, %.2f s walking on the spot; resting %.1f s, crept %.3f m, turned %.2f deg, gait peak %.2f" % [
		total.toggles, blocked_strolls, dithering, total.frames / 60.0, total.path, rad_to_deg(total.turn), total.gait
	])
	_check("wander: rests stand still", total.path < 0.02 and total.turn < deg_to_rad(1.0) and total.gait < 0.1)
	_check("wander: never walks on the spot", dithering < 0.5)
	npc.queue_free()
	await _physics_frames(2)


## A bandit fighting a player who stands still: once in range it holds its ground.
func _fight() -> void:
	var player := PLAYER.instantiate()
	var bandit: Npc = BANDIT.instantiate()
	add_child(player)
	add_child(bandit)
	player.global_position = Vector3(-3, 0.05, -3)
	bandit.global_position = Vector3(-3, 0.05, -9)
	await _physics_frames(5)
	var player_health: Health = player.get_node("%Health")
	player_health.max_health = 100000
	player_health.reset()
	bandit.memory.remember(player)
	var waited := 0.0
	while waited < 8.0 and bandit.flat_distance_to(player.global_position) > 1.3:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		player.global_position = Vector3(-3, player.global_position.y, -3)
	await _physics_frames(30)
	var stats := await _watch(bandit, 4.0, func() -> void:
		player.global_position = Vector3(-3, player.global_position.y, -3)
		player_health.reset())
	print("  fight: in range after %.2f s; then %s" % [waited, _describe(stats)])
	_check_still(stats, "fight")
	player.queue_free()
	bandit.queue_free()
	await _physics_frames(2)


## Follows `npc` for `seconds` and sums up how much it still moves: ground crept, yaw
## turned, how often Locomotion started or stopped, and how high the walk cycle stays.
func _watch(npc: Npc, seconds: float, each_frame := Callable()) -> Dictionary:
	var animator: BodyAnimator = npc.get_node("%BodyAnimator")
	var stats := {path = 0.0, turn = 0.0, toggles = 0, gait = 0.0, speed = 0.0}
	var last_pos := npc.global_position
	var last_yaw := npc.rotation.y
	var last_moving := npc.locomotion.is_moving()
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if each_frame.is_valid():
			each_frame.call()
		stats.path += _flat(npc.global_position - last_pos).length()
		stats.turn += absf(angle_difference(last_yaw, npc.rotation.y))
		stats.speed = maxf(stats.speed, _flat(npc.get_real_velocity()).length())
		# The walk cycle fades out over the first second; after that it must stay down.
		if elapsed > 1.0:
			stats.gait = maxf(stats.gait, animator._gait)
		if npc.locomotion.is_moving() != last_moving:
			stats.toggles += 1
		last_moving = npc.locomotion.is_moving()
		last_pos = npc.global_position
		last_yaw = npc.rotation.y
	return stats


func _describe(stats: Dictionary) -> String:
	return "crept %.3f m, turned %.2f deg, %d starts/stops, peak speed %.2f m/s, gait peak %.2f" % [
		stats.path, rad_to_deg(stats.turn), stats.toggles, stats.speed, stats.gait
	]


func _check_still(stats: Dictionary, label: String) -> void:
	_check("%s: stands still once arrived" % label,
		stats.path < 0.02 and stats.turn < deg_to_rad(1.0) and stats.toggles == 0 and stats.gait < 0.1)


## A flat floor with a solid block on it, and a navigation region baked from both, set
## up like test_level's.
func _build_floor() -> NavigationRegion3D:
	TestWorld.add_floor(self, 60)
	TestWorld.add_slab(self, BLOCK_SIZE, BLOCK_CENTER + Vector3.UP * BLOCK_SIZE.y * 0.5)
	return TestWorld.add_nav_region(self)


func _in_block(point: Vector3) -> bool:
	var offset := _flat(point - BLOCK_CENTER).abs()
	return offset.x < BLOCK_SIZE.x * 0.5 and offset.z < BLOCK_SIZE.z * 0.5


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
