extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const BOX_SMALL := preload("res://resources/items/box_small.tres")

var _sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1200, 450)]
var _shots_dir := ""
var _shot_count := 0
var _failures := 0
var _level: Node
var _panel: InventoryPanel
var _bar: HotbarPanel
var _mouse := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			_sizes = [Vector2i(int(parts[0]), int(parts[1]))]
		elif arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	get_window().size = _sizes[0]
	_level = LEVEL.instantiate()
	add_child(_level)
	_panel = _level.find_child("InventoryPanel", true, false) as InventoryPanel
	_bar = _level.find_child("HotbarPanel", true, false) as HotbarPanel
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var pack: Inventory = _panel._inventory
	var hotbar: Hotbar = _panel._hotbar
	pack.add_at(ROCK, Vector2i(0, 0))
	pack.add_at(BOX_SMALL, Vector2i(0, 2))
	var rock := pack.get_entry_at(Vector2i(0, 0))

	for window_size in _sizes:
		get_window().size = window_size
		_panel.open()
		await _frames(3)
		await _drags(window_size, pack, hotbar, rock)
		_panel.close()
		await _frames(2)

	await _drag_link_back(hotbar, rock)
	var key := InputEventAction.new()
	key.action = "hotbar_2"
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(5)
	_check("key 2 draws the linked rock into the left hand",
		_panel._hands[0].get_item_data() == ROCK)

	_check_rotated_icon()
	_check_type_and_wear()

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check_rotated_icon() -> void:
	var long_item := ROCK.duplicate() as ItemData
	long_item.grid_size = Vector2i(3, 1)
	long_item.icon = PlaceholderTexture2D.new()
	var flat := _panel._make_tile(long_item, false)
	var tile := _panel._make_tile(long_item, true)
	var icon := tile.get_child(0) as Control
	var flat_icon_size: Vector2 = flat.size - Vector2(8, 8)
	var turned := Rect2(icon.position + icon.pivot_offset - Vector2(icon.size.y, icon.size.x) / 2.0,
		Vector2(icon.size.y, icon.size.x))
	_check("rotated tile turns its icon a quarter", is_equal_approx(icon.rotation, PI / 2.0))
	_check("rotated icon keeps the unrotated size", icon.size.is_equal_approx(flat_icon_size))
	_check("rotated icon bounds fill the tile",
		turned.is_equal_approx(Rect2(Vector2(4, 4), tile.size - Vector2(8, 8))))
	flat.free()
	tile.free()


func _check_type_and_wear() -> void:
	var club := load("res://resources/items/chair_leg_club.tres") as ItemData
	var mask := load("res://resources/items/bandit_mask.tres") as ItemData
	var club_tile := _panel._make_tile(club, false, club.durability / 2)
	var mask_tile := _panel._make_tile(mask)
	var rock_tile := _panel._make_tile(ROCK)
	var fill := func(tile: Control) -> Color:
		return (tile.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	_check("weapon tile has the weapon fill", fill.call(club_tile) == _panel.weapon_color)
	_check("mask tile has the mask fill", fill.call(mask_tile) == _panel.mask_color)
	_check("rock tile has the everyday fill", fill.call(rock_tile) == _panel.item_color)
	var badge := club_tile.get_node_or_null("DamageBadge") as Label
	_check("weapon tile shows its damage (%d)" % club.melee_damage(),
		badge != null and club.melee_damage() > 0 and badge.text == str(club.melee_damage()))
	_check("non-weapon tile shows no damage", rock_tile.get_node_or_null("DamageBadge") == null)
	var wear := club_tile.get_node_or_null("WearLine") as ColorRect
	var full := club_tile.size.x - 8
	_check("half-worn weapon draws a half-length wear line",
		wear != null and absf(wear.size.x - full * 0.5) <= 1.0)
	_check("fresh mask draws no wear line", mask_tile.get_node_or_null("WearLine") == null)
	_panel._tooltip.show_item(club, club.durability / 2)
	var damage_label := _panel._tooltip.get_node("%DamageLabel") as Label
	_check("tooltip shows the weapon's damage",
		damage_label.visible and damage_label.text == "Damage  %d" % club.melee_damage())
	_panel._tooltip.show_item(mask)
	_check("tooltip hides damage for a mask", not damage_label.visible or mask.melee_damage() > 0)
	_panel._tooltip.hide()
	for tile in [club_tile, mask_tile, rock_tile]:
		tile.free()


func _drags(window_size: Vector2i, pack: Inventory, hotbar: Hotbar, rock: InventoryEntry) -> void:
	var at := " (%dx%d)" % [window_size.x, window_size.y]
	for index in hotbar.slot_count():
		hotbar.clear(index)

	await _drag(_cell_center(Vector2i(0, 0)), _slot_center(0), MOUSE_BUTTON_LEFT)
	_check("grid -> hotbar square 1 links the rock" + at, hotbar.get_slot(0).entry == rock)
	_check("the rock stays in the grid" + at, pack.get_entry_at(Vector2i(0, 0)) == rock)

	await _drag(_cell_center(Vector2i(0, 2)), _slot_center(2), MOUSE_BUTTON_LEFT)
	_check("grid -> hotbar square 3 links the box" + at, hotbar.get_slot(2).data == BOX_SMALL)

	await _drag(_slot_center(0), _slot_center(1), MOUSE_BUTTON_LEFT)
	_check("link dragged along the bar moves" + at,
		hotbar.get_slot(1).entry == rock and hotbar.get_slot(0).entry == null)

	await _click(_slot_center(2), MOUSE_BUTTON_RIGHT)
	_check("right-click clears a square" + at, hotbar.get_slot(2).entry == null)
	_check("clearing leaves the item in the grid" + at,
		pack.get_entry_at(Vector2i(0, 2)) != null)


func _drag_link_back(hotbar: Hotbar, rock: InventoryEntry) -> void:
	if hotbar.get_slot(1).entry != rock:
		hotbar.assign(1, rock)
	await _frames(1)


func _drag(from: Vector2, to: Vector2, button: MouseButton) -> void:
	await _move(from)
	_button(from, button, true)
	await _frames(2)
	for step in range(1, 7):
		await _move(from.lerp(to, step / 6.0), button)
	await _shot()
	_button(to, button, false)
	await _frames(2)


func _click(at: Vector2, button: MouseButton) -> void:
	await _move(at)
	_button(at, button, true)
	await _frames(1)
	_button(at, button, false)
	await _frames(2)


func _move(to: Vector2, held: MouseButton = MOUSE_BUTTON_NONE) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - _mouse
	if held != MOUSE_BUTTON_NONE:
		event.button_mask = 1 << (held - 1)
	_mouse = to
	Input.parse_input_event(event)
	await _frames(1)


func _button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	if pressed:
		event.button_mask = 1 << (button - 1)
	Input.parse_input_event(event)


func _slot_center(index: int) -> Vector2:
	return _bar.slot_rect(index).get_center()


func _cell_center(cell: Vector2i) -> Vector2:
	var half := _panel.cell_size * 0.5
	return _panel._grid_for(InventoryPanel.Side.PLAYER).global_position + Vector2(
		_panel._offset(cell.x) + half, _panel._offset(cell.y) + half
	)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


func _shot() -> void:
	if _shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	_shot_count += 1
	get_viewport().get_texture().get_image().save_png(
		"%s/hotbar_drag_%d.png" % [_shots_dir, _shot_count]
	)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
