extends Node3D

## Headless checks for the walking chair creature (scenes/characters/chair_creature.tscn):
## it walks along the navigation mesh one limb at a time (two at most when it scuttles),
## its hands stay put while they carry weight, it scuttles at a run on the chairs' side,
## and killed it collapses and drops its mask. Prints PASS/FAIL per check
## and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/walking_chair_check.tscn

const CREATURE := preload("res://scenes/characters/chair_creature.tscn")
## How far a planted hand may drift between two frames, metres.
const SLIDE_TOLERANCE := 0.01

var _failures := 0

## Emitted every frame after every other node's _process.
signal _posed


func _ready() -> void:
	process_priority = 1000
	_run.call_deferred()


func _process(_delta: float) -> void:
	_posed.emit()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	TestWorld.add_slab(self, Vector3(3, 2, 1), Vector3(0, 1, 3.5))
	await TestWorld.bake(TestWorld.add_nav_region(self))

	var creature: CharacterBody3D = CREATURE.instantiate()
	add_child(creature)
	creature.global_position = Vector3(0, 0.05, 0)
	# Its own roaming off: the check steers it.
	creature.set_process(false)
	await _physics_frames(10)
	var chair: Node3D = creature.get_node("%Chair")
	var health: Health = creature.get_node("%Health")
	var locomotion: Locomotion = creature.get_node("%Locomotion")

	# Around the slab to the far side: the straight line runs into it.
	var goal := Vector3(0, 0, 7)
	locomotion.move_to(goal)
	var walk: Dictionary = await _watch_gait(chair, locomotion)
	var flat := Vector3(creature.global_position.x, 0, creature.global_position.z)
	_check("walks around the slab to the goal (%.2f m off)" % flat.distance_to(goal),
		flat.distance_to(goal) < 1.0)
	_check("lifts its hands to step (%d swings)" % walk.swings, walk.swings >= 12)
	_check("planted hands do not slide (worst %.4f m over %d frames)" % [walk.worst, walk.planted],
		walk.planted > 100 and walk.worst < SLIDE_TOLERANCE)
	_check("walking, each limb steps on its own: one hand up at a time (%d frames with two)"
		% walk.two_up, walk.most_up == 1)

	var info := DamageInfo.new(10)
	info.position = creature.global_position + Vector3(0, 0.6, -1)
	health.apply_damage(info)
	_check("an enemy of the player's side",
		creature.get_node("%Faction").data == preload("res://resources/factions/chairs.tres")
		and preload("res://resources/items/chair_mask.tres").faction.is_hostile_to(
			preload("res://resources/factions/player.tres")))
	# Chasing, it scuttles: the gait at a run, on along the way it was going.
	locomotion.move_to(creature.global_position + Vector3(0, 0, 3), true)
	await _physics_frames(5)
	_check("scuttles off", locomotion.is_moving())
	var run: Dictionary = await _watch_gait(chair, locomotion)
	_check("scuttling, at most two hands are off the ground (most %d)" % run.most_up,
		run.most_up <= 2 and run.swings >= 4)
	_check("scuttling, planted hands do not slide (worst %.4f m)" % run.worst,
		run.worst < SLIDE_TOLERANCE)

	var killing := DamageInfo.new(1000)
	killing.position = creature.global_position
	health.apply_damage(killing)
	await _physics_frames(60)
	_check("dies", not health.is_alive())
	_check("collapses", chair.is_collapsed())
	var dropped := false
	for child in get_children():
		if child is RigidBody3D and child.scene_file_path == "res://scenes/items/chair_mask.tscn":
			dropped = true
	_check("drops its mask", dropped)
	_finish()


## Watches the chair's hands while it moves: the worst frame-to-frame drift of a planted
## hand, how many frames that covers, how many steps it takes, and how many hands are up
## at once.
func _watch_gait(chair: Node3D, locomotion: Locomotion) -> Dictionary:
	var stats := {"worst": 0.0, "planted": 0, "swings": 0, "most_up": 0, "two_up": 0}
	var last := {}
	var waited := 0.0
	while locomotion.is_moving() and waited < 25.0:
		# Sampled once the chair has posed itself this frame (process_frame comes before
		# the nodes' own _process).
		await _posed
		waited += get_process_delta_time()
		var up := 0
		for corner in ["FL", "FR", "BL", "BR"]:
			var wrist := chair.get_node("%Wrist" + corner) as Node3D
			if chair.planted_hand(corner) == null:
				up += 1
				if last.has(corner):
					stats.swings += 1
				last.erase(corner)
				continue
			if last.has(corner):
				var drift := (last[corner] as Vector3).distance_to(wrist.global_position)
				stats.worst = maxf(stats.worst, drift)
				stats.planted += 1
			last[corner] = wrist.global_position
		stats.most_up = maxi(stats.most_up, up)
		if up >= 2:
			stats.two_up += 1
	return stats


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
