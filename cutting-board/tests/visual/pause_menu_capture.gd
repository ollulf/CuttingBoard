extends Node

## Records the mask pause menu in the test level: Esc takes the mask off, the selection
## moves over the carved words, Save is carved ("not yet"), then Resume is carved and the
## mask goes back on. Meant for Movie Maker:
##
##   godot --path cutting-board --write-movie out.avi --fixed-fps 30 --resolution 960x540
##     res://tests/visual/pause_menu_capture.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _menu: PauseMenu


func _ready() -> void:
	# Keeps directing the shot while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := LEVEL.instantiate()
	add_child(level)
	_menu = level.find_children("*", "PauseMenu", true, false)[0]
	_menu.quit_handler = func() -> void: pass
	_tour.call_deferred()


func _tour() -> void:
	await _wait(1.0)
	_menu.open()
	await _wait(1.2)
	for dir in [Vector2.DOWN, Vector2.RIGHT, Vector2.DOWN]:
		_menu.select_toward(dir)
		await _wait(0.5)
	_menu.select_toward(Vector2.LEFT)
	_menu.select_toward(Vector2.UP)
	_menu.select_toward(Vector2.LEFT)
	await _wait(0.4)
	_menu.activate()
	await _wait(1.4)
	while _menu.selected() != PauseMenu.Word.RESUME:
		_menu.select_next()
	await _wait(0.5)
	_menu.activate()
	await _wait(1.6)
	get_tree().quit()


## Counts frames at the recording rate (--fixed-fps 30).
func _wait(seconds: float) -> void:
	for i in int(seconds * 30.0):
		await get_tree().process_frame
