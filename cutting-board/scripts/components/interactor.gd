class_name Interactor
extends Node

signal hover_changed(target: Node3D)
signal item_stowed(data: ItemData)
signal container_opened(inventory: Inventory)
signal trader_opened(trader: Trader)
signal stow_refused(data: ItemData)

@export var ray_length := 3.0
@export var collision_mask := 1
@export var throw_speed := 12.0
@export var aim_distance := 12.0
@export_range(0.0, 1.0) var aim_convergence := 0.8
@export var highlight_material: Material

@export var drop_distance := 1.3
@export var drop_speed := 1.5

@export_group("Sounds")
@export var grab_sound: SoundBank = preload("res://resources/audio/grab.tres")
@export var throw_sound: SoundBank = preload("res://resources/audio/throw.tres")
@export var drop_sound: SoundBank = preload("res://resources/audio/drop.tres")
@export var refused_sound: SoundBank = preload("res://resources/audio/ui_invalid.tres")
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
	if not is_instance_valid(_hovered):
		_hovered = null
	var target := _get_target()
	if not _is_interactable(target):
		target = null
	if target == _hovered:
		return
	set_overlay(_hovered, null)
	_hovered = target
	set_overlay(_hovered, highlight_material)
	hover_changed.emit(_hovered)


func get_hovered() -> Node3D:
	return _hovered if is_instance_valid(_hovered) else null


func interact(inventory: Inventory = null) -> void:
	if stow_hovered(inventory):
		return
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	if carryable and inventory:
		Sfx.play(refused_sound)
		stow_refused.emit(carryable.item_data)
	var container := get_hovered_container()
	if container:
		container_opened.emit(container)
	var usable := _get_component(get_hovered(), "Usable") as Usable
	if usable and usable.use(get_owner()):
		if usable is Trader:
			trader_opened.emit(usable)
		return
	var dialogue := Dialogue.find_dialogue_in(get_hovered())
	if dialogue:
		dialogue.use(get_owner())


func get_hovered_container() -> Inventory:
	return _container_of(get_hovered())


func _container_of(node: Node3D) -> Inventory:
	if _get_component(node, "Carryable") != null:
		return null
	var health := Health.find_in(node)
	if health and health.is_alive():
		return null
	return _get_component(node, "Inventory") as Inventory


func can_stow_hovered(inventory: Inventory) -> bool:
	if inventory == null:
		return false
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	return carryable != null and inventory.can_add(carryable.item_data)


func stow_hovered(inventory: Inventory) -> bool:
	if not can_stow_hovered(inventory):
		return false
	var carryable := _get_component(get_hovered(), "Carryable") as Carryable
	var data := carryable.item_data
	var durability := carryable.get_durability()
	if not inventory.add(data, durability):
		return false
	carryable.stow(get_owner())
	item_stowed.emit(data)
	return true


func has_grabbable() -> bool:
	return _get_component(get_hovered(), "Carryable") != null


func grab_or_charge(hand: HandSlot) -> void:
	if hand.is_free():
		_grab_into(hand)
	else:
		hand.begin_charge()


func release_hand(hand: HandSlot) -> void:
	if not hand.is_charging():
		return
	_throw_from(hand, hand.end_charge())


func drop_item(data: ItemData, durability: int = -1) -> bool:
	if data == null:
		return false
	var item := data.spawn()
	if item == null:
		return false
	get_tree().current_scene.add_child(item)
	Destructible.write(item, durability)
	item.global_position = (
		_camera.global_position - _camera.global_transform.basis.z * drop_distance
	)
	var body := item as RigidBody3D
	if body:
		body.linear_velocity = -_camera.global_transform.basis.z * drop_speed
	return true


func spawn_into_hand(data: ItemData, durability: int, hand: HandSlot) -> Node3D:
	if data == null or hand == null or not hand.is_free():
		return null
	var item := data.spawn()
	if item == null:
		return null
	get_tree().current_scene.add_child(item)
	Destructible.write(item, durability)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(get_owner())
	if hand.hold(item):
		return item
	item.queue_free()
	return null


func stow_held(
	hand: HandSlot, inventory: Inventory, origin := Vector2i(-1, -1), rotated := false
) -> InventoryEntry:
	if hand == null or inventory == null or hand.is_free():
		return null
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


func move_held(from: HandSlot, to: HandSlot) -> bool:
	if from == null or to == null or from == to or from.is_free() or not to.is_free():
		return false
	var item := from.release()
	if to.hold(item):
		return true
	from.hold(item)
	return false


func consume_held(hand: HandSlot) -> void:
	if hand == null or hand.is_free():
		return
	hand.release().queue_free()


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
	var body := item as RigidBody3D
	if body:
		HumanBody.keep_clear_of(body, get_owner())
		body.linear_velocity = _throw_direction(item.global_position) * throw_speed * ratio
	if ratio >= throw_sound_charge:
		Sfx.play(throw_sound, linear_to_db(clampf(ratio, 0.5, 1.0)))
	else:
		Sfx.play(drop_sound)


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
	var own_body := get_owner() as CollisionObject3D
	if own_body:
		query.exclude = [own_body.get_rid()]
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	if not is_instance_valid(collider):
		return null
	return HumanBody.actor_of(collider) as Node3D


func _is_interactable(node: Node3D) -> bool:
	return (
		_get_component(node, "Carryable") != null
		or _get_component(node, "Usable") != null
		or _get_component(node, "Dialogue") != null
		or _container_of(node) != null
	)


func _get_component(node: Node3D, component_name: String) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null(component_name)


static func set_overlay(node: Node3D, material: Material) -> void:
	if node == null or not is_instance_valid(node):
		return
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material
