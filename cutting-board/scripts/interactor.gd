class_name Interactor
extends Node

## Raycasts from the parent Camera3D: highlights whatever interactable sits under the
## crosshair, uses Usable objects, and moves Carryable objects in and out of a HandSlot.

@export var ray_length := 3.0
@export var collision_mask := 1
## Overlay applied to the hovered object's meshes; a translucent tint is built if unset.
@export var highlight_material: Material

@onready var _camera: Camera3D = get_parent()

var _hovered: Node3D = null


func _ready() -> void:
	if highlight_material == null:
		var tint := StandardMaterial3D.new()
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.albedo_color = Color(1.0, 0.9, 0.4, 0.25)
		highlight_material = tint


func _physics_process(_delta: float) -> void:
	var target := _get_target()
	if not _is_interactable(target):
		target = null
	if target == _hovered:
		return
	_set_overlay(_hovered, null)
	_hovered = target
	_set_overlay(_hovered, highlight_material)


func interact() -> void:
	var usable := _get_component(_hovered, "Usable") as Usable
	if usable:
		usable.use(get_owner())


func grab_or_drop(hand: HandSlot) -> void:
	if hand.is_free():
		_grab_into(hand)
	else:
		_drop_from(hand)


func _grab_into(hand: HandSlot) -> void:
	var carryable := _get_component(_hovered, "Carryable") as Carryable
	if carryable == null:
		return
	hand.hold(carryable.take(get_owner()))


func _drop_from(hand: HandSlot) -> void:
	var item := hand.release()
	item.reparent(get_tree().current_scene, true)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.return_to_world()


func _get_target() -> Node3D:
	var space_state := _camera.get_world_3d().direct_space_state
	var origin := _camera.global_position
	var end := origin - _camera.global_transform.basis.z * ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
	var result := space_state.intersect_ray(query)
	return result.get("collider") as Node3D


func _is_interactable(node: Node3D) -> bool:
	return _get_component(node, "Carryable") != null or _get_component(node, "Usable") != null


func _get_component(node: Node3D, component_name: String) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null(component_name)


func _set_overlay(node: Node3D, material: Material) -> void:
	if node == null or not is_instance_valid(node):
		return
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material
