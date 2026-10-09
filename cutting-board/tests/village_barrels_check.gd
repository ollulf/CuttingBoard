extends Node3D

## Headless check that every barrel in the village (and on its market stalls) is a
## carryable item barrel and settles on the ground instead of popping or falling through.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/village_barrels_check.tscn

const VILLAGE := preload("res://scenes/levels/village.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_floor()
	var village := VILLAGE.instantiate()
	add_child(village)
	var barrels: Array[RigidBody3D] = []
	for node in village.find_children("*", "RigidBody3D", true, false):
		var item := node.get_node_or_null("Carryable") as Carryable
		if item and item.item_data and item.item_data.resource_path.ends_with("barrel.tres"):
			barrels.append(node)
	var start := {}
	for barrel in barrels:
		start[barrel] = barrel.global_position
	_check(barrels.size() >= 7, "village has %d carryable barrels (>= 7)" % barrels.size())
	for _i in 180:
		await get_tree().physics_frame
	for barrel in barrels:
		var moved: Vector3 = barrel.global_position - start[barrel]
		_check(moved.length() < 0.15 and barrel.global_position.y > 0.3,
				"%s settles (moved %.3f, y %.2f)" % [barrel.name, moved.length(), barrel.global_position.y])
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failures += 1
