extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const HAMMER := preload("res://resources/items/hammer.tres")
const SMALL_BOX := preload("res://resources/items/box_small.tres")
const BARREL := preload("res://resources/items/barrel.tres")

const ZOOM_RECT := Rect2i(420, 570, 440, 140)
const ZOOM := 3

var _shots_dir := ""
var _cycle := false
var _player: Node
var _inventory_panel: InventoryPanel


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--cycle":
			_cycle = true
	var level := LEVEL.instantiate()
	add_child(level)
	_player = level.get_node("Player")
	_inventory_panel = level.find_children("*", "InventoryPanel", true, false)[0]
	_tour.call_deferred()


func _tour() -> void:
	await _wait(1.5)
	await _save("01_hud_empty")

	var inventory: Inventory = _player.inventory
	var hotbar: Hotbar = _player.hotbar
	hotbar.assign(0, inventory.store(ROCK))
	hotbar.assign(1, inventory.store(SMALL_BOX))
	hotbar.assign(3, inventory.store(HAMMER))
	hotbar.assign(5, inventory.store(BARREL))
	await _wait(0.3)
	await _save("02_hud_filled")

	hotbar.use(3)
	await _wait(0.5)
	await _save("03_hud_held")

	if _cycle:
		for index in [0, 3, 0, 3]:
			await _wait(0.6)
			hotbar.use(index)
		await _wait(0.8)

	_inventory_panel.open()
	await _wait(0.4)
	await _save("04_inventory")
	get_tree().quit()


func _save(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_shots_dir.path_join("%s.png" % shot_name))
	var zoom := image.get_region(ZOOM_RECT)
	zoom.resize(ZOOM_RECT.size.x * ZOOM, ZOOM_RECT.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	zoom.save_png(_shots_dir.path_join("%s_zoom.png" % shot_name))
	print("saved ", shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
