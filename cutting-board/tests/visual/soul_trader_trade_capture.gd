extends Node

## Screenshots of the Soul Trader in the village: where it stands in the market, a look
## at it from the player's eyes with the "Trade" prompt, and the trade screen open on its
## stock with a few soul flasks in the pack.
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <tmp>.avi
##     res://tests/visual/soul_trader_trade_capture.tscn -- --shots=<dir>

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const FLASK := preload("res://resources/items/soul_bottle.tres")

var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	add_child(LEVEL.instantiate())
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	var trader := find_child("SoulTrader", true, false) as Node3D
	var interactor := find_child("Interactor", true, false) as Interactor
	var player := interactor.get_owner() as Node3D
	var camera := interactor.get_parent() as Camera3D
	var panel := find_child("InventoryPanel", true, false) as InventoryPanel
	var forward := -trader.global_transform.basis.z

	# Overview from above the market: the trader, the Mask-Monger and the paths.
	var overview := Camera3D.new()
	add_child(overview)
	overview.look_at_from_position(trader.global_position + Vector3(4.5, 7.0, 7.5),
		trader.global_position + Vector3(3.0, 0, 1.0))
	overview.make_current()
	await _frames(10)
	_shot("village")

	# The player walks up to the cart and looks at the trader.
	camera.make_current()
	player.global_position = trader.global_position + forward * 2.6
	player.look_at(trader.global_position, Vector3.UP)
	await _frames(15)
	_shot("approach")

	var pack: Inventory = panel._inventory
	for i in 5:
		pack.add(FLASK)
	panel.open_trade(Usable.find_in(trader) as Trader)
	await _frames(10)
	_shot("trade")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
