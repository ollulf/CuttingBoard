extends Node3D

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await _wait(1.5)
	var player := level.find_child("Player", false, false)
	var inventory: Inventory = player.inventory
	while inventory.add(ROCK):
		pass
	var item := ROCK.spawn()
	level.add_child(item)
	var ahead := -(player as Node3D).global_basis.z
	item.global_position = (player as Node3D).global_position + ahead * 1.5 + Vector3.UP * 0.5
	await _wait(0.8)
	(player.camera_pivot as Node3D).look_at(item.global_position)
	await _wait(0.8)
	var interactor: Interactor = player.interactor
	print("hovered rock: ", interactor.get_hovered() == item)
	interactor.interact(inventory)
	await _wait(1.25)
	interactor.interact(inventory)
	await _wait(2.2)
	print("rock still on the ground: ", is_instance_valid(item))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
