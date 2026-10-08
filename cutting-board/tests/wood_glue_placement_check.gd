extends Node3D

## Headless check that the valley holds the scattered wood glue pots and that each one
## comes to rest on the ground once physics settles: ground just below it, nothing
## overhead (not buried in a wall or roof), not still moving, and no two stacked.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/wood_glue_placement_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const GLUE_SCENE := "res://scenes/items/wood_glue.tscn"
const MIN_POTS := 8

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	add_child(LEVEL.instantiate())
	for i in 240:
		await get_tree().physics_frame
	var pots: Array[RigidBody3D] = []
	_collect(self, pots)
	_check("at least %d wood glue pots in the level (found %d)" % [MIN_POTS, pots.size()],
			pots.size() >= MIN_POTS)
	for pot in pots:
		_check_pot(pot, pots)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _collect(node: Node, out: Array[RigidBody3D]) -> void:
	if node is RigidBody3D and node.scene_file_path == GLUE_SCENE:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _check_pot(pot: RigidBody3D, pots: Array[RigidBody3D]) -> void:
	var at := pot.global_position
	var name := "%s at (%.1f, %.1f, %.1f)" % [pot.get_parent().name, at.x, at.y, at.z]
	var space := get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, at + Vector3.DOWN * 1.0)
	down.exclude = [pot.get_rid()]
	var ground := space.intersect_ray(down)
	_check("%s rests on the ground" % name,
			not ground.is_empty() and at.y - ground.position.y < 0.3)
	var up := PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 3.0)
	up.exclude = [pot.get_rid()]
	_check("%s is in the open" % name, space.intersect_ray(up).is_empty())
	_check("%s has settled" % name, pot.linear_velocity.length() < 0.2)
	var apart := true
	for other in pots:
		if other != pot and other.global_position.distance_to(at) < 1.0:
			apart = false
	_check("%s is not stacked on another pot" % name, apart)


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failures += 1
