extends Node3D

## Headless checks for the opening: the player starts bare-faced and held still, holding
## Esc skips to the landing without opening the pause menu, the fall ends on the ground at
## the landing spot with control handed over, and `--skip-intro` is recognised.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/intro_sequence_check.tscn
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/intro_sequence_check.tscn -- --skip-intro

const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--skip-intro" in OS.get_cmdline_user_args():
		_check("--skip-intro is recognised", IntroSequence.skip_requested())
		_finish()
		return
	_check("no skip without the argument", not IntroSequence.skip_requested())
	var level := LEVEL.instantiate()
	add_child(level)
	await _frames(5)
	var intro: IntroSequence = level.find_child("IntroSequence", true, false)
	var player = level.find_child("Player", true, false)
	var menu: PauseMenu = player.find_child("PauseMenu", true, false)
	var hud: CanvasLayer = player.get_node("%InteractionPrompts")
	_check("an instanced level does not start the opening by itself", not intro.running)
	_check("the player starts with no mask", player.equipment.is_free(Equipment.Slot.MASK))
	_check("the player mask is nowhere in the inventory",
		not _inventory_has(player.inventory, "player_mask"))

	# Skip: hold Esc.
	intro.start()
	await _frames(3)
	_check("the opening runs", intro.running)
	_check("movement is locked", player.control == intro.CONTROL_NONE)
	_check("no HUD during the opening", not hud.visible)
	_check("starts high above the meadow", player.global_position.y > 30.0)
	_press_esc(true)
	await _frames(int(intro.skip_hold * 60.0) + 10)
	_press_esc(false)
	_check("holding Esc skips the opening", not intro.running)
	_check("holding Esc does not open the pause menu", not menu.is_open() and not get_tree().paused)
	_check_landed(intro, player, hud)

	# Full fall: jump to the end of the grain beat and let it drop.
	intro.start()
	intro.elapsed = intro.GRAIN_END - 0.5
	await _frames(20)
	print("state ", intro.running, " ", intro.elapsed, " ", player.control, " ", Input.is_action_pressed("pause"))
	_check("look only during the grain", player.control == intro.CONTROL_LOOK_ONLY)
	_check("still high up", player.global_position.y > 30.0)
	await _frames(int((intro.FALL_END - intro.GRAIN_END) * 60.0) + 30)
	_check("the fall ends the opening", not intro.running)
	_check_landed(intro, player, hud)
	await _frames(30)
	_check("still standing after a second (no fall damage)", player.health.is_alive()
		and player.health.get_current() >= player.health.max_health)
	_finish()


func _check_landed(intro: IntroSequence, player, hud: CanvasLayer) -> void:
	var flat := Vector2(player.global_position.x, player.global_position.z)
	_check("lands at the landing spot",
		flat.distance_to(Vector2(intro.landing_spot.x, intro.landing_spot.z)) < 0.5)
	_check("lands on the ground", absf(player.global_position.y - intro._ground_y) < 0.5)
	_check("control is handed over", player.control == intro.CONTROL_FULL
		and player.is_physics_processing())
	_check("the HUD is back", hud.visible)


func _inventory_has(inventory: Inventory, id: String) -> bool:
	for entry in inventory.get_entries():
		if entry.data != null and entry.data.resource_path.get_file().get_basename() == id:
			return true
	return false


func _press_esc(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)
