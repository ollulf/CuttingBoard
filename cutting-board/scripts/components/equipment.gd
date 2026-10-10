class_name Equipment
extends Node

signal changed

enum Slot { MASK, HEAD, BODY, PACK }
const NO_SLOT := -1

const SLOT_TYPES := {
	Slot.MASK: ItemData.Type.MASK,
	Slot.HEAD: ItemData.Type.HEAD,
	Slot.BODY: ItemData.Type.BODY,
	Slot.PACK: ItemData.Type.PACK,
}

@export var starting_items: Array[ItemData] = []

var _items: Dictionary = {}
var _durability: Dictionary = {}


func _ready() -> void:
	for data in starting_items:
		equip(slot_for(data), data)


static func slot_for(data: ItemData) -> int:
	if data == null:
		return NO_SLOT
	for slot in SLOT_TYPES:
		if SLOT_TYPES[slot] == data.item_type:
			return slot
	return NO_SLOT


func get_item(slot: int) -> ItemData:
	return _items.get(slot)


func get_durability(slot: int) -> int:
	return _durability.get(slot, -1)


func set_durability(slot: int, durability: int) -> void:
	if is_free(slot) or get_durability(slot) == durability:
		return
	_durability[slot] = durability
	changed.emit()


func is_free(slot: int) -> bool:
	return not _items.has(slot)


func accepts(slot: int, data: ItemData) -> bool:
	return data != null and SLOT_TYPES.has(slot) and SLOT_TYPES[slot] == data.item_type


func equip(slot: int, data: ItemData, durability: int = -1) -> bool:
	if not is_free(slot) or not accepts(slot, data):
		return false
	_items[slot] = data
	_durability[slot] = durability if durability >= 0 else data.durability
	changed.emit()
	return true


func unequip(slot: int) -> ItemData:
	var data: ItemData = _items.get(slot)
	if data == null:
		return null
	_items.erase(slot)
	_durability.erase(slot)
	changed.emit()
	return data


func swap_from(slot: int, from: Inventory, entry: InventoryEntry) -> bool:
	if from == null or entry == null or not accepts(slot, entry.data):
		return false
	if is_free(slot):
		if equip(slot, entry.data, entry.durability):
			from.remove(entry)
			return true
		return false
	var old: ItemData = _items[slot]
	var old_durability: int = _durability[slot]
	var spot := _spot_for(old, from, entry)
	if spot.is_empty():
		return false
	from.remove(entry)
	_items[slot] = entry.data
	_durability[slot] = entry.durability if entry.durability >= 0 else entry.data.durability
	from.add_at(old, spot["origin"], old_durability, spot["rotated"])
	changed.emit()
	return true


func can_swap_from(slot: int, from: Inventory, entry: InventoryEntry) -> bool:
	if from == null or entry == null or not accepts(slot, entry.data):
		return false
	return is_free(slot) or not _spot_for(_items[slot], from, entry).is_empty()


func _spot_for(data: ItemData, grid: Inventory, leaving: InventoryEntry) -> Dictionary:
	for rotated in [false, true]:
		if grid.is_region_free(leaving.origin, data.footprint(rotated), leaving):
			return {"origin": leaving.origin, "rotated": rotated}
	for rotated in [false, true]:
		var origin := grid.find_free_origin(data.footprint(rotated))
		if origin.x >= 0:
			return {"origin": origin, "rotated": rotated}
	return {}
