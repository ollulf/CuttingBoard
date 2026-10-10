extends Node

const HOTBAR_PANEL := preload("res://scenes/ui/hotbar_panel.tscn")
const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")

var _failures := 0


func _ready() -> void:
	var equipment := Equipment.new()
	add_child(equipment)
	var panel: HotbarPanel = HOTBAR_PANEL.instantiate()
	add_child(panel)
	panel.bind_equipment(equipment)

	_check("bare face at start shows nothing", panel.is_bare_face() and panel.get_mask_texture() == null and not panel.is_mask_worn_down())

	equipment.equip(Equipment.Slot.MASK, BANDIT_MASK)
	_check("bandit mask has an icon to show", BANDIT_MASK.icon != null)
	_check("shows the worn mask", panel.get_mask_texture() == BANDIT_MASK.icon)
	_check("not bare when masked", not panel.is_bare_face())
	_check("fresh mask has no wear bar", not panel.is_mask_worn_down())

	equipment.unequip(Equipment.Slot.MASK)
	equipment.equip(Equipment.Slot.MASK, VILLAGER_MASK)
	_check("follows a swap", panel.get_mask_texture() == VILLAGER_MASK.icon)

	equipment.set_durability(Equipment.Slot.MASK, int(VILLAGER_MASK.durability * 0.4))
	_check("wear bar under half", panel.is_mask_worn_down())

	equipment.set_durability(Equipment.Slot.MASK, 0)
	equipment.unequip(Equipment.Slot.MASK)
	_check("bare face after break", panel.is_bare_face() and panel.get_mask_texture() == null)
	_check("no wear bar on a bare face", not panel.is_mask_worn_down())

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failures += 1
