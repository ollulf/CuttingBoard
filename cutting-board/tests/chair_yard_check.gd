extends Node

## Headless checks for the chair yard, the abandoned spot west of the village where the
## walking chairs live: each chair stands on the navmesh and can walk its roam circle, and
## none of them can see the roads, the village, the intro landing or the Mask-Monger from
## anywhere it roams on its own. The bandits leave them be, and the camp is far off.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/chair_yard_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
## Spare metres on top of roam radius plus sight distance.
const MARGIN := 3.0

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
	var map := region.get_navigation_map()

	var yard := level.get_node_or_null("ChairYard") as Node3D
	_check("chair yard is placed in the level", yard != null)
	if yard == null:
		_finish()
		return
	var chairs: Array[Node3D] = []
	for child in yard.get_children():
		if child is CharacterBody3D and "roam_radius" in child:
			chairs.append(child)
	_check("three chairs in the yard (%d)" % chairs.size(), chairs.size() == 3)

	var terrain: Terrain = level.get_node("Terrain")
	var landing: Vector3 = level.get_node("IntroSequence").landing_spot
	var monger: Node3D = level.get_node("Village/Market/MaskMonger")
	var village: Node3D = level.get_node("Village")
	var camp: Node3D = level.get_node("BanditCamp")
	var bandit_faction: Faction = camp.get_node("Bandits/GateGuardNorth/%Faction")
	for chair in chairs:
		var at := chair.global_position
		var sight: float = chair.get_node("%Sight").view_distance
		var reach: float = chair.roam_radius + sight + MARGIN
		var on_mesh := NavigationServer3D.map_get_closest_point(map, at)
		_check("%s stands on the navmesh (%.2f m off)" % [chair.name, on_mesh.distance_to(at)],
				on_mesh.distance_to(at) < 1.0)
		var spot := on_mesh + Vector3(chair.roam_radius, 0.0, 0.0)
		var path := NavigationServer3D.map_get_path(map, on_mesh, spot, true)
		_check("%s can walk its roam circle" % chair.name, path.size() > 1
				and _flat(path[path.size() - 1]).distance_to(_flat(spot)) < 0.8)
		_check("%s is out of sight of the landing" % chair.name, _flat(at).distance_to(_flat(landing)) > reach)
		_check("%s is out of sight of the Mask-Monger" % chair.name,
				_flat(at).distance_to(_flat(monger.global_position)) > reach)
		var nearest_house := INF
		for building in village.get_node("Buildings").get_children():
			nearest_house = minf(nearest_house, _flat(at).distance_to(_flat(building.global_position)))
		_check("%s is out of sight of the village (%.0f m)" % [chair.name, nearest_house], nearest_house > reach)
		var road := _road_distance(terrain, at)
		_check("%s is out of sight of the roads (%.0f m)" % [chair.name, road], road > reach)
		_check("%s is far from the bandit camp" % chair.name,
				_flat(at).distance_to(_flat(camp.global_position)) > 2.0 * reach)
		var faction: Faction = chair.get_node("%Faction")
		_check("%s and the bandits leave each other be" % chair.name,
				not faction.is_hostile_to(camp.get_node("Bandits/GateGuardNorth"))
				and not bandit_faction.is_hostile_to(chair))
	_finish()


## Distance in metres from a point to the nearest painted path on the terrain.
func _road_distance(terrain: Terrain, at: Vector3) -> float:
	var point := Vector2(at.x, at.z)
	var nearest := INF
	for path in terrain.paths:
		for i in path.size() - 1:
			var on_segment := Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])
			nearest = minf(nearest, point.distance_to(on_segment))
	return nearest


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _finish() -> void:
	print("chair_yard_check: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
