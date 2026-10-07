extends Node

## Headless checks for the looting view of the inventory screen: with a container open
## the equipment frame is hidden and only the two grids show, the plain inventory still
## shows it, and a double-click moves an item between the player's grid and the open
## container (keeping its wear), refuses when the other side is full, and does nothing
## with no container open or on an empty square. Clicks are fed to the panel as real
## double-click mouse events. Prints PASS/FAIL per check and quits with the number of
## failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/loot_transfer_check.tscn

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const HAMMER := preload("res://resources/items/hammer.tres")

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
	var equip_frame := _panel.get_node("%EquipFrame") as Control

	_panel.open()
	await _frames(3)
	_check("plain inventory shows the equipment", equip_frame.visible)
	_check("plain inventory hides the container panel", not _panel._container_frame.visible)
	pack.add_at(HAMMER, Vector2i(0, 0), 7)
	await _frames(2)
	_double_click(InventoryPanel.Side.PLAYER, Vector2i(0, 0))
	await _frames(2)
	_check("double-click without a container does nothing", pack.get_entries().size() == 1)
	_panel.close()

	var chest := Inventory.new()
	chest.grid_size = Vector2i(3, 4)
	chest.display_name = "Chest"
	add_child(chest)
	_panel.open_container(chest)
	await _frames(3)
	_check("looting hides the equipment", not equip_frame.visible)
	_check("looting shows the container panel", _panel._container_frame.is_visible_in_tree())
	_check("hands are not hit-tested while hidden",
		_panel._hand_at(_panel._local_rect(_panel._hand_boxes[0]).get_center()) == null)

	_double_click(InventoryPanel.Side.PLAYER, Vector2i(0, 0))
	await _frames(2)
	_check("player -> container moves the hammer",
		pack.is_empty() and chest.get_entries().size() == 1)
	var moved := chest.get_entries()[0] if not chest.is_empty() else null
	_check("wear is kept", moved != null and moved.durability == 7)
	_check("no drag is left running", not _panel._is_dragging())

	_double_click(InventoryPanel.Side.CONTAINER, moved.origin if moved else Vector2i.ZERO)
	await _frames(2)
	_check("container -> player moves it back",
		chest.is_empty() and pack.get_entries().size() == 1)

	# Fill the chest, then try to send one more rock across.
	while chest.add(ROCK):
		pass
	pack.add(ROCK)
	await _frames(2)
	var rock := _find(pack, ROCK)
	var before := pack.get_entries().size()
	_double_click(InventoryPanel.Side.PLAYER, rock.origin)
	await _frames(2)
	_check("full container refuses", pack.get_entries().size() == before and _find(pack, ROCK) == rock)

	# And the other way: a packed player grid refuses the chest's rock.
	while pack.add(ROCK):
		pass
	var chest_count := chest.get_entries().size()
	_double_click(InventoryPanel.Side.CONTAINER, chest.get_entries()[0].origin)
	await _frames(2)
	_check("full player grid refuses", chest.get_entries().size() == chest_count)

	_panel.close()
	await _frames(2)
	_panel.open()
	await _frames(2)
	_check("equipment is back on the plain inventory", equip_frame.visible)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _find(inventory: Inventory, data: ItemData) -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data == data:
			return entry
	return null


## Two left presses on a grid square, the second flagged as a double-click, as the OS
## delivers them.
func _double_click(side: int, cell: Vector2i) -> void:
	var half := _panel.cell_size * 0.5
	var pos := _panel._grid_origin(side) + Vector2(
		_panel._offset(cell.x) + half, _panel._offset(cell.y) + half
	)
	for second in [false, true]:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.double_click = second and pressed
			event.position = pos
			_panel._gui_input(event)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
