extends Node3D

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ITEMS := [
	["chair_leg_club", 0.4], ["pegged_rolling_pin", 1.0], ["rocker_sickle", 0.8],
	["back_scratcher_rake", 1.0], ["bandit_mask", 1.0], ["villager_mask", 0.3],
	["rock", 1.0], ["wood_glue", 1.0], ["sawdust_pouch", 1.0], ["hammer", 0.7],
]

var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().create_timer(1.2).timeout
	var player := level.find_child("Player", false, false)
	var inventory: Inventory = player.inventory
	var club: InventoryEntry
	for pair in ITEMS:
		var data := load("res://resources/items/%s.tres" % pair[0]) as ItemData
		var left := roundi(data.durability * pair[1]) if pair[1] < 1.0 else -1
		var entry := inventory.store(data, left)
		if pair[0] == "chair_leg_club":
			club = entry
	var panel := level.find_child("InventoryPanel", true, false) as InventoryPanel
	panel.open()
	for i in 3:
		await get_tree().process_frame
	if club:
		var tile := panel._tiles.get(club) as Control
		var at := Vector2(400, 300)
		if tile:
			at = panel.get_global_transform().affine_inverse() * tile.get_global_rect().get_center()
		panel._tooltip.show_item(club.data, club.durability)
		await get_tree().process_frame
		panel._tooltip.show_item(club.data, club.durability)
		await get_tree().process_frame
		panel._place_tooltip(Vector2(at.x - 40, at.y + 230))
	for i in 3:
		await get_tree().process_frame
	if not _shots_dir.is_empty():
		await RenderingServer.frame_post_draw
		var path := _shots_dir.path_join("inv_types.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
