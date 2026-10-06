extends Node

## Screenshot and clip tour of the inventory screen: loads the test level, fills the
## player's pack, hands and loadout, and photographs the screen in its main states —
## empty, full, with a chest open, and mid-drag over an equipment slot that will and
## one that will not take the item.
##
##   godot --path cutting-board res://tests/visual/inventory_capture.tscn -- --shots=<dir>
##   godot --path cutting-board --write-movie <out>.avi --fixed-fps 30 \
##       res://tests/visual/inventory_capture.tscn -- --movie
##
## --only=<name>,<name> limits the stills to shots whose names contain those. --movie
## plays a scripted drag into the equipment slots instead of taking stills, with a drawn
## cursor since the OS one is not in the frame. Both need a real window. --check runs
## every kind of drag through the panel and prints PASS / FAIL, and works headless.
##
## The worn items here are placeholders built in code: there are no mask, head, body or
## pack items in the game yet.

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const HAMMER := preload("res://resources/items/hammer.tres")
const BOX_SMALL := preload("res://resources/items/box_small.tres")
const BARREL := preload("res://resources/items/barrel.tres")

var _shots_dir := ""
var _only: PackedStringArray = []
var _movie := false
var _check_only := false
var _level: Node
var _player: Node3D
var _panel: InventoryPanel
var _cursor: Polygon2D
var _chest: Inventory
var _mask: ItemData
var _hood: ItemData
var _coat: ItemData
var _satchel: ItemData


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--movie":
			_movie = true
		elif arg == "--check":
			_check_only = true
	_level = LEVEL.instantiate()
	add_child(_level)
	_player = _level.get_node("Player")
	_player.global_position = Vector3(1, _player.global_position.y, -38)
	_player.rotation.y = atan2(1.0, 20.0)
	_panel = _level.find_child("InventoryPanel", true, false) as InventoryPanel
	_mask = _placeholder("Tallow Mask", "MASK", Vector2i(2, 2), "Pale wax, still warm.")
	_hood = _placeholder("Wool Hood", "HEAD", Vector2i(2, 2), "")
	_coat = _placeholder("Waxed Coat", "BODY", Vector2i(2, 3), "")
	_satchel = _placeholder("Satchel", "PACK", Vector2i(2, 3), "")
	_chest = Inventory.new()
	_chest.grid_size = Vector2i(6, 5)
	_chest.display_name = "Chest"
	_level.add_child(_chest)
	_make_cursor()
	if _check_only:
		_run_checks.call_deferred()
	elif _movie:
		_play_movie.call_deferred()
	else:
		_tour.call_deferred()


## A worn item for the tour, typed by name so this scene still loads on a build without
## those types — which is what lets it photograph the screen before the change too.
func _placeholder(title: String, type_name: String, size: Vector2i, text: String) -> ItemData:
	var data := ItemData.new()
	data.display_name = title + " (placeholder)"
	data.description = text
	data.grid_size = size
	data.weight = 0.5
	data.durability = 60
	if ItemData.Type.has(type_name):
		data.item_type = ItemData.Type[type_name]
	return data


func _tour() -> void:
	await _wait(1.2)
	_panel.open()
	await _settle()
	await _save("inv_01_empty")

	_fill_pack()
	_hold_hammer()
	_wear([_coat, _satchel])
	_hurt(28)
	await _settle()
	await _save("inv_02_items")

	_fill_chest()
	_panel.open_container(_chest)
	await _settle()
	await _save("inv_03_container")

	_panel.close()
	_panel.open()
	await _settle()
	# Pick the mask up out of the pack and hold it over the Mask slot, then the rock.
	var slots := _wear_slot_rects()
	if not slots.is_empty():
		_drag_from_pack(Vector2i(2, 0), slots["MASK"].get_center())
		await _settle()
		await _save("inv_04_drag_valid")
		_panel._cancel_drag()
		_drag_from_pack(Vector2i(0, 0), slots["MASK"].get_center())
		await _settle()
		await _save("inv_05_drag_invalid")
		_panel._cancel_drag()
	get_tree().quit()


## The scripted clip: the mask goes from the pack onto the face, a rock is offered to the
## Head slot and refused, and the coat comes off the body back into the pack.
func _play_movie() -> void:
	_fill_pack()
	_hold_hammer()
	_wear([_coat, _satchel])
	_hurt(28)
	await _wait(0.6)
	_panel.open()
	await _settle()
	var slots := _wear_slot_rects()
	_cursor.show()
	_cursor.position = Vector2(900, 560)
	await _glide(_pack_cell_center(Vector2i(2, 0)), 0.6)
	await _drag(_pack_cell_center(Vector2i(2, 0)), slots["MASK"].get_center(), 1.1)
	await _wait(0.5)
	await _glide(_pack_cell_center(Vector2i(0, 0)), 0.7)
	await _drag(_pack_cell_center(Vector2i(0, 0)), slots["HEAD"].get_center(), 1.0)
	await _wait(0.5)
	await _glide(slots["BODY"].get_center(), 0.7)
	await _drag(slots["BODY"].get_center(), _pack_cell_center(Vector2i(3, 5)), 1.1)
	await _wait(0.8)
	_report()
	get_tree().quit()


