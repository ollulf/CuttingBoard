class_name Sight
extends Node

## An NPC's eyes. A few times a second it looks over every actor in range and reports
## the ones it can actually see: inside the field of view and not hidden behind a wall.
## It sits under the node that marks where the eyes are, and looks the way the body
## faces. What is done about a sighting is not its business — it only reports.

signal spotted(actor: Node3D)

## How far the eyes reach, in metres.
@export var view_distance := 15.0
## Width of the view cone, in degrees.
@export_range(1.0, 360.0) var field_of_view := 140.0
## Anything this close is noticed whichever way the NPC faces — heard, or bumped into.
@export var awareness_radius := 2.0
## Seconds between looks. Sight is cheap at this rate even with many NPCs.
@export var interval := 0.2
@export var collision_mask := 1
## Height above an actor's origin that the line of sight is drawn to: roughly the chest.
@export var target_height := 1.0

@onready var _eyes: Node3D = get_parent()
@onready var _body: Node3D = owner

var _timer := 0.0


func _ready() -> void:
	# Spread the looks of NPCs placed at once across frames instead of stacking them.
	_timer = randf() * interval


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += interval
	_look()


func _look() -> void:
	for node in get_tree().get_nodes_in_group(Faction.GROUP):
		var actor := node as Node3D
		if actor == null or actor == _body or not Health.is_node_alive(actor):
			continue
		if _can_see(actor):
			spotted.emit(actor)


func _can_see(actor: Node3D) -> bool:
	var target := actor.global_position + Vector3.UP * target_height
	var to_target := target - _eyes.global_position
	var distance := to_target.length()
	if distance > view_distance:
		return false
	if distance > awareness_radius and not _in_view_cone(to_target):
		return false
	return _has_line_of_sight(actor, target)


## Measured flat, against the way the body faces, so looking up at someone on a step
## does not count as looking away from them.
func _in_view_cone(to_target: Vector3) -> bool:
	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if flat.length_squared() < 0.0001:
		return true
	return rad_to_deg(forward.angle_to(flat)) <= field_of_view * 0.5


func _has_line_of_sight(actor: Node3D, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eyes.global_position, target, collision_mask)
	var own_body := _body as CollisionObject3D
	if own_body:
		query.exclude = [own_body.get_rid()]
	var hit := _eyes.get_world_3d().direct_space_state.intersect_ray(query)
	# Nothing in the way at all also counts: the ray may end just short of a thin actor.
	return hit.is_empty() or hit.get("collider") == actor
