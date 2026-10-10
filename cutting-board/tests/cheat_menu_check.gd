extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const CREATURE := preload("res://scenes/characters/chair_creature.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	var menu: CheatMenu = player.find_child("CheatMenu", true, false)
	_check("cheat menu is in the HUD", menu != null)
	if menu == null:
		_finish()
		return
	_check("cheat menu starts closed", not menu.visible)
	var press := InputEventAction.new()
	press.action = &"toggle_cheats"
	press.pressed = true
	menu._unhandled_key_input(press)
	_check("toggle_cheats opens the menu", menu.visible)

	var items := CheatMenu.find_items()
	var files := Array(DirAccess.get_files_at(CheatMenu.ITEMS_DIR)).filter(
		func(f: String) -> bool: return f.trim_suffix(".remap").ends_with(".tres"))
	_check("every item resource is found (%d)" % files.size(), items.size() == files.size() and items.size() > 0)
	var buttons: Array[Button] = []
	for child in menu.find_child("ItemList", true, false).get_children():
		if child is Button:
			buttons.append(child)
	_check("one button per item", buttons.size() == items.size())

	_check_grouping(menu)

	var inventory: Inventory = player.find_child("Inventory", true, false)
	var target: ItemData = items[0]
	for button in buttons:
		if button.text == target.display_name:
			button.pressed.emit()
			break
	var found := false
	for entry in inventory.get_entries():
		if entry.data == target:
			found = true
	_check("pressing a button adds %s" % target.display_name, found)

	await _check_infinite_health(menu, player)
	await _check_no_aggro(menu, player)

	menu.toggle()
	_check("toggle closes the menu", not menu.visible)
	_finish()


func _check_grouping(menu: CheatMenu) -> void:
	var sorted := CheatMenu.sorted_items()
	var ordered := true
	for i in range(1, sorted.size()):
		var a := sorted[i - 1]
		var b := sorted[i]
		var rank_a := CheatMenu.type_rank(a)
		var rank_b := CheatMenu.type_rank(b)
		if rank_a > rank_b:
			ordered = false
		elif rank_a == rank_b and CheatMenu.label_for(a).naturalnocasecmp_to(CheatMenu.label_for(b)) > 0:
			ordered = false
	_check("items sorted by type, then name", ordered)
	_check("weapons come first", CheatMenu.type_rank(sorted[0]) == 0)

	var types := {}
	for data in sorted:
		types[data.item_type] = true
	var children := menu.find_child("ItemList", true, false).get_children()
	var headers := children.filter(func(c: Node) -> bool: return c.is_in_group(CheatMenu.HEADER_GROUP))
	_check("one header per item type present (%d)" % types.size(), headers.size() == types.size())
	_check("list starts with a header", children.size() > 0 and children[0].is_in_group(CheatMenu.HEADER_GROUP))

	var layout_ok := true
	var current := ""
	var index := 0
	for child in children:
		if child.is_in_group(CheatMenu.HEADER_GROUP):
			current = (child as Label).text
			continue
		var data := sorted[index]
		index += 1
		if (child as Button).text != CheatMenu.label_for(data) or CheatMenu.TYPE_HEADERS[data.item_type] != current:
			layout_ok = false
	_check("buttons sit under their type's header in sorted order", layout_ok and index == sorted.size())


func _check_infinite_health(menu: CheatMenu, player: Node3D) -> void:
	var toggle: CheckButton = menu.find_child("InfiniteHealth", true, false)
	_check("infinite health toggle exists and starts off", toggle != null and not toggle.button_pressed and not Cheats.infinite_health)
	var health: Health = player.get_node("%Health")
	var equipment: Equipment = player.get_node("%Equipment")
	var mask: ItemData = null
	for data in CheatMenu.find_items():
		if data.item_type == ItemData.Type.MASK and data.durability > 0:
			mask = data
			break
	if mask:
		equipment.equip(Equipment.Slot.MASK, mask, mask.durability)
		await get_tree().process_frame

	toggle.button_pressed = true
	_check("toggle turns infinite health on", Cheats.infinite_health)
	var before := health.get_current()
	var mask_before := equipment.get_durability(Equipment.Slot.MASK)
	health.apply_damage(DamageInfo.new(before + 500, self))
	await get_tree().process_frame
	_check("player takes no damage", health.get_current() == before and health.is_alive())
	if mask:
		_check("worn %s keeps its durability" % mask.display_name,
			equipment.get_durability(Equipment.Slot.MASK) == mask_before
			and equipment.get_item(Equipment.Slot.MASK) == mask)

	toggle.button_pressed = false
	_check("toggle turns infinite health off", not Cheats.infinite_health)
	health.apply_damage(DamageInfo.new(1, self))
	_check("player takes damage again", health.get_current() < before)


func _check_no_aggro(menu: CheatMenu, player: Node3D) -> void:
	var toggle: CheckButton = menu.find_child("NoAggro", true, false)
	_check("no aggro toggle exists and starts off", toggle != null and not toggle.button_pressed and not Cheats.no_aggro)
	var equipment: Equipment = player.get_node("%Equipment")
	if not equipment.is_free(Equipment.Slot.MASK):
		equipment.unequip(Equipment.Slot.MASK)
	var bandit: Npc = BANDIT.instantiate()
	add_child(bandit)
	bandit.global_position = Vector3(4, 0.05, 0)
	var creature = CREATURE.instantiate()
	add_child(creature)
	creature.global_position = Vector3(-4, 0.05, 0)
	await get_tree().process_frame

	var hostile_before := bandit.faction.is_hostile_to(player)
	print("  bandit hostile to player before: %s" % hostile_before)
	bandit.hold_grudge(player)
	creature._target = player
	creature._state = creature.State.CHASE
	_check("bandit targets the player before", bandit.get_attack_target() == player)
	_check("chair creature targets the player before", creature.get_attack_target() == player)

	toggle.button_pressed = true
	_check("toggle turns no aggro on", Cheats.no_aggro)
	_check("bandit is not hostile to the player", not bandit.faction.is_hostile_to(player))
	_check("bandit drops its grudge and target", not bandit.has_grudge_against(player) and bandit.get_attack_target() == null)
	_check("bandit forgets the player", not bandit.memory.knows(player))
	_check("chair creature gives up the chase",
		creature.get_attack_target() == null and creature.get_state() == creature.State.ROAM)
	bandit.hold_grudge(player)
	_check("hitting a bandit starts no grudge", not bandit.has_grudge_against(player))
	creature._on_spotted(player)
	_check("chair creature ignores the player when it spots them", creature.get_attack_target() == null)

	toggle.button_pressed = false
	_check("toggle turns no aggro off", not Cheats.no_aggro)
	_check("bandit hostility returns when off", bandit.faction.is_hostile_to(player) == hostile_before)
	bandit.queue_free()
	creature.queue_free()


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
