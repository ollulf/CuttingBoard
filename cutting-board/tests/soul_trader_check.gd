extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const TRADER := preload("res://scenes/characters/soul_trader_npc.tscn")
const FLASK := preload("res://resources/items/soul_bottle.tres")
const ROCK := preload("res://resources/items/rock.tres")
const GLUE := preload("res://resources/items/wood_glue.tres")
const SICKLE := preload("res://resources/items/rocker_sickle.tres")

var _failures := 0
var _panel: InventoryPanel


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var level := LEVEL.instantiate()
	add_child(level)
	_panel = level.find_child("InventoryPanel", true, false) as InventoryPanel
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var pack: Inventory = _panel._inventory
	for entry in pack.get_entries().duplicate():
		pack.remove(entry)
	var interactor := get_tree().root.find_child("Interactor", true, false) as Interactor
	var camera := interactor.get_parent() as Camera3D

	var trader_body := TRADER.instantiate() as Node3D
	add_child(trader_body)
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	trader_body.global_position = camera.global_position + forward * 1.6 - Vector3(0, 1.5, 0)
	trader_body.look_at(trader_body.global_position + forward, Vector3.UP)
	var trader := Usable.find_in(trader_body) as Trader
	await _physics(4)
	_check("trader is hovered", interactor.get_hovered() == trader_body)
	_check("prompt offers Trade", trader.get_prompt(interactor.get_owner()) == "Trade")
	_check("stock is filled from the offers", trader.get_stock().get_entries().size() == 11)
	_check("stock is not lootable as a container", interactor.get_hovered_container() == null)
	interactor.interact(pack)
	await _frames(3)
	_check("E opens the trade screen", _panel.visible and _panel.is_trading())
	_check("stock grid shows priced tiles", _price_badges() == trader.get_stock().get_entries().size())

	var stock := trader.get_stock()
	var glue := _find(stock, GLUE)
	var glue_price := trader.price_of(glue)
	for i in glue_price - 1:
		pack.add(FLASK)
	await _frames(2)
	_double_click(InventoryPanel.Side.CONTAINER, glue.origin)
	await _frames(2)
	_check("can't buy without enough flasks",
		_find(pack, GLUE) == null and trader.count_currency(pack) == glue_price - 1
		and stock.get_entries().has(glue))

	pack.add(FLASK)
	pack.add(FLASK)
	await _frames(2)
	_double_click(InventoryPanel.Side.CONTAINER, glue.origin)
	await _frames(2)
	_check("buying adds the item", _find(pack, GLUE) != null)
	_check("buying takes the price in flasks", trader.count_currency(pack) == 1)
	_check("bought item leaves the stock", not stock.get_entries().has(glue))

	var count_before := stock.get_entries().size()
	_double_click(InventoryPanel.Side.PLAYER, _find(pack, GLUE).origin)
	_double_click(InventoryPanel.Side.PLAYER, _find(pack, FLASK).origin)
	await _frames(2)
	_check("double-click can't sell", stock.get_entries().size() == count_before
		and _find(pack, GLUE) != null and trader.count_currency(pack) == 1)
	var sold := _drag(InventoryPanel.Side.PLAYER, _find(pack, GLUE).origin,
		InventoryPanel.Side.CONTAINER, Vector2i(7, 5))
	await _frames(2)
	_check("drag can't sell", stock.get_entries().size() == count_before
		and _find(pack, GLUE) != null and trader.count_currency(pack) == 1)
	_check("no drag is left running", not _panel._is_dragging() and sold)

	for entry in pack.get_entries().duplicate():
		pack.remove(entry)
	for i in 4:
		pack.add_at(FLASK, [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 2)][i])
	while pack.add(ROCK):
		pass
	var sickle := _find(stock, SICKLE)
	await _frames(2)
	var size_before := pack.get_entries().size()
	_double_click(InventoryPanel.Side.CONTAINER, sickle.origin)
	await _frames(2)
	_check("can't buy without room", _find(pack, SICKLE) == null
		and trader.count_currency(pack) == 4 and pack.get_entries().size() == size_before
		and stock.get_entries().has(sickle))

	for entry in pack.get_entries().duplicate():
		pack.remove(entry)
	for i in 4:
		pack.add(FLASK)
	await _frames(2)
	_drag(InventoryPanel.Side.CONTAINER, sickle.origin, InventoryPanel.Side.PLAYER, Vector2i(2, 4))
	await _frames(2)
	_check("drag buys", _find(pack, SICKLE) != null and trader.count_currency(pack) == 0
		and not stock.get_entries().has(sickle))

	_panel.close()
	await _frames(2)
	_check("closing ends the trade", not _panel.is_trading())

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _price_badges() -> int:
	var count := 0
	for child in _panel._container_grid.get_children():
		if child.get_node_or_null("PriceBadge"):
			count += 1
	return count


func _find(inventory: Inventory, data: ItemData) -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data == data:
			return entry
	return null


func _cell_pos(side: int, cell: Vector2i) -> Vector2:
	var half := _panel.cell_size * 0.5
	return _panel._grid_origin(side) + Vector2(
		_panel._offset(cell.x) + half, _panel._offset(cell.y) + half
	)


func _double_click(side: int, cell: Vector2i) -> void:
	var pos := _cell_pos(side, cell)
	for second in [false, true]:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.double_click = second and pressed
			event.position = pos
			_panel._gui_input(event)


func _drag(from_side: int, from_cell: Vector2i, to_side: int, to_cell: Vector2i) -> bool:
	var start := _cell_pos(from_side, from_cell)
	var end := _cell_pos(to_side, to_cell)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	_panel._gui_input(press)
	for t in [0.3, 0.7, 1.0]:
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(end, t)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_panel._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end
	_panel._gui_input(release)
	return true


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
