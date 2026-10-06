extends Node

## Headless checks for the worn-mask square between the hands on the hotbar: it shows
## the worn mask's icon, follows a swap, a mask breaking off and a bare face (nothing shown), and shows
## the wear bar once the mask is under half. Prints PASS/FAIL per check and quits with
## the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/hud_mask_check.tscn

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

	# A mask that breaks comes off the face.
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
