class_name InventoryEntry
extends RefCounted

var data: ItemData
var origin: Vector2i
var durability: int
var rotated: bool


func _init(
	p_data: ItemData, p_origin: Vector2i, p_durability: int = -1, p_rotated: bool = false
) -> void:
	data = p_data
	origin = p_origin
	durability = p_durability if p_durability >= 0 else (p_data.durability if p_data else 0)
	rotated = p_rotated


func get_size() -> Vector2i:
	return data.footprint(rotated)


func covers(cell: Vector2i) -> bool:
	var size := get_size()
	return (
		cell.x >= origin.x and cell.x < origin.x + size.x
		and cell.y >= origin.y and cell.y < origin.y + size.y
	)
