class_name Equipment
extends Node

## What the player is wearing: one item each on the face, the head, the body and the
## back. Like the inventory it keeps ItemData records rather than world objects — a worn
## coat is a loadout entry, not a thing in the scene — and unlike the hands it never
## spawns anything. Each slot takes only its own kind of item, read off
## ItemData.item_type, so a hood cannot go on as a mask.
##
## Wearing something mostly has no effect yet: a pack does not change what the grid
## holds. The mask is the exception — the player's body wears whatever is in the Mask
## slot, which is the face it falls with.

signal changed

enum Slot { MASK, HEAD, BODY, PACK }
const NO_SLOT := -1

## The kind of item each slot takes.
const SLOT_TYPES := {
	Slot.MASK: ItemData.Type.MASK,
	Slot.HEAD: ItemData.Type.HEAD,
	Slot.BODY: ItemData.Type.BODY,
	Slot.PACK: ItemData.Type.PACK,
}

## What is worn from the start, each item in the slot its kind goes in.
@export var starting_items: Array[ItemData] = []

## What each slot holds, by slot; a slot that is not in here is empty.
var _items: Dictionary = {}
## Wear of each worn item. It is kept beside the record and not on it for the same
## reason InventoryEntry keeps it: an ItemData is shared by every copy of the item.
var _durability: Dictionary = {}


func _ready() -> void:
	for data in starting_items:
		equip(slot_for(data), data)


## The slot an item would go in, or NO_SLOT for anything that is not worn.
static func slot_for(data: ItemData) -> int:
	if data == null:
		return NO_SLOT
	for slot in SLOT_TYPES:
		if SLOT_TYPES[slot] == data.item_type:
			return slot
	return NO_SLOT


func get_item(slot: int) -> ItemData:
	return _items.get(slot)


## What the worn item has left, or -1 when the slot is empty.
func get_durability(slot: int) -> int:
	return _durability.get(slot, -1)


## Records what the worn item has left after it took some wear on the body, such as a
## mask struck in the face. Ignored for an empty slot.
func set_durability(slot: int, durability: int) -> void:
	if is_free(slot) or get_durability(slot) == durability:
		return
	_durability[slot] = durability
	changed.emit()


func is_free(slot: int) -> bool:
	return not _items.has(slot)


## Whether `data` is the kind of item `slot` takes, whether or not the slot is free.
func accepts(slot: int, data: ItemData) -> bool:
	return data != null and SLOT_TYPES.has(slot) and SLOT_TYPES[slot] == data.item_type


## Puts an item on. Refused when the slot is taken or the item is the wrong kind, so the
## caller only lets go of its own copy once this has said yes. `durability` is what this
## particular item has left, or -1 for a fresh one.
func equip(slot: int, data: ItemData, durability: int = -1) -> bool:
	if not is_free(slot) or not accepts(slot, data):
		return false
	_items[slot] = data
	_durability[slot] = durability if durability >= 0 else data.durability
	changed.emit()
	return true


## Takes off whatever a slot is wearing and hands back the record, or null when it was
## empty. The wear is lost with it, so read get_durability() first.
func unequip(slot: int) -> ItemData:
	var data: ItemData = _items.get(slot)
	if data == null:
		return null
	_items.erase(slot)
	_durability.erase(slot)
	changed.emit()
	return data


## Swaps an item from a grid with whatever `slot` is wearing: the new item goes on and
## the old one goes into the grid, wear and all, into the squares the new item leaves if
## it fits there and anywhere free otherwise. Refused, with nothing moved, when the item
## is the wrong kind or the old one has nowhere to go. An empty slot is a plain equip.
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
	# The spot is found before anything moves, so a refusal leaves both items put.
	var spot := _spot_for(old, from, entry)
	if spot.is_empty():
		return false
	from.remove(entry)
	_items[slot] = entry.data
	_durability[slot] = entry.durability if entry.durability >= 0 else entry.data.durability
	from.add_at(old, spot["origin"], old_durability, spot["rotated"])
	changed.emit()
	return true


## Whether swap_from() would go through, without moving anything.
func can_swap_from(slot: int, from: Inventory, entry: InventoryEntry) -> bool:
	if from == null or entry == null or not accepts(slot, entry.data):
		return false
	return is_free(slot) or not _spot_for(_items[slot], from, entry).is_empty()


## Where `data` can go in `grid` once `leaving` is out of it: the squares `leaving` frees
## first, either way round, then any free spot. Empty when there is none.
func _spot_for(data: ItemData, grid: Inventory, leaving: InventoryEntry) -> Dictionary:
	for rotated in [false, true]:
		if grid.is_region_free(leaving.origin, data.footprint(rotated), leaving):
			return {"origin": leaving.origin, "rotated": rotated}
	for rotated in [false, true]:
		var origin := grid.find_free_origin(data.footprint(rotated))
		if origin.x >= 0:
			return {"origin": origin, "rotated": rotated}
	return {}
