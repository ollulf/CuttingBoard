class_name Sight
extends Node

signal spotted(actor: Node3D)

@export var view_distance := 15.0
@export_range(1.0, 360.0) var field_of_view := 140.0
@export var awareness_radius := 2.0
@export var interval := 0.2
@export var collision_mask := 1
@export var target_height := 1.0

@onready var _eyes: Node3D = get_parent()
@onready var _body: Node3D = owner

var _timer := 0.0
var _own_rids: Array[RID] = []


func _ready() -> void:
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


func _in_view_cone(to_target: Vector3) -> bool:
	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if flat.length_squared() < 0.0001:
		return true
	return rad_to_deg(forward.angle_to(flat)) <= field_of_view * 0.5


func _has_line_of_sight(actor: Node3D, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eyes.global_position, target, collision_mask)
	if _own_rids.is_empty():
		for collider in HumanBody.colliders_of(_body):
			_own_rids.append(collider.get_rid())
	query.exclude = _own_rids
	var hit := _eyes.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or HumanBody.actor_of(hit.get("collider")) == actor
