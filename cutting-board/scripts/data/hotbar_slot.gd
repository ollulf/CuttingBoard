class_name HotbarSlot
extends RefCounted

var hand_index: int
var entry: InventoryEntry
var held: Node3D
var data: ItemData
var origin := Vector2i(-1, -1)
var rotated := false


func _init(p_hand_index: int) -> void:
	hand_index = p_hand_index


func is_empty() -> bool:
	return entry == null and not is_held()


func is_held() -> bool:
	return held != null and is_instance_valid(held)


func assign(p_entry: InventoryEntry) -> void:
	entry = p_entry
	data = p_entry.data
	origin = p_entry.origin
	rotated = p_entry.rotated
	held = null


func take_into_hand(item: Node3D, from_entry: InventoryEntry) -> void:
	if from_entry:
		data = from_entry.data
		origin = from_entry.origin
		rotated = from_entry.rotated
	held = item
	entry = null


func link_held(item: Node3D, p_data: ItemData) -> void:
	clear()
	held = item
	data = p_data


func return_to_grid(p_entry: InventoryEntry) -> void:
	held = null
	entry = p_entry
	if p_entry:
		data = p_entry.data
		origin = p_entry.origin
		rotated = p_entry.rotated


func get_durability() -> int:
	if is_held():
		return Destructible.read(held)
	return entry.durability if entry else -1


func clear() -> void:
	entry = null
	held = null
	data = null
	origin = Vector2i(-1, -1)
	rotated = false
