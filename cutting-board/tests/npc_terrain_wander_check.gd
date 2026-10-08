extends Node3D

## Headless check that NPCs in the real level walk across the terrain without dithering
## on one spot. Loads the test level, switches every NPC's brain off so no fight or
## flight gets in the way, and keeps sending each one on strolls about where it stands,
## as its wander would. Per NPC it counts the seconds spent walking on open ground while
## covering almost no ground, and the times its facing swung back and forth. Prints a
## line per NPC, PASS/FAIL, and quits with the number of failures as the exit code.
##
## On terrain the navigation mesh floats about half a metre above the ground, and the
## path's waypoints with it; a body that passes waypoints by 3D distance hardly ever
## reaches one and circles it instead. This check catches that.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/npc_terrain_wander_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
## Seconds of strolling watched.
const WATCH_TIME := 30.0
## How far from where it started a stroll can take an NPC, in metres.
const STROLL_RADIUS := 8.0
## A stroll that has not arrived after this many seconds is given up, as the wander does.
const GIVE_UP_AFTER := 10.0
## A walking NPC that covers less than this flat distance in a second is dithering.
const STUCK_DISTANCE := 0.3

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(11)
	var level := LEVEL.instantiate()
	add_child(level)
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	if region.navigation_mesh.get_polygon_count() == 0:
		await region.bake_finished
	await TestWorld.physics_frames(self, 30)

	var npcs: Array[Npc] = []
	for node in level.find_children("*", "Npc", true, false):
		var npc := node as Npc
		npc.brain.shut_down()
		npc.locomotion.stop()
		npc.locomotion.clear_facing()
		npcs.append(npc)
	var homes := {}
	var trails := {}
	var stuck := {}
	var flips := {}
	var last_turn := {}
	var yaw := {}
	var walking_for := {}
	var notes := {}
	for npc in npcs:
		homes[npc] = npc.global_position
		trails[npc] = []
		stuck[npc] = 0.0
		flips[npc] = 0
		last_turn[npc] = 0.0
		yaw[npc] = npc.rotation.y
		walking_for[npc] = 0.0
		notes[npc] = ""
	var elapsed := 0.0
	while elapsed < WATCH_TIME:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		for npc in npcs:
			if not npc.locomotion.is_moving() or walking_for[npc] > GIVE_UP_AFTER:
				var angle := randf() * TAU
				var distance := randf_range(STROLL_RADIUS * 0.3, STROLL_RADIUS)
				npc.locomotion.stop()
				npc.locomotion.move_to(homes[npc] + Vector3(cos(angle), 0.0, sin(angle)) * distance)
				walking_for[npc] = 0.0
			walking_for[npc] += dt
			var trail: Array = trails[npc]
			trail.append(npc.global_position)
			var turn := angle_difference(yaw[npc], npc.rotation.y)
			yaw[npc] = npc.rotation.y
			if absf(turn) > 0.002:
				if last_turn[npc] != 0.0 and signf(turn) != signf(last_turn[npc]):
					flips[npc] += 1
				last_turn[npc] = turn
			# Walking on open ground: pressed against something — a loose crate the
			# navigation mesh does not know about — is a different matter.
			if npc.is_on_wall() or trail.size() <= 60:
				continue
			var moved := Vector2(trail[-1].x - trail[-61].x, trail[-1].z - trail[-61].z).length()
			if moved < STUCK_DISTANCE:
				stuck[npc] += dt
				if notes[npc] == "" and stuck[npc] > 1.0:
					notes[npc] = _describe_stuck(npc)

	var worst_stuck := 0.0
	var worst_flips := 0
	for npc in npcs:
		print("  %s at %s: %.1f s walking in place, %d facing reversals %s" % [
			npc.name, _v(npc.global_position), stuck[npc], flips[npc], notes[npc]
		])
		worst_stuck = maxf(worst_stuck, stuck[npc])
		worst_flips = maxi(worst_flips, flips[npc])
	print("  %d NPCs; worst %.1f s walking in place, worst %d facing reversals" % [
		npcs.size(), worst_stuck, worst_flips
	])
	_check("found NPCs in the level", npcs.size() > 0)
	_check("no NPC walks in place for over 3 s", worst_stuck <= 3.0)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _describe_stuck(npc: Npc) -> String:
	var agent: NavigationAgent3D = npc.get_node("%NavigationAgent3D")
	var path := agent.get_current_navigation_path()
	var index := agent.get_current_navigation_path_index()
	var next := path[index] if index < path.size() else agent.target_position
	var pos := npc.global_position
	return "[stuck: agent waypoint %d/%d %s (flat %.2f m, up %.2f m), target %s, velocity %s]" % [
		index, path.size(), _v(next), Vector2(next.x - pos.x, next.z - pos.z).length(),
		next.y - pos.y, _v(agent.target_position), _v(npc.velocity)
	]


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
