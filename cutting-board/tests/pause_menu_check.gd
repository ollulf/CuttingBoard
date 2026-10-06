extends Node3D

## Headless checks for the mask pause menu: Esc takes the mask off and pauses the tree,
## arrows and Tab reach every carved word, Resume puts it back on and unpauses, Quit needs
## two carves, and Esc leaves pause alone while the inventory or cheat menu is open.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/pause_menu_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")

var _failures := 0
var _quit_calls := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	var menu: PauseMenu = player.find_child("PauseMenu", true, false)
	_check("pause menu is on the player's camera", menu != null)
	if menu == null:
		_finish()
		return
	menu.quit_handler = func() -> void: _quit_calls += 1
	_check("starts closed and unpaused", not menu.is_open() and not get_tree().paused)

	await _press_esc()
	_check("Esc takes the mask off", menu.is_open())
	_check("the tree is paused", get_tree().paused)
	await _wait(0.8)
	_check("Resume is selected first", menu.selected() == PauseMenu.Word.RESUME)

	var reached := {}
	for i in 5:
		reached[menu.selected()] = true
		menu.select_next()
	_check("Tab reaches all five words", reached.size() == 5)
	_check("Tab wraps back to Resume", menu.selected() == PauseMenu.Word.RESUME)
	reached = {menu.selected(): true}
	for dir in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		menu.select_toward(dir)
		reached[menu.selected()] = true
	_check("arrows reach all five words (%d)" % reached.size(), reached.size() == 5)

	_select(menu, PauseMenu.Word.SAVE)
	menu.activate()
	await _wait(0.6)
	_check("carving Save keeps the menu open", menu.is_open() and get_tree().paused)

	_select(menu, PauseMenu.Word.QUIT)
	menu.activate()
	await _wait(0.6)
	_check("the first Quit carve doesn't quit", _quit_calls == 0 and menu.is_open())
	menu.activate()
	await _wait(0.6)
	_check("the second Quit carve quits", _quit_calls == 1)

	_select(menu, PauseMenu.Word.RESUME)
	menu.activate()
	await _wait(1.3)
	_check("Resume puts the mask back on", not menu.is_open())
	_check("Resume unpauses", not get_tree().paused)

	await _press_esc()
	await _wait(0.8)
	await _press_esc()
	await _wait(0.8)
	_check("Esc also puts it back on", not menu.is_open() and not get_tree().paused)

	var inventory: InventoryPanel = player.find_child("InventoryPanel", true, false)
	inventory.open()
	await _press_esc()
	_check("Esc closes the inventory", not inventory.visible)
	_check("closing the inventory doesn't open pause", not menu.is_open() and not get_tree().paused)

	var cheats: CheatMenu = player.find_child("CheatMenu", true, false)
	cheats.open()
	await _press_esc()
	_check("Esc closes the cheat menu", not cheats.visible)
	_check("closing the cheat menu doesn't open pause", not menu.is_open() and not get_tree().paused)
	_finish()


func _select(menu: PauseMenu, word: int) -> void:
	for i in 5:
		if menu.selected() == word:
			return
		menu.select_next()


func _press_esc() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	# Process frames still tick while the tree is paused.
	for i in int(seconds * 60.0):
		await get_tree().process_frame


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
