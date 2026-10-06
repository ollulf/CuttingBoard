extends Node

## Opens the inventory on the test level, takes the player's mask off into the pack so
## the world fades to grain behind the inventory, then puts it back on. Meant for Movie
## Maker (about 7 s at 30 fps); `--shots=<dir>` also saves a still with the grain in.
##
##   godot --path cutting-board --write-movie out.avi --fixed-fps 30 --quit-after 210
##       res://tests/visual/mask_off_vision_capture.tscn -- [--shots=<dir>]

const LEVEL := preload("res://scenes/levels/test_level.tscn")


func _ready() -> void:
	var shots_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	var level := LEVEL.instantiate()
	add_child(level)
	var player := level.get_node("Player")
	var inventory := player.get_node("%Inventory") as Inventory
	var equipment := player.get_node("%Equipment") as Equipment
	var panel := level.find_child("InventoryPanel", true, false) as InventoryPanel
	await _seconds(1.0)
	panel.open()
	await _seconds(1.0)
	var mask := equipment.get_item(Equipment.Slot.MASK)
	var entry := inventory.store(mask, equipment.get_durability(Equipment.Slot.MASK))
	equipment.unequip(Equipment.Slot.MASK)
	await _seconds(2.5)
	if not shots_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots_dir.path_join("mask_off_vision.png"))
	inventory.remove(entry)
	equipment.equip(Equipment.Slot.MASK, mask)
	await _seconds(2.0)
	get_tree().quit()


func _seconds(duration: float) -> void:
	var left := duration
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