## Drives every kind of drag the screen supports through the panel's own mouse handlers
## and prints PASS or FAIL for each, so the rework can be checked for regressions in
## the paths it did not mean to change as well as the new ones. Runs headless.
func _run_checks() -> void:
	await _wait(0.8)
	var pack: Inventory = _panel._inventory
	var hands: Array[HandSlot] = _panel._hands
	var hotbar: Hotbar = _panel._hotbar
	var equipment := _player.get_node("Equipment") as Equipment
	_fill_pack()
	_panel.open()
	await _settle()
	var slots := _wear_slot_rects()
	var hand_box: Control = _panel._slot_boxes[hands[0]]
	var hand_center := Rect2(hand_box.global_position, hand_box.size).get_center()

	_click_drag(_pack_cell_center(Vector2i(2, 0)), slots["MASK"].get_center())
	_check("grid -> mask slot", equipment.get_item(Equipment.Slot.MASK) == _mask)
	_check("mask left the pack", pack.get_entries().all(func(e): return e.data != _mask))
	_click_drag(_pack_cell_center(Vector2i(4, 0)), slots["BODY"].get_center())
	_check("hood refused by body slot", equipment.is_free(Equipment.Slot.BODY))
	_click_drag(_pack_cell_center(Vector2i(0, 0)), slots["HEAD"].get_center())
	_check("rock refused by head slot", equipment.is_free(Equipment.Slot.HEAD))
	_click_drag(_pack_cell_center(Vector2i(4, 0)), slots["HEAD"].get_center())
	_check("grid -> head slot", equipment.get_item(Equipment.Slot.HEAD) == _hood)
	_click_drag(slots["MASK"].get_center(), _pack_cell_center(Vector2i(3, 5)))
	_check("mask slot -> grid", equipment.is_free(Equipment.Slot.MASK)
		and pack.get_entry_at(Vector2i(3, 5)) != null
		and pack.get_entry_at(Vector2i(3, 5)).data == _mask)
	_click_drag(slots["HEAD"].get_center(), hand_center)
	_check("worn item refused by a hand", hands[0].is_free()
		and equipment.get_item(Equipment.Slot.HEAD) == _hood)

	_click_drag(_pack_cell_center(Vector2i(1, 0)), _hotbar_center(0))
	_check("grid -> hotbar link", hotbar.get_slot(0).entry == pack.get_entry_at(Vector2i(1, 0)))
	_click_drag(_pack_cell_center(Vector2i(1, 0)), hand_center)
	await _settle()
	_check("grid -> hand", hands[0].get_item_data() == ROCK)
	_check("hotbar link follows into hand", hotbar.get_slot(0).is_held())
	_click_drag(hand_center, _pack_cell_center(Vector2i(1, 0)))
	await _settle()
	_check("hand -> grid", hands[0].is_free() and pack.get_entry_at(Vector2i(1, 0)) != null)

	_panel._rotate(_pack_cell_center(Vector2i(0, 2)))
	_check("right-click turns in place", pack.get_entry_at(Vector2i(0, 2)).rotated)

	_fill_chest()
	_panel.open_container(_chest)
	await _settle()
	var chest_cell := _panel._grid_origin(InventoryPanel.Side.CONTAINER) + Vector2(10, 10)
	var before := _chest.get_entries().size()
	_click_drag(_pack_cell_center(Vector2i(5, 7)), chest_cell + Vector2(_panel._offset(5), 0))
	_check("grid -> container", _chest.get_entries().size() == before + 1)
	_click_drag(slots["HEAD"].get_center(), chest_cell + Vector2(0, _panel._offset(4)))
	_check("head slot -> container", equipment.is_free(Equipment.Slot.HEAD)
		and _chest.get_entries().any(func(e): return e.data == _hood))
	_click_drag(chest_cell + Vector2(_panel._offset(4), 0), _pack_cell_center(Vector2i(5, 7)))
	_check("container -> grid", pack.get_entry_at(Vector2i(5, 7)) != null)
	var hood_entry: InventoryEntry
	for entry in _chest.get_entries():
		if entry.data == _hood:
			hood_entry = entry
	_click_drag(
		chest_cell + Vector2(_panel._offset(hood_entry.origin.x), _panel._offset(hood_entry.origin.y)),
		slots["HEAD"].get_center()
	)
	_check("container -> head slot", equipment.get_item(Equipment.Slot.HEAD) == _hood)
	_panel._update_hover(slots["HEAD"].get_center(), true)
	_check("hover on worn slot finds its item", _panel._hover_data == _hood)
	get_tree().quit()


