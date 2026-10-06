extends Node

## Headless checks for the Hollowstump bandit camp in the test level: the camp loads,
## its five bandits spawn on the bandit side with their roles, a player in the bandit
## mask is left alone, and the navmesh leads from the gate into the den.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/bandit_camp_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")

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

	var camp := level.get_node_or_null("BanditCamp") as Node3D
	_check("camp is placed in the level", camp != null)
	if camp == null:
		_finish()
		return
	var bandits := camp.get_node("Bandits").get_children()
	_check("five bandits", bandits.size() == 5)
	for bandit in bandits:
		_check("%s is a bandit" % bandit.name, bandit is Npc and bandit.faction.data.id == &"bandits")
	var lookout: Npc = camp.get_node("Bandits/Lookout")
	_check("lookout sees further", lookout.get_node("Eyes/Sight").view_distance > 20.0)
	_check("lookout stands on the platform", lookout.global_position.y > camp.global_position.y + 5.5)
	_check("sleeper hears allies", camp.get_node("Bandits/Sleeper").hears_allies)
	_check("cook flees when hurt", camp.get_node("Bandits/Cook/Brain/Flee").flee_below_health > 0.0)

	# A masked player at the gate.
	var player: Node3D = level.get_node("Player")
	player.global_position = camp.global_position + Vector3(-8.0, 0.1, 0.0)
	var equipment: Equipment = player.get_node("%Equipment")
	equipment.unequip(Equipment.Slot.MASK)
	equipment.equip(Equipment.Slot.MASK, BANDIT_MASK)
	var guard: Npc = camp.get_node("Bandits/GateGuardNorth")
	guard.memory.remember(player)
	_check("masked player: guard leaves them be", guard.get_attack_target() != player)
	_check("masked player: not hostile", not guard.faction.is_hostile_to(player))

	# The den is reachable from outside the gate.
	var map := region.get_navigation_map()
	var from := NavigationServer3D.map_get_closest_point(map, camp.global_position + Vector3(-12, 0, 0))
	var to := camp.global_position + Vector3(0.8, 0, -0.6)
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	_check("navmesh path from the gate", path.size() > 1)
	if path.size() > 1:
		var end := path[path.size() - 1]
		_check("path ends inside the den (%.2f m off)" % Vector2(end.x - to.x, end.z - to.z).length(),
				Vector2(end.x - to.x, end.z - to.z).length() < 0.8)
	_finish()


func _finish() -> void:
	print("bandit_camp_check: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
