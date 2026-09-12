class_name Inventory
extends Node

## A grid container measured in squares. Unlike a HandSlot, which holds the live world
## node, an inventory stores lightweight ItemData records, so the same component works
## for the player, a chest, a wagon or a corpse — only grid_size differs.

signal changed

## Width and height of the grid, in squares.
@export var grid_size := Vector2i(6, 8)

var _entries: Array[InventoryEntry] = []


func get_entries() -> Array[InventoryEntry]:
	return _entries


func is_empty() -> bool:
	return _entries.is_empty()


## Adds an item wherever it fits: first onto an existing stack, otherwise into the
## first free footprint, scanning row by row. Returns false if there is no room.
func add(data: ItemData) -> bool:
	if data == null:
		return false
	var stack := _find_open_stack(data)
	if stack:
		stack.count += 1
		changed.emit()
		return true
	var origin := find_free_origin(data.grid_size)
	if origin.x < 0:
		return false
	return add_at(data, origin)


## Adds an item at an exact cell, for placement the player drives by hand.
func add_at(data: ItemData, origin: Vector2i) -> bool:
	if data == null or not is_region_free(origin, data.grid_size):
		return false
	_entries.append(InventoryEntry.new(data, origin))
	changed.emit()
	return true


func can_add(data: ItemData) -> bool:
	if data == null:
		return false
	return _find_open_stack(data) != null or find_free_origin(data.grid_size).x >= 0


## Takes one off the entry's stack, dropping the entry once it empties.
func remove(entry: InventoryEntry) -> void:
	if entry == null or not _entries.has(entry):
		return
	entry.count -= 1
	if entry.count <= 0:
		_entries.erase(entry)
	changed.emit()


## Relocates an entry, leaving it untouched if the destination is blocked.
func move(entry: InventoryEntry, origin: Vector2i) -> bool:
	return move_to(entry, origin, -1)


## Moves `count` items out of an entry to a free region at `origin`; -1 means the whole
## stack. Taking the whole stack relocates the entry, taking part of it splits a new
## entry off and leaves the remainder where it was.
func move_to(entry: InventoryEntry, origin: Vector2i, count: int = -1) -> bool:
	if entry == null or not _entries.has(entry):
		return false
	if count < 0:
		count = entry.count
	count = clampi(count, 1, entry.count)
	var whole := count == entry.count
	# A split leaves the source in place, so the source still blocks the destination;
	# only a whole-stack move may land on the squares it is vacating.
	if not is_region_free(origin, entry.get_size(), entry if whole else null):
		return false
	if whole:
		entry.origin = origin
	else:
		entry.count -= count
		_entries.append(InventoryEntry.new(entry.data, origin, count))
	changed.emit()
	return true


## True if `count` items can be poured from one stack onto another of the same item.
func can_merge(source: InventoryEntry, target: InventoryEntry, count: int = -1) -> bool:
	if source == null or target == null or source == target:
		return false
	if not _entries.has(source) or not _entries.has(target):
		return false
	if source.data != target.data:
		return false
	if count < 0:
		count = source.count
	return count >= 1 and count <= source.count and target.count + count <= target.data.stack_max


## Pours `count` items from one stack into another, emptying the source if it runs out.
func merge(source: InventoryEntry, target: InventoryEntry, count: int = -1) -> bool:
	if not can_merge(source, target, count):
		return false
	if count < 0:
		count = source.count
	target.count += count
	source.count -= count
	if source.count <= 0:
		_entries.erase(source)
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


func _find_open_stack(data: ItemData) -> InventoryEntry:
	if data.stack_max <= 1:
		return null
	for entry in _entries:
		if entry.data == data and entry.count < data.stack_max:
			return entry
	return null


func _overlaps(a_pos: Vector2i, a_size: Vector2i, b_pos: Vector2i, b_size: Vector2i) -> bool:
	return (
		a_pos.x < b_pos.x + b_size.x and b_pos.x < a_pos.x + a_size.x
		and a_pos.y < b_pos.y + b_size.y and b_pos.y < a_pos.y + a_size.y
	)
