extends Node3D

## Headless checks for the fence colliders: a player-sized and an NPC-sized capsule walk
## and sprint-jump into every fence piece from both sides, a rock is thrown at them, a
## melee-style ray is cast through them, and the navmesh is baked around a fence and
## around the village paddock. Prints PASS/FAIL per check and quits with the number of
## failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/fence_collision_check.tscn

const FENCE_1X1 := preload("res://scenes/environment/buildings/1x1_fence.tscn")
const FENCE_1X2 := preload("res://scenes/environment/buildings/1x2_fence.tscn")
const FENCE_CORNER := preload("res://scenes/environment/buildings/fence_1x1_corner.tscn")
const VILLAGE := preload("res://scenes/levels/village.tscn")
const ROCK := preload("res://scenes/items/rock.tscn")

## The player controller's numbers (player.gd / player.tscn).
const PLAYER_RADIUS := 0.4
const PLAYER_HEIGHT := 1.8
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
## The NPC capsule (npc_base.tscn).
const NPC_RADIUS := 0.3
const NPC_HEIGHT := 1.7

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ground := _make_ground(60.0)
	add_child(ground)

	# Each case: the scene, a point on the fence line, and the direction across it.
	var cases := [
		["1x1 middle", FENCE_1X1, Vector3(0.0, 0, 0), Vector3.BACK],
		["1x1 left end", FENCE_1X1, Vector3(-1.1, 0, 0), Vector3.BACK],
		["1x1 right end", FENCE_1X1, Vector3(1.0, 0, 0), Vector3.BACK],
		["1x2 middle", FENCE_1X2, Vector3(0.0, 0, 0), Vector3.BACK],
		["1x2 left end", FENCE_1X2, Vector3(-2.1, 0, 0), Vector3.BACK],
		["1x2 right end", FENCE_1X2, Vector3(2.1, 0, 0), Vector3.BACK],
		["corner x arm", FENCE_CORNER, Vector3(0.8, 0, 0), Vector3.BACK],
		["corner z arm", FENCE_CORNER, Vector3(0, 0, -0.7), Vector3.RIGHT],
	]
	for case in cases:
		var fence: Node3D = case[1].instantiate()
		add_child(fence)
		# The corner scene carries an offset on its root; place every piece at the origin.
		fence.transform = Transform3D.IDENTITY
		await _physics_frames(2)
		var at: Vector3 = case[2]
		var across: Vector3 = case[3]
		for side: float in [1.0, -1.0]:
			var dir: Vector3 = across * side
			var tag := "%s, from %s" % [case[0], "front" if side > 0 else "back"]
			_check("player walking is stopped: " + tag,
					await _push(at, dir, PLAYER_RADIUS, PLAYER_HEIGHT, WALK_SPEED, false))
			_check("player sprint-jumping is stopped: " + tag,
					await _push(at, dir, PLAYER_RADIUS, PLAYER_HEIGHT, SPRINT_SPEED, true))
			_check("NPC walking is stopped: " + tag,
					await _push(at, dir, NPC_RADIUS, NPC_HEIGHT, WALK_SPEED, false))
			_check("thrown rock bounces off: " + tag, await _throw_rock(at, dir))
			_check("melee ray hits the fence: " + tag, _ray_hits(fence, at, dir))
		fence.queue_free()
		await _physics_frames(2)

	await _check_nav_around_fence()
	ground.queue_free()
	await _check_paddock_nav()
	get_tree().quit(_failures)


## Moves a capsule from 2 m before the fence line toward it for two seconds (jumping
## just before it if asked) and reports whether it is still on its own side.
func _push(at: Vector3, dir: Vector3, radius: float, height: float, speed: float,
		jump: bool) -> bool:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)
	body.global_position = at - dir * 2.0
	await _physics_frames(1)
	var jumped := false
	for i in 120:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		if not body.is_on_floor():
			body.velocity += body.get_gravity() * delta
		if jump and not jumped and body.is_on_floor() and (at - body.global_position).dot(dir) < 1.4:
			body.velocity.y = JUMP_VELOCITY
			jumped = true
		body.velocity.x = dir.x * speed
		body.velocity.z = dir.z * speed
		body.move_and_slide()
	var stayed := (body.global_position - at).dot(dir) < 0.0
	body.queue_free()
	return stayed


