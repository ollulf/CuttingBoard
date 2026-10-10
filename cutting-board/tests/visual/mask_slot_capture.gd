extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")


func _ready() -> void:
	var shots_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	var level := LEVEL.instantiate()
	add_child(level)
	var player := level.get_node("Player")
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add(load("res://resources/items/villager_mask.tres"))
	inventory.add(load("res://resources/items/bandit_mask.tres"))
	var panel := level.find_child("InventoryPanel", true, false) as InventoryPanel
	await get_tree().create_timer(1.0).timeout
	panel.open()
	for i in 3:
		await get_tree().process_frame
	if not shots_dir.is_empty():
		await RenderingServer.frame_post_draw
		var path := shots_dir.path_join("mask_slot.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
