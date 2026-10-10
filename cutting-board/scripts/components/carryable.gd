class_name Carryable
extends Node

@export var item_data: ItemData
@export_range(0, 999) var impact_damage := 0

signal picked_up(by: Node)
signal released

var _world_layer := 0
var _world_mask := 0


func take(by: Node) -> Node3D:
	var root := get_parent() as Node3D
	var body := root as CollisionObject3D
	if body:
		_world_layer = body.collision_layer
		_world_mask = body.collision_mask
		body.collision_layer = 0
		body.collision_mask = 0
	var rigid := root as RigidBody3D
	if rigid:
		rigid.freeze = true
	picked_up.emit(by)
	return root


func return_to_world() -> void:
	var root := get_parent()
	var body := root as CollisionObject3D
	if body:
		body.collision_layer = _world_layer
		body.collision_mask = _world_mask
	var rigid := root as RigidBody3D
	if rigid:
		rigid.freeze = false
	released.emit()


func get_durability() -> int:
	return Destructible.read(get_parent())


func stow(by: Node) -> void:
	picked_up.emit(by)
	get_parent().queue_free()