## Throws a rock hard at the fence from 3 m away, chest high, and reports whether it
## stays on the thrower's side.
func _throw_rock(at: Vector3, dir: Vector3) -> bool:
	var rock: RigidBody3D = ROCK.instantiate()
	add_child(rock)
	rock.global_position = at - dir * 3.0 + Vector3.UP * 0.8
	rock.linear_velocity = dir * 14.0 + Vector3.UP * 1.0
	# A rock breaks on a hard enough impact, so its last position before that counts.
	var last := rock.global_position
	for i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(rock):
			break
		last = rock.global_position
	if is_instance_valid(rock):
		rock.queue_free()
	return (last - at).dot(dir) < 0.0


## Casts a ray on the default mask at knee and chest height, like MeleeAttack does, and
## reports whether both hit the fence's body.
func _ray_hits(fence: Node3D, at: Vector3, dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for y: float in [0.4, 1.0]:
		var from := at - dir * 1.5 + Vector3.UP * y
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 3.0, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not fence.is_ancestor_of(hit.collider):
			return false
	return true


## Bakes a navmesh like the levels' (fence parsed through its scene group) around one
## long fence and checks that a path across it walks around an end instead of through.
func _check_nav_around_fence() -> void:
	var region := _make_region()
	add_child(region)
	region.add_child(_make_ground(20.0))
	var fence: Node3D = FENCE_1X2.instantiate()
	region.add_child(fence)
	region.bake_navigation_mesh(false)
	await _nav_synced(region, Vector3(0, 0, -3))
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map,
			Vector3(0, 0, -3), Vector3(0, 0, 3), true)
	print("  path: ", path)
	_check("navmesh has a path past the fence", _reaches(path, Vector3(0, 0, 3)))
	_check("the path goes round an end of the fence, not through it",
			_crossing_x(path, 0.0) != INF and absf(_crossing_x(path, 0.0)) > 2.33)
	region.queue_free()
	await _physics_frames(2)


## Bakes the village with its paddock and checks a path from outside the paddock to its
## middle enters by the east gate.
func _check_paddock_nav() -> void:
	var region := _make_region()
	add_child(region)
	region.add_child(_make_ground(200.0))
	region.add_child(VILLAGE.instantiate())
	region.bake_navigation_mesh(false)
	var start := Vector3(-14.7, 0, 20.0)
	await _nav_synced(region, start)
	var goal := Vector3(-14.7, 0, 26.6)
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, start, goal, true)
	print("  paddock path: ", path)
	_check("paddock: a path from outside reaches the middle", _reaches(path, goal))
	var through_gate := false
	for p: Vector3 in path:
		if p.x > -6.5 and p.z > 24.3 and p.z < 26.7:
			through_gate = true
	_check("paddock: the path enters by the east gate", through_gate)
	_check("paddock: the path does not cut through the south fence",
			_crossing_x(path, 22.0) == INF or _crossing_x(path, 22.0) > -5.0)
	region.queue_free()


## The x where the path first crosses the line z = `z`, or INF if it never does.
func _crossing_x(path: PackedVector3Array, z: float) -> float:
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		if (a.z - z) * (b.z - z) <= 0.0 and a.z != b.z:
			return lerpf(a.x, b.x, (z - a.z) / (b.z - a.z))
	return INF


func _make_region() -> NavigationRegion3D:
	# Same settings as the level's NavigationMesh (test_level.tscn).
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	return region


## A flat ground slab, collidable and in the navigation source group, top at y = 0.
func _make_ground(size: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh.mesh = plane
	body.add_child(mesh)
	return body


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## Whether the path ends at `goal`, ignoring the navmesh's height above the ground.
func _reaches(path: PackedVector3Array, goal: Vector3) -> bool:
	if path.size() < 2:
		return false
	var end := path[path.size() - 1]
	return Vector2(end.x - goal.x, end.z - goal.z).length() < 0.5


## Waits until the navigation map has really picked up the freshly baked region: the
## bake is done, the region is on the map, `probe` snaps onto its navmesh, and the map
## has synced twice more after that. Under CPU load (parallel test runs) the map sync
## lags behind the physics frames, so this polls real conditions with a wall-time limit.
func _nav_synced(region: NavigationRegion3D, probe: Vector3) -> void:
	var map := get_world_3d().navigation_map
	var deadline := Time.get_ticks_msec() + 20000
	while region.is_baking() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not NavigationServer3D.map_get_regions(map).has(region.get_rid()):
			continue
		var snapped := NavigationServer3D.map_get_closest_point(map, probe)
		if Vector2(snapped.x - probe.x, snapped.z - probe.z).length() < 0.1:
			break
	for i in 2:
		var before := NavigationServer3D.map_get_iteration_id(map)
		while NavigationServer3D.map_get_iteration_id(map) == before \
				and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
