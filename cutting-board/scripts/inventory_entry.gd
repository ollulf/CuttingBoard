class_name InventoryEntry
extends RefCounted

## One occupied region of an Inventory grid: which item sits there, where its top-left
## corner is, and how many are stacked in that one footprint.

var data: ItemData
var origin: Vector2i
var count: int


func _init(p_data: ItemData, p_origin: Vector2i, p_count: int = 1) -> void:
	data = p_data
	origin = p_origin
	count = p_count


func get_size() -> Vector2i:
	return data.grid_size


## True if this region covers the given cell, which is what the UI uses for hit-testing.
func covers(cell: Vector2i) -> bool:
	var size := get_size()
	return (
		cell.x >= origin.x and cell.x < origin.x + size.x
		and cell.y >= origin.y and cell.y < origin.y + size.y
	)
