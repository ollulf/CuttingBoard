class_name Interactor
extends Node

## Raycasts from the parent Camera3D: highlights whatever interactable sits under the
## crosshair, uses Usable objects, and moves Carryable objects in and out of a HandSlot.

signal hover_changed(target: Node3D)
## An object under the crosshair went into the inventory. Carries the record stored,
## so a listener can react to what was taken as well as that something was.
signal item_stowed(data: ItemData)

@export var ray_length := 3.0
@export var collision_mask := 1
## Speed of a fully charged throw, in metres per second. A release with no wind-up
## leaves the item at rest, which is what makes a quick click read as a plain drop.
@export var throw_speed := 12.0
## How far down the line of sight a throw is aimed. The hands sit off to either side of
## the camera, so a throw sent straight forward stays out there and never arrives where
## the crosshair is pointing; aiming at a point on the sight line converges it instead.
@export var aim_distance := 12.0
## How much of that convergence to apply: 0 throws straight forward from the hand, 1
## sends the item exactly through the aim point.
@export_range(0.0, 1.0) var aim_convergence := 0.8
## Overlay applied to the hovered object's meshes; a translucent tint is built if unset.
@export var highlight_material: Material

## How far in front of the camera items from the inventory land, in metres, how fast
## they are pushed away, and how far apart a dropped stack is spaced.
@export var drop_distance := 1.3
@export var drop_speed := 1.5
@export var drop_spread := 0.3

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
	# Read the record before stowing: that is what frees the world object it lives on.
	var data := carryable.item_data
	if not inventory.add(data):
		return false
	carryable.stow(get_owner())
	item_stowed.emit(data)
	return true


## True if there is something under the crosshair that a hand could take hold of.
func has_grabbable() -> bool:
	return _get_component(_hovered, "Carryable") != null


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


## Rebuilds items from an inventory record and puts them back into the world just in
## front of the camera. Returns how many actually made it out, which is what the caller
## should then take off the stack — an item with no world scene cannot be dropped.
func drop_item(data: ItemData, count: int = 1) -> int:
	if data == null:
		return 0
	var dropped := 0
	for i in count:
		var item := data.spawn()
		if item == null:
			break
		get_tree().current_scene.add_child(item)
		# Spread a stack slightly so the pieces do not spawn inside one another.
		var spread := _camera.global_transform.basis.x * (i - (count - 1) * 0.5) * drop_spread
		item.global_position = _camera.global_position - _camera.global_transform.basis.z * drop_distance + spread
		var body := item as RigidBody3D
		if body:
			body.linear_velocity = -_camera.global_transform.basis.z * drop_speed
		dropped += 1
	return dropped


## Draws the item assigned to a slot, spawning the real world object into that hand, so
## an equipped hammer is identical to one picked up off the ground. Whatever the hand
## was carrying is dropped first — a click always ends with the equipped item ready.
func draw_equipped(hand: HandSlot) -> bool:
	if hand == null or hand.equipped == null or hand.is_drawn():
		return false
	var data := hand.equipped
	if not hand.is_free():
		drop_hand(hand)
	var item := data.spawn()
	if item == null:
		return false
	get_tree().current_scene.add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(get_owner())
	if hand.hold_drawn(item):
		return true
	item.queue_free()
	return false


## Puts drawn items away: the world object is destroyed, but the slot keeps its
## assignment, so what was in hand is simply back in its equipment slot ready to be
## drawn again. Items the hands merely picked up are left alone — they are not
## equipment and have nowhere to go but the floor. Returns how many were put away.
func sheathe_equipment(hands: Array[HandSlot]) -> int:
	var sheathed := 0
	for hand in hands:
		var item := hand.sheathe()
		if item == null:
			continue
		item.queue_free()
		sheathed += 1
	return sheathed


## Moves an assignment from one slot to the other, carrying the drawn object across
## with it so a weapon already in hand simply changes hands.
func move_equipped(from: HandSlot, to: HandSlot) -> bool:
	if from == null or to == null or from == to or from.equipped == null or to.equipped != null:
		return false
	# Read the record first: releasing a drawn item is what clears the assignment.
	var data := from.equipped
	var item: Node3D = from.release() if from.is_drawn() else null
	from.unequip()
	if to.equip(data):
		if item:
			to.hold_drawn(item)
		return true
	# Refused — put it back exactly as it was rather than dropping it on the floor.
	from.equip(data)
	if item:
		from.hold_drawn(item)
	return false


## Destroys whatever a hand holds, for when its record has just been banked elsewhere.
func consume_held(hand: HandSlot) -> void:
	if hand == null or hand.is_free():
		return
	hand.release().queue_free()


## Puts whatever a hand holds back into the world at rest — a throw with no wind-up.
func drop_hand(hand: HandSlot) -> void:
	if hand == null or hand.is_free():
		return
	_throw_from(hand, 0.0)


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
		body.linear_velocity = _throw_direction(item.global_position) * throw_speed * ratio


## Which way an item leaves a hand: somewhere between straight ahead and angled in at a
## point on the line of sight, so a throw from either hand converges toward the
## crosshair instead of running parallel to it.
func _throw_direction(from: Vector3) -> Vector3:
	var forward := -_camera.global_transform.basis.z
	var to_aim := _camera.global_position + forward * aim_distance - from
	if to_aim.is_zero_approx():
		return forward
	return forward.slerp(to_aim.normalized(), aim_convergence)


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
