class_name Interactor
extends Node

## Raycasts from the parent Camera3D: highlights whatever interactable sits under the
## crosshair, uses Usable objects, and moves Carryable objects in and out of a HandSlot.

signal hover_changed(target: Node3D)
## An object under the crosshair went into the inventory. Carries the record stored,
## so a listener can react to what was taken as well as that something was.
signal item_stowed(data: ItemData)
## A container under the crosshair was opened. The interactor owns no UI, so it reports
## which inventory was opened and leaves putting a screen on it to whoever owns the HUD.
signal container_opened(inventory: Inventory)

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

## How far in front of the camera items from the inventory land, in metres, and how fast
## they are pushed away.
@export var drop_distance := 1.3
@export var drop_speed := 1.5

@export_group("Sounds")
## A hand taking hold of something off the ground.
@export var grab_sound: SoundBank = preload("res://resources/audio/grab.tres")
## A held item leaving the hand: thrown when it was wound up past throw_sound_charge,
## let go otherwise.
@export var throw_sound: SoundBank = preload("res://resources/audio/throw.tres")
@export var drop_sound: SoundBank = preload("res://resources/audio/drop.tres")
@export_range(0.0, 1.0) var throw_sound_charge := 0.2
@export_group("")

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


## What is under the crosshair, or null. Read through here rather than off _hovered: what
## was hovered can be freed between two physics steps — taken into the inventory, then
## something else changes the inventory before the next step — and a freed node cannot
## even be passed on to a typed parameter.
func get_hovered() -> Node3D:
	return _hovered if is_instance_valid(_hovered) else null


## The "interact" action: a loose item goes into the inventory, since that is what a
## player pointing at a barrel means. Anything that is not stowable — a lever, a door,
## a full inventory's worth of item — falls through to the object's Usable behaviour.
func interact(inventory: Inventory = null) -> void:
	if stow_hovered(inventory):
		return
	# A container is opened as well as used rather than instead of it, so a chest can
	# still swing its lid or play a sound through its own Usable.
	var container := get_hovered_container()
	if container:
		container_opened.emit(container)
	var usable := _get_component(get_hovered(), "Usable") as Usable
	if usable:
		usable.use(get_owner())


## The inventory of the container under the crosshair, or null if what is there is not
## one.
func get_hovered_container() -> Inventory:
	return _container_of(get_hovered())


## A carryable object's own inventory does not count: pointing at a sack means picking
## it up, and its contents come with it. Nor does a living one's — an NPC's pockets are
## its own until it is dead, and only then is the body something to search.
func _container_of(node: Node3D) -> Inventory:
	if _get_component(node, "Carryable") != null:
		return null
	var health := Health.find_in(node)
	if health and health.is_alive():
		return null
	return _get_component(node, "Inventory") as Inventory


## True if the hovered object is carryable and there is room for it in `inventory`.
func can_stow_hovered(inventory: Inventory) -> bool:
	if inventory == null:
		return false
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	return carryable != null and inventory.can_add(carryable.item_data)


func stow_hovered(inventory: Inventory) -> bool:
	if not can_stow_hovered(inventory):
		return false
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	# Read the record and the wear before stowing: that is what frees the world object
	# both live on, and the wear is the half that would otherwise be lost.
	var data := carryable.item_data
	var durability := carryable.get_durability()
	if not inventory.add(data, durability):
		return false
	carryable.stow(get_owner())
	item_stowed.emit(data)
	return true


## True if there is something under the crosshair that a hand could take hold of.
func has_grabbable() -> bool:
	return _get_component(get_hovered(), "Carryable") != null


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


## Rebuilds an item from an inventory record and puts it back into the world just in
## front of the camera. Returns false when it could not be — an item with no world scene
## cannot be dropped — which is the caller's cue to leave the record where it is rather
## than remove it.
func drop_item(data: ItemData, durability: int = -1) -> bool:
	if data == null:
		return false
	var item := data.spawn()
	if item == null:
		return false
	get_tree().current_scene.add_child(item)
	# The rebuilt object starts at the scene's authored durability, so the wear the
	# record was carrying has to be put back onto it.
	Destructible.write(item, durability)
	item.global_position = (
		_camera.global_position - _camera.global_transform.basis.z * drop_distance
	)
	var body := item as RigidBody3D
	if body:
		body.linear_velocity = -_camera.global_transform.basis.z * drop_speed
	return true


