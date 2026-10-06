extends Node

## Screenshots of the worn-mask square between the hands on the hotbar: the HUD with
## the player's mask on, a worn-down mask with its wear bar, and a bare face. Each shot
## is also saved as a 3x close-up of the bar.
##
##   godot --path cutting-board res://tests/visual/hud_mask_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved.

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")

## The part of a 1280x720 window the close-ups are cut from, around the bar.
const ZOOM_RECT := Rect2i(420, 570, 440, 140)
const ZOOM := 3

var _shots_dir := ""
var _equipment: Equipment


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var level := LEVEL.instantiate()
	add_child(level)
	_equipment = level.get_node("Player").get_node("Equipment")
	_tour.call_deferred()


func _tour() -> void:
	await _wait(1.5)
	if _equipment.get_item(Equipment.Slot.MASK) == null:
		_equipment.equip(Equipment.Slot.MASK, BANDIT_MASK)
	await _wait(0.3)
	await _save("01_worn_mask")

	var mask: ItemData = _equipment.get_item(Equipment.Slot.MASK)
	_equipment.set_durability(Equipment.Slot.MASK, int(mask.durability * 0.3))
	await _wait(0.3)
	await _save("02_worn_down")

	_equipment.unequip(Equipment.Slot.MASK)
	await _wait(0.3)
	await _save("03_bare_face")
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
