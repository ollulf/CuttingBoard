class_name Carryable
extends Node

## Lets an object be taken out of the world and held in a HandSlot, and describes what
## the object becomes once it reaches an inventory (item_data).

@export var item_data: ItemData

signal picked_up(by: Node)

var _world_layer := 0
var _world_mask := 0


## Detaches the item from world physics and returns the root node to be held.
func take(by: Node) -> Node3D:
	var root := get_parent() as Node3D
	var body := root as CollisionObject3D
	if body:
		_world_layer = body.collision_layer
		_world_mask = body.collision_mask
		body.collision_layer = 0
		body.collision_mask = 0
	# Freezing is what keeps a held RigidBody3D following the hand instead of
	# simulating its way out of it.
	var rigid := root as RigidBody3D
	if rigid:
		rigid.freeze = true
	picked_up.emit(by)
	return root


## Restores world physics after the item leaves a HandSlot.
func return_to_world() -> void:
	var root := get_parent()
	var body := root as CollisionObject3D
	if body:
		body.collision_layer = _world_layer
		body.collision_mask = _world_mask
	var rigid := root as RigidBody3D
	if rigid:
		rigid.freeze = false
