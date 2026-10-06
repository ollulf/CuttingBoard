extends Node3D

## Headless checks that taking an item into a full inventory is refused with feedback:
## the inventory is packed with rocks, the player looks at a rock on the ground and
## presses E, and the rock has to stay in the world while the interactor reports the
## refusal and the HUD shows "Inventory full". Prints PASS/FAIL per check and quits with
## the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/inventory_full_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const ROCK := preload("res://resources/items/rock.tres")

var _failures := 0
var _refusals := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var player = PLAYER.instantiate()
	add_child(player)
	await _physics_frames(5)
	var inventory: Inventory = player.inventory
	while inventory.add(ROCK):
		pass
	_check("the inventory has no room for another rock", not inventory.can_add(ROCK))

	var item := ROCK.spawn()
	add_child(item)
	item.global_position = Vector3(0, 0.2, -1.5)
	await _physics_frames(30)
	(player.camera_pivot as Node3D).look_at(item.global_position)
	await _physics_frames(3)
	var interactor: Interactor = player.interactor
	_check("the rock is under the crosshair", interactor.get_hovered() == item)
	var count := inventory.get_entries().size()
	interactor.stow_refused.connect(func(_d: ItemData) -> void: _refusals += 1)
	var label := player.find_child("RefusedLabel", true, false) as Label
	_check("the message is hidden before trying", label != null and label.modulate.a == 0.0)

	interactor.interact(inventory)
	await _frames(2)
	_check("the rock stays in the world", is_instance_valid(item))
	_check("the inventory is unchanged", inventory.get_entries().size() == count)
	_check("the refusal is reported once", _refusals == 1)
	_check("the HUD shows the message", label != null and label.modulate.a > 0.9)

	# A second press restarts the message rather than stacking another.
	interactor.interact(inventory)
	await _frames(2)
	_check("a second press reports again", _refusals == 2)
	_check("the message is still up", label != null and label.modulate.a > 0.9)
	await get_tree().create_timer(2.0).timeout
	_check("the message fades out", label != null and label.modulate.a < 0.05)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


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
