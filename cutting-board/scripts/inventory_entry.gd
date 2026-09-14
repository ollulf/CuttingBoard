class_name InventoryEntry
extends RefCounted

## One occupied region of an Inventory grid: which item sits there and where its
## top-left corner is. One entry is one item — items do not stack, so a second hammer
## takes its own squares rather than piling onto the first.

var data: ItemData
var origin: Vector2i
## What this item has left, on ItemData.durability's scale. Wear is held here and not on
## the ItemData because an ItemData is a single shared resource: every hammer in the
## game points at the same record, so damage written there would be damage to all of
## them at once.
var durability: int
## Whether this item is stored turned on its side. Like durability it belongs to the one
## item and not to its ItemData, since every copy of the item shares that record and
## they need not all lie the same way round.
var rotated: bool


## A durability of -1 means "as authored", which is what a fresh item arrives with.
func _init(
	p_data: ItemData, p_origin: Vector2i, p_durability: int = -1, p_rotated: bool = false
) -> void:
	data = p_data
	origin = p_origin
	durability = p_durability if p_durability >= 0 else (p_data.durability if p_data else 0)
	rotated = p_rotated


func get_size() -> Vector2i:
	return data.footprint(rotated)


## True if this region covers the given cell, which is what the UI uses for hit-testing.
func covers(cell: Vector2i) -> bool:
	var size := get_size()
	return (
		cell.x >= origin.x and cell.x < origin.x + size.x
		and cell.y >= origin.y and cell.y < origin.y + size.y
	)
