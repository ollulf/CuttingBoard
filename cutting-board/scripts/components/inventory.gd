class_name Inventory
extends Node

## A grid container measured in squares. Unlike a HandSlot, which holds the live world
## node, an inventory stores lightweight ItemData records, so the same component works
## for the player, a chest, a wagon or a corpse — only grid_size differs.
##
## Items do not stack. Every item occupies its own footprint, which is what makes the
## grid itself the limit on what can be carried: two hammers cost two hammers' worth of
## room, and an item's condition stays its own rather than being averaged into a pile.

signal changed

## Width and height of the grid, in squares.
@export var grid_size := Vector2i(6, 8)
## What this container is called on screen when its grid is opened. Left blank it falls
## back to the owning object's node name, which is enough for a chest called "Chest".
@export var display_name: String

var _entries: Array[InventoryEntry] = []


func get_entries() -> Array[InventoryEntry]:
	return _entries


## The heading to put over this grid.
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	var holder := get_parent()
	return holder.name if holder else "Container"


func is_empty() -> bool:
	return _entries.is_empty()


## Adds an item to the first free footprint, scanning row by row. Returns false if there
## is no room. `durability` is what this particular item has left, or -1 for a fresh one.
func add(data: ItemData, durability: int = -1) -> bool:
	if data == null:
		return false
	var origin := find_free_origin(data.grid_size)
	if origin.x < 0:
		return false
	return add_at(data, origin, durability)


## Adds an item at an exact cell, for placement the player drives by hand.
func add_at(data: ItemData, origin: Vector2i, durability: int = -1) -> bool:
	if data == null or not is_region_free(origin, data.grid_size):
		return false
	_entries.append(InventoryEntry.new(data, origin, durability))
	changed.emit()
	return true


func can_add(data: ItemData) -> bool:
	if data == null:
		return false
	return find_free_origin(data.grid_size).x >= 0


## Takes an item out of the grid.
func remove(entry: InventoryEntry) -> void:
	if entry == null or not _entries.has(entry):
		return
	_entries.erase(entry)
	changed.emit()


## Relocates an entry, leaving it untouched if the destination is blocked. The entry is
## allowed to land on the squares it is itself vacating.
func move(entry: InventoryEntry, origin: Vector2i) -> bool:
	if entry == null or not _entries.has(entry):
		return false
	if not is_region_free(origin, entry.get_size(), entry):
		return false
	entry.origin = origin
	changed.emit()
	return true


func get_entry_at(cell: Vector2i) -> InventoryEntry:
	for entry in _entries:
		if entry.covers(cell):
			return entry
	return null


## True if a size-sized rectangle at origin lies inside the grid and hits nothing.
## `ignore` lets a moving entry test against its own current position.
func is_region_free(origin: Vector2i, size: Vector2i, ignore: InventoryEntry = null) -> bool:
	if origin.x < 0 or origin.y < 0:
		return false
	if origin.x + size.x > grid_size.x or origin.y + size.y > grid_size.y:
		return false
	for entry in _entries:
		if entry == ignore:
			continue
		if _overlaps(origin, size, entry.origin, entry.get_size()):
			return false
	return true


## The first cell a size-sized item fits in, or (-1, -1) when the grid is too full.
func find_free_origin(size: Vector2i) -> Vector2i:
	for y in range(grid_size.y - size.y + 1):
		for x in range(grid_size.x - size.x + 1):
			var origin := Vector2i(x, y)
			if is_region_free(origin, size):
				return origin
	return Vector2i(-1, -1)


func _overlaps(a_pos: Vector2i, a_size: Vector2i, b_pos: Vector2i, b_size: Vector2i) -> bool:
	return (
		a_pos.x < b_pos.x + b_size.x and b_pos.x < a_pos.x + a_size.x
		and a_pos.y < b_pos.y + b_size.y and b_pos.y < a_pos.y + a_size.y
	)
