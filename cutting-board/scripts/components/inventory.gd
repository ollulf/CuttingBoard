class_name Inventory
extends Node

signal changed

@export var grid_size := Vector2i(6, 8)
@export var display_name: String

var _entries: Array[InventoryEntry] = []


func get_entries() -> Array[InventoryEntry]:
	return _entries


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	var holder := get_parent()
	return holder.name if holder else "Container"


func is_empty() -> bool:
	return _entries.is_empty()


func add(data: ItemData, durability: int = -1) -> bool:
	return store(data, durability) != null


func add_at(data: ItemData, origin: Vector2i, durability: int = -1, rotated: bool = false) -> bool:
	return store_at(data, origin, durability, rotated) != null


func store(data: ItemData, durability: int = -1) -> InventoryEntry:
	if data == null:
		return null
	for rotated in [false, true]:
		var origin := find_free_origin(data.footprint(rotated))
		if origin.x >= 0:
			return store_at(data, origin, durability, rotated)
	return null


func store_at(
	data: ItemData, origin: Vector2i, durability: int = -1, rotated: bool = false
) -> InventoryEntry:
	if data == null or not is_region_free(origin, data.footprint(rotated)):
		return null
	var entry := InventoryEntry.new(data, origin, durability, rotated)
	_entries.append(entry)
	changed.emit()
	return entry


func can_add(data: ItemData) -> bool:
	if data == null:
		return false
	return find_free_origin(data.grid_size).x >= 0 or find_free_origin(data.footprint(true)).x >= 0


func remove(entry: InventoryEntry) -> void:
	if entry == null or not _entries.has(entry):
		return
	_entries.erase(entry)
	changed.emit()


func move(entry: InventoryEntry, origin: Vector2i, rotated: bool) -> bool:
	if entry == null or not _entries.has(entry):
		return false
	if not is_region_free(origin, entry.data.footprint(rotated), entry):
		return false
	entry.origin = origin
	entry.rotated = rotated
	changed.emit()
	return true


func rotate_item(entry: InventoryEntry) -> bool:
	return entry != null and move(entry, entry.origin, not entry.rotated)


func get_entry_at(cell: Vector2i) -> InventoryEntry:
	for entry in _entries:
		if entry.covers(cell):
			return entry
	return null


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