func _click_drag(from: Vector2, to: Vector2) -> void:
	_panel._begin_drag(from)
	_panel._update_drag(to)
	_panel._end_drag(to)


func _hotbar_center(index: int) -> Vector2:
	return _panel._hotbar_panel.slot_rect(index).get_center() - _panel.global_position


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


## Prints where everything ended up, so a run can be checked without watching it.
func _report() -> void:
	var equipment := _player.get_node("Equipment") as Equipment
	for slot in Equipment.Slot.values():
		var worn := equipment.get_item(slot)
		print("worn ", Equipment.Slot.keys()[slot], ": ", worn.display_name if worn else "-")
	for entry in _panel._inventory.get_entries():
		print("pack ", entry.origin, ": ", entry.data.display_name)


func _fill_pack() -> void:
	var pack: Inventory = _panel._inventory
	pack.add_at(ROCK, Vector2i(0, 0))
	pack.add_at(ROCK, Vector2i(1, 0))
	pack.add_at(_mask, Vector2i(2, 0))
	pack.add_at(_hood, Vector2i(4, 0))
	pack.add_at(BOX_SMALL, Vector2i(0, 2))
	pack.add_at(ROCK, Vector2i(5, 7))


func _fill_chest() -> void:
	_chest.add_at(BARREL, Vector2i(0, 0))
	_chest.add_at(ROCK, Vector2i(4, 0))
	_chest.add_at(HAMMER, Vector2i(3, 4))


func _hold_hammer() -> void:
	var hand: HandSlot = _panel._hands[1]
	_panel._interactor.spawn_into_hand(HAMMER, -1, hand)


## Puts items straight onto the player's loadout, where there is one.
func _wear(items: Array) -> void:
	var equipment := _player.get_node_or_null("Equipment")
	if equipment == null:
		return
	for data in items:
		equipment.equip(equipment.slot_for(data), data)


## The on-screen box of each worn slot by slot name, or empty on a build without them.
func _wear_slot_rects() -> Dictionary:
	var rects := {}
	var boxes = _panel.get("_wear_boxes")
	if boxes == null:
		return rects
	for slot in boxes:
		var box: Control = boxes[slot]
		var key := String(box.name).trim_suffix("Slot").to_upper()
		rects[key] = Rect2(box.global_position, box.size)
	return rects


func _pack_cell_center(cell: Vector2i) -> Vector2:
	var half := _panel.cell_size * 0.5
	return _panel._grid_origin(InventoryPanel.Side.PLAYER) + Vector2(
		_panel._offset(cell.x) + half, _panel._offset(cell.y) + half
	)


func _drag_from_pack(cell: Vector2i, to: Vector2) -> void:
	_panel._begin_drag(_pack_cell_center(cell))
	_panel._update_drag(to)
	_cursor.position = to
	_cursor.show()


## Presses at `from`, carries the item to `to` over `seconds`, and lets go there.
func _drag(from: Vector2, to: Vector2, seconds: float) -> void:
	_cursor.position = from
	_panel._begin_drag(from)
	var time := 0.0
	while time < seconds:
		await get_tree().process_frame
		time += get_process_delta_time()
		var t := smoothstep(0.0, 1.0, minf(time / seconds, 1.0))
		_cursor.position = from.lerp(to, t)
		_panel._update_drag(_cursor.position)
	await _wait(0.35)
	_panel._end_drag(to)


func _glide(to: Vector2, seconds: float) -> void:
	var from := _cursor.position
	var time := 0.0
	while time < seconds:
		await get_tree().process_frame
		time += get_process_delta_time()
		_cursor.position = from.lerp(to, smoothstep(0.0, 1.0, minf(time / seconds, 1.0)))


## A plain arrow drawn over everything, standing in for the mouse pointer.
func _make_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_cursor = Polygon2D.new()
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(0, 22), Vector2(6, 16), Vector2(10, 26),
		Vector2(14, 24), Vector2(10, 15), Vector2(17, 15),
	])
	_cursor.polygon = points
	_cursor.color = Color(0.96, 0.9, 0.76)
	var outline := Line2D.new()
	points.append(Vector2.ZERO)
	outline.points = points
	outline.width = 2.0
	outline.default_color = Color(0.03, 0.02, 0.04)
	_cursor.add_child(outline)
	_cursor.hide()
	layer.add_child(_cursor)


## Knocks some health off, so the header's bar has something to show.
func _hurt(amount: int) -> void:
	var health := _player.get_node("Health") as Health
	health.apply_damage(DamageInfo.new(amount))


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _save(shot_name: String) -> void:
	if not _only.is_empty() and not Array(_only).any(func(part): return part in shot_name):
		return
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
