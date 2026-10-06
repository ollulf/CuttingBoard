extends Node

## Headless checks for swapping a worn item with one from the inventory: the new item
## goes on, the old one lands in the grid with its wear, a full grid refuses the swap,
## and nothing is duplicated or lost. Prints PASS/FAIL per check and quits with the
## number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/equipment_swap_check.tscn

const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")

var _failures := 0


func _ready() -> void:
	var equipment := Equipment.new()
	add_child(equipment)
	var bag := Inventory.new()
	bag.grid_size = Vector2i(4, 2)
	add_child(bag)
	var changes := [0]
	equipment.changed.connect(func() -> void: changes[0] += 1)

	equipment.equip(Equipment.Slot.MASK, BANDIT_MASK, 37)
	var entry := bag.store_at(VILLAGER_MASK, Vector2i(2, 0), 11)
	var before: int = changes[0]
	_check("swap allowed", equipment.can_swap_from(Equipment.Slot.MASK, bag, entry))
	_check("swap goes through", equipment.swap_from(Equipment.Slot.MASK, bag, entry))
	_check("new mask worn", equipment.get_item(Equipment.Slot.MASK) == VILLAGER_MASK)
	_check("new mask keeps its wear", equipment.get_durability(Equipment.Slot.MASK) == 11)
	_check("changed emitted", changes[0] > before)
	var entries := bag.get_entries()
	_check("one item in the bag", entries.size() == 1)
	_check("old mask in the bag", entries[0].data == BANDIT_MASK)
	_check("old mask keeps its wear", entries[0].durability == 37)
	_check("old mask in the freed spot", entries[0].origin == Vector2i(2, 0))

	# A full bag still takes a same-size swap: the worn mask goes in the freed spot.
	bag.store_at(BANDIT_MASK, Vector2i(0, 0), 5)
	var back := bag.get_entry_at(Vector2i(2, 0))
	_check("same-size swap back fits", equipment.can_swap_from(Equipment.Slot.MASK, bag, back))

	# A full grid with a small dragged item: the worn 2x2 mask cannot fit anywhere.
	var tiny := ItemData.new()
	tiny.item_type = BANDIT_MASK.item_type
	tiny.grid_size = Vector2i(1, 1)
	tiny.durability = 10
	var full := Inventory.new()
	full.grid_size = Vector2i(2, 2)
	add_child(full)
	var small := full.store_at(tiny, Vector2i(0, 0), 3)
	full.store_at(tiny, Vector2i(1, 0), 4)
	full.store_at(tiny, Vector2i(0, 1), 6)
	equipment.unequip(Equipment.Slot.MASK)
	equipment.equip(Equipment.Slot.MASK, BANDIT_MASK, 37)
	var worn := equipment.get_item(Equipment.Slot.MASK)
	var worn_wear := equipment.get_durability(Equipment.Slot.MASK)
	_check("no room: refused", not equipment.can_swap_from(Equipment.Slot.MASK, full, small))
	_check("no room: swap fails", not equipment.swap_from(Equipment.Slot.MASK, full, small))
	_check("no room: worn mask unchanged",
		equipment.get_item(Equipment.Slot.MASK) == worn
		and equipment.get_durability(Equipment.Slot.MASK) == worn_wear)
	_check("no room: grid unchanged", full.get_entries().size() == 3 and full.get_entries().has(small))

	_check("wrong kind refused", not equipment.swap_from(Equipment.Slot.HEAD, bag, back))
	_check("bag untouched after refusals", bag.get_entries().size() == 2)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print(("PASS " if ok else "FAIL ") + label)
