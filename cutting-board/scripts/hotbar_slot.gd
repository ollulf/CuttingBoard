class_name HotbarSlot
extends RefCounted

## One numbered square of the hotbar. A slot is a link, not a container: it points at an
## item that is sitting in the inventory, and the item stays there. Pressing the slot's
## key is what actually makes the item real, and while it is out in the hand the slot
## points at that object instead — so the same square tracks the item the whole way
## round, from the bag, into the hand, and back again.

## Which hand this slot draws into: an index into the player's hands.
var hand_index: int
## The inventory entry this slot is linked to, while the item is in the grid.
var entry: InventoryEntry
## The world object, while this slot's item is out in a hand.
var held: Node3D
## The record for whichever of the two it is. Kept here as well because the entry is
## gone while the item is in hand, and the bar still has to draw the item.
var data: ItemData
## Where the item was sitting in the grid, so putting it away puts it back in its own
## place rather than wherever it happens to fit.
var origin := Vector2i(-1, -1)
var rotated := false


func _init(p_hand_index: int) -> void:
	hand_index = p_hand_index


func is_empty() -> bool:
	return entry == null and not is_held()


## True while this slot's item is out in a hand. The instance check matters: an item
## destroyed out in the world leaves a freed reference behind, which compares equal to
## null and would otherwise read as an empty slot only by accident.
func is_held() -> bool:
	return held != null and is_instance_valid(held)


## Links this slot to an item in the inventory.
func assign(p_entry: InventoryEntry) -> void:
	entry = p_entry
	data = p_entry.data
	origin = p_entry.origin
	rotated = p_entry.rotated
	held = null


## The item has left the grid for a hand. Where it was is remembered, not discarded:
## that is the square it goes back to when it is put away.
func take_into_hand(item: Node3D, from_entry: InventoryEntry) -> void:
	if from_entry:
		data = from_entry.data
		origin = from_entry.origin
		rotated = from_entry.rotated
	held = item
	entry = null


## The item is back in the grid, as a new entry: the old one stopped existing the moment
## it was taken out.
func return_to_grid(p_entry: InventoryEntry) -> void:
	held = null
	entry = p_entry
	if p_entry:
		data = p_entry.data
		origin = p_entry.origin
		rotated = p_entry.rotated


## What this slot's item has left. While it is out in the hand that is read off the live
## object, since that is where damage has been landing; in the bag the entry is the only
## thing still holding the number.
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
