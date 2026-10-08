extends Node

## Headless checks for the Carver's grove: he is placed in the level on the ground, well
## away from the village, the roads, the intro landing, the chair yard and the bandit camp,
## faces back towards the valley, his stump stops the player and is cut out of the navmesh,
## and his lights fade with distance.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/carver_grove_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	if region.navigation_mesh.get_polygon_count() == 0:
		await region.bake_finished
	await _physics_frames(10)

	var grove := level.get_node_or_null("CarverGrove") as Node3D
	_check("carver grove is placed in the level", grove != null)
	if grove == null:
		_finish()
		return
	_check("the Carver is in the grove", grove.get_node_or_null("%Carver") != null)

	var terrain: Terrain = level.get_node("Terrain")
	var at := grove.global_position
	var ground := terrain.height_at(at.x, at.z)
	_check("grove sits on the ground (%.2f m vs ground %.2f m)" % [at.y, ground],
			absf(at.y - (ground - terrain.snap_sink)) < 0.05)
	var stump: CollisionShape3D = grove.get_node("%Stump")
	var foot := stump.global_position.y - 1.0
	_check("stump foot is at ground level (%.2f m off)" % (foot - ground), absf(foot - ground) < 0.4)

	var village: Node3D = level.get_node("Village")
	var nearest_house := INF
	for building in village.get_node("Buildings").get_children():
		nearest_house = minf(nearest_house, _flat(at).distance_to(_flat(building.global_position)))
	_check("away from the village (%.0f m)" % nearest_house, nearest_house > 50.0)
	var road := _road_distance(terrain, at)
	_check("away from the roads (%.0f m)" % road, road > 40.0)
	var landing: Vector3 = level.get_node("IntroSequence").landing_spot
	_check("away from the intro landing", _flat(at).distance_to(_flat(landing)) > 60.0)
	var yard: Node3D = level.get_node("ChairYard")
	_check("away from the chair yard (%.0f m)" % _flat(at).distance_to(_flat(yard.global_position)),
			_flat(at).distance_to(_flat(yard.global_position)) > 60.0)
	var camp: Node3D = level.get_node("BanditCamp")
	_check("far from the bandit camp", _flat(at).distance_to(_flat(camp.global_position)) > 100.0)
	var forward := -grove.global_basis.z
	var to_valley := (Vector3.ZERO - at).normalized()
	_check("he faces back towards the valley", forward.dot(to_valley) > 0.7)

	# Walk the player at the stump from in front: the stump stops him.
	var player: CharacterBody3D = level.get_node("Player")
	var centre := stump.global_position
	var start := centre + forward * 4.0
	start.y = terrain.height_at(start.x, start.z) + 1.0
	player.global_position = start
	await _physics_frames(2)
	var motion := (centre - start) * Vector3(1, 0, 1)
	var hit := player.move_and_collide(motion, true)
	_check("the stump blocks the player", hit != null)

	var map := region.get_navigation_map()
	# An NPC walking from in front of the stump to behind it goes round, never through.
	var behind := centre - forward * 4.0
	var path := NavigationServer3D.map_get_path(map, start, behind, true)
	var closest := INF
	for point in path:
		closest = minf(closest, _flat(point).distance_to(_flat(centre)))
	_check("NPCs path round the stump (closest %.2f m)" % closest, path.size() > 1 and closest > 1.4)

	var lights := grove.find_children("*", "OmniLight3D", true, false)
	var fading := lights.filter(func(l: OmniLight3D) -> bool: return l.distance_fade_enabled and not l.shadow_enabled)
	_check("all %d lights fade with distance, no shadows" % lights.size(),
			lights.size() > 0 and fading.size() == lights.size())

	# He talks: a Dialogue voiced by his own blip bank, reached by looking at him.
	var dialogue := grove.get_node_or_null("%Dialogue") as Dialogue
	_check("the Carver has a Dialogue", dialogue != null)
	if dialogue == null:
		_finish()
		return
	var bank := dialogue.voice
	_check("his voice is carver_voice.tres", bank != null
			and bank.resource_path == "res://resources/audio/carver_voice.tres")
	var loaded := bank.streams.filter(func(s: AudioStream) -> bool: return s != null and s.get_length() > 0.1)
	_check("all %d voice blips load" % bank.streams.size(), bank.streams.size() == 8 and loaded.size() == 8)
	var near := centre + forward * 2.6
	near.y = terrain.height_at(near.x, near.z) + 1.0
	player.global_position = near
	player.rotation.y = atan2(forward.x, forward.z)
	await _physics_frames(5)
	var interactor := player.get_node("%Interactor") as Interactor
	_check("looking at him from the stump's edge hovers his talk body",
			interactor.get_hovered() == grove.get_node("%TalkBody"))
	_check("offers \"Talk\"", dialogue.get_prompt(player) == "Talk")
	var shown: Array[String] = []
	dialogue.line_shown.connect(func(text: String) -> void: shown.append(text))
	interactor.interact(player.get_node("%Inventory"))
	await _physics_frames(2)
	_check("E starts the talk with his first line", dialogue.is_talking()
			and shown.size() == 1 and shown[0] == dialogue.first_lines[0])
	_check("the plank names him", dialogue._speaker() == "The Carver")
	for i in dialogue.first_lines.size():
		dialogue.advance()
	_check("all %d first lines are said, then the talk ends" % dialogue.first_lines.size(),
			not dialogue.is_talking() and shown.size() == dialogue.first_lines.size() and dialogue.talked)
	_finish()


## Distance in metres from a point to the nearest road; the last path is the Carver's own
## footpath and does not count.
func _road_distance(terrain: Terrain, at: Vector3) -> float:
	var point := Vector2(at.x, at.z)
	var nearest := INF
	for path in terrain.paths.slice(0, terrain.paths.size() - 1):
		for i in path.size() - 1:
			var on_segment := Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])
			nearest = minf(nearest, point.distance_to(on_segment))
	return nearest


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _finish() -> void:
	print("carver_grove_check: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
