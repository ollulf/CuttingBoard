extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")

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
	var buttons := menu.find_child("ItemList", true, false).get_children()
	_check("one button per item", buttons.size() == items.size())

	var inventory: Inventory = player.find_child("Inventory", true, false)
	var target: ItemData = items[0]
	for i in items.size():
		if buttons[i].text == target.display_name:
			buttons[i].pressed.emit()
			break
	var found := false
	for entry in inventory.get_entries():
		if entry.data == target:
			found = true
	_check("pressing a button adds %s" % target.display_name, found)

	menu.toggle()
	_check("toggle closes the menu", not menu.visible)
	_finish()


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