## Builds an inventory record into a real object and puts it straight into a hand, so an
## item taken out of the bag is identical to one picked up off the ground. Returns the
## object, or null if it could not be made — an item with no world scene has nothing to
## become — which is the caller's cue to leave the record where it was.
func spawn_into_hand(data: ItemData, durability: int, hand: HandSlot) -> Node3D:
	if data == null or hand == null or not hand.is_free():
		return null
	var item := data.spawn()
	if item == null:
		return null
	get_tree().current_scene.add_child(item)
	# Rebuilt at the wear the record was carrying, not fresh off its scene.
	Destructible.write(item, durability)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(get_owner())
	if hand.hold(item):
		return item
	item.queue_free()
	return null


## The reverse: banks what a hand is holding into an inventory and destroys the object.
## `origin` is only a preference — the square the item came out of, or where it was
## dropped — and anywhere it fits will do. Returns the entry it became, or null when
## there was no room, in which case the item is still in the hand and nothing was lost.
func stow_held(
	hand: HandSlot, inventory: Inventory, origin := Vector2i(-1, -1), rotated := false
) -> InventoryEntry:
	if hand == null or inventory == null or hand.is_free():
		return null
	# Read before storing: both the record and the wear live on the object that is about
	# to be destroyed.
	var data := hand.get_item_data()
	if data == null:
		return null
	var durability := hand.get_durability()
	var entry: InventoryEntry = null
	if origin.x >= 0:
		entry = inventory.store_at(data, origin, durability, rotated)
	if entry == null:
		entry = inventory.store(data, durability)
	if entry == null:
		return null
	consume_held(hand)
	return entry


## Hands a held object across to the other hand. A refused move puts it straight back,
## so a full hand never costs the item.
func move_held(from: HandSlot, to: HandSlot) -> bool:
	if from == null or to == null or from == to or from.is_free() or not to.is_free():
		return false
	var item := from.release()
	if to.hold(item):
		return true
	from.hold(item)
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
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	if carryable == null:
		return
	if hand.hold(carryable.take(get_owner())):
		Sfx.play(grab_sound)


func _throw_from(hand: HandSlot, ratio: float) -> void:
	var item := hand.release()
	item.reparent(get_tree().current_scene, true)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.return_to_world()
	# After return_to_world, so the body is unfrozen and will accept the velocity.
	var body := item as RigidBody3D
	if body:
		HumanBody.keep_clear_of(body, get_owner())
		body.linear_velocity = _throw_direction(item.global_position) * throw_speed * ratio
	if ratio >= throw_sound_charge:
		Sfx.play(throw_sound, linear_to_db(clampf(ratio, 0.5, 1.0)))
	else:
		Sfx.play(drop_sound)


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
	# The ray starts inside the owner's own capsule. Excluding that body keeps the
	# player from ever reading as a target of their own — they carry components the
	# interactor looks for, their Inventory among them.
	var own_body := get_owner() as CollisionObject3D
	if own_body:
		query.exclude = [own_body.get_rid()]
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	# Physics still reports a body that was freed earlier in the same frame — a barrel
	# shattering on impact — and a freed node cannot even be passed to a typed
	# parameter later on, so it is dropped at the source.
	if not is_instance_valid(collider):
		return null
	# A fallen body is found by its limbs, but it is the character that gets searched.
	return HumanBody.actor_of(collider) as Node3D


func _is_interactable(node: Node3D) -> bool:
	return (
		_get_component(node, "Carryable") != null
		or _get_component(node, "Usable") != null
		or _container_of(node) != null
	)


func _get_component(node: Node3D, component_name: String) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null(component_name)


func _set_overlay(node: Node3D, material: Material) -> void:
	if node == null or not is_instance_valid(node):
		return
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material
