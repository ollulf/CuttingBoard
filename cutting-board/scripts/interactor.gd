class_name Interactor
extends Node

## Raycasts from the parent Camera3D: highlights whatever interactable sits under the
## crosshair, uses Usable objects, and moves Carryable objects in and out of a HandSlot.

signal hover_changed(target: Node3D)

@export var ray_length := 3.0
@export var collision_mask := 1
## Speed of a fully charged throw, in metres per second. A release with no wind-up
## leaves the item at rest, which is what makes a quick click read as a plain drop.
@export var throw_speed := 12.0
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
	# The hovered object can be destroyed while it is being looked at — a barrel
	# shattering on impact. A freed node cannot even be passed to a typed parameter,
	# so it has to be dropped here rather than guarded against further down. The test
	# is is_instance_valid alone: a freed reference compares equal to null, so a
	# null check would skip exactly the case this guards.
	if not is_instance_valid(_hovered):
		_hovered = null
	var target := _get_target()
	if not _is_interactable(target):
		target = null
	if target == _hovered:
		return
	_set_overlay(_hovered, null)
	_hovered = target
	_set_overlay(_hovered, highlight_material)
	hover_changed.emit(_hovered)


func get_hovered() -> Node3D:
	return _hovered


## The "interact" action: a loose item goes into the inventory, since that is what a
## player pointing at a barrel means. Anything that is not stowable — a lever, a door,
## a full inventory's worth of item — falls through to the object's Usable behaviour.
func interact(inventory: Inventory = null) -> void:
	if stow_hovered(inventory):
		return
	var usable := _get_component(_hovered, "Usable") as Usable
	if usable:
		usable.use(get_owner())


## True if the hovered object is carryable and there is room for it in `inventory`.
func can_stow_hovered(inventory: Inventory) -> bool:
	if inventory == null:
		return false
	var carryable := _get_component(_hovered, "Carryable") as Carryable
	return carryable != null and inventory.can_add(carryable.item_data)


func stow_hovered(inventory: Inventory) -> bool:
	if not can_stow_hovered(inventory):
		return false
	var carryable := _get_component(_hovered, "Carryable") as Carryable
	if not inventory.add(carryable.item_data):
		return false
	carryable.stow(get_owner())
	return true


## Pressing with an empty hand grabs; pressing with a full one starts winding up a throw.
func grab_or_charge(hand: HandSlot) -> void:
	if hand.is_free():
		_grab_into(hand)
	else:
		hand.begin_charge()


## Releasing only matters if this hand was winding up, so the press that performed a
## grab does not immediately throw the item it just picked up.
func release_hand(hand: HandSlot) -> void:
	if not hand.is_charging():
		return
	_throw_from(hand, hand.end_charge())


func _grab_into(hand: HandSlot) -> void:
	var carryable := _get_component(_hovered, "Carryable") as Carryable
	if carryable == null:
		return
	hand.hold(carryable.take(get_owner()))


func _throw_from(hand: HandSlot, ratio: float) -> void:
	var item := hand.release()
	item.reparent(get_tree().current_scene, true)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.return_to_world()
	# After return_to_world, so the body is unfrozen and will accept the velocity.
	var body := item as RigidBody3D
	if body:
		body.linear_velocity = -_camera.global_transform.basis.z * throw_speed * ratio


func _get_target() -> Node3D:
	var space_state := _camera.get_world_3d().direct_space_state
	var origin := _camera.global_position
	var end := origin - _camera.global_transform.basis.z * ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	# Physics still reports a body that was freed earlier in the same frame — a barrel
	# shattering on impact — and a freed node cannot even be passed to a typed
	# parameter later on, so it is dropped at the source.
	return collider if is_instance_valid(collider) else null


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
