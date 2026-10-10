extends Node3D

const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _failures := 0
var _hits: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--skip-intro" in OS.get_cmdline_user_args():
		_check("--skip-intro is recognised", IntroSequence.skip_requested())
		_finish()
		return
	_check("no skip without the argument", not IntroSequence.skip_requested())
	var missing := IntroSequence.CUES.filter(
		func(cue: Array) -> bool: return not ResourceLoader.exists(IntroSequence.SFX + cue[1] + ".wav")
	)
	_check("every sound of the opening exists", missing.is_empty())
	var level := LEVEL.instantiate()
	add_child(level)
	for npc in level.find_children("*", "Npc", true, false):
		npc.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	var intro: IntroSequence = level.find_child("IntroSequence", true, false)
	var player = level.find_child("Player", true, false)
	var menu: PauseMenu = player.find_child("PauseMenu", true, false)
	var hud: CanvasLayer = player.get_node("%InteractionPrompts")
	player.health.damaged.connect(func(info: DamageInfo) -> void:
		_hits.append("%d from %s" % [info.amount, info.source.get_path() if info.source else "nothing"]))
	_check("an instanced level does not start the opening by itself", not intro.running)
	_check("the player starts with no mask", player.equipment.is_free(Equipment.Slot.MASK))
	_check("the player mask is nowhere in the inventory",
		not _inventory_has(player.inventory, "player_mask"))

	intro.start()
	await _frames(3)
	_check("the opening runs", intro.running)
	_check("movement is locked", player.control == intro.CONTROL_NONE)
	_check("no HUD during the opening", not hud.visible)
	_check("starts high above the meadow", player.global_position.y > 30.0)
	_check("the skip hint is shown", is_instance_valid(intro.hint) and intro.hint.is_visible_in_tree())
	var hint: Control = intro.hint
	_press_esc(true)
	await _frames(int(intro.skip_hold * 60.0) + 10)
	_press_esc(false)
	_check("holding Esc skips the opening", not intro.running)
	_check("holding Esc does not open the pause menu", not menu.is_open() and not get_tree().paused)
	_check_landed(intro, player, hud)
	await _frames(2)
	_check("the skip hint is gone", not is_instance_valid(hint))

	intro.start()
	intro.elapsed = intro.GRAIN_END + 1.0
	await _frames(3)
	_press_esc(true)
	await _frames(int(intro.skip_hold * 60.0) + 10)
	_press_esc(false)
	_check("holding Esc skips mid-fall", not intro.running)
	_check_landed(intro, player, hud)

	intro.start()
	_check("all black until the heart beats", intro._hole(intro.HEARTBEATS[0] - 0.1) == 0.0)
	_check("the heartbeats open the dark from the centre",
		intro._hole(intro.HEARTBEATS[1] + 0.6) > intro._hole(intro.HEARTBEATS[0] + 0.6))
	_check("clear once born", intro._hole(intro.BIRTH_END) > 1.5)
	intro.elapsed = intro.GRAIN_END - 0.5
	await _frames(20)
	_check("look only during the grain", player.control == intro.CONTROL_LOOK_ONLY)
	_check("still high up", player.global_position.y > 30.0)
	var limit := int((intro.FALL_END - intro.GRAIN_END) * 60.0) * 3
	while intro.running and limit > 0:
		await _frames(1)
		limit -= 1
	_check("the fall ends the opening", not intro.running)
	_check_landed(intro, player, hud)
	await _frames(60)
	_check("standing on the floor after landing", player.is_on_floor())
	_check("still standing after a second (no fall damage)%s" % (" " + str(_hits) if _hits else ""),
		player.health.is_alive() and player.health.get_current() >= player.health.max_health)
	player.global_position = Vector3(0, 1, 0)
	intro.place_at_landing()
	var flat := Vector2(player.global_position.x, player.global_position.z)
	_check("skipping the intro lands at the same spot",
		flat.distance_to(Vector2(intro.landing_spot.x, intro.landing_spot.z)) < 0.1)
	_finish()


func _check_landed(intro: IntroSequence, player, hud: CanvasLayer) -> void:
	var flat := Vector2(player.global_position.x, player.global_position.z)
	_check("lands at the landing spot",
		flat.distance_to(Vector2(intro.landing_spot.x, intro.landing_spot.z)) < 0.5)
	_check("lands on the ground", absf(player.global_position.y - intro._ground_y) < 0.5)
	_check("lands on the ground, not on a roof", intro._ground_y < 1.0)
	var monger := intro.owner.find_child("MaskMonger", true, false) as Node3D
	if monger:
		var to_monger: Vector3 = monger.global_position - player.global_position
		to_monger.y = 0.0
		var facing: Vector3 = -player.global_basis.z
		_check("lands next to the Mask-Monger (%.1f m)" % to_monger.length(),
			to_monger.length() > 1.2 and to_monger.length() < 4.0)
		_check("lands facing the Mask-Monger", facing.dot(to_monger.normalized()) > 0.9)
	else:
		_check("the level has a Mask-Monger", false)
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
