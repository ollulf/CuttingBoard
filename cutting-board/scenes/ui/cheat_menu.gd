class_name CheatMenu
extends Control

## Debug cheat menu: F1 (`toggle_cheats`) lists every item resource as a plain button,
## and a click puts a fresh one into the bound inventory. Items are found at runtime,
## so a new .tres in the items folder shows up without code changes.

const ITEMS_DIR := "res://resources/items/"

@onready var _list: VBoxContainer = %ItemList
@onready var _status: Label = %Status

var _inventory: Inventory


func _ready() -> void:
	hide()
	_build()


func bind(inventory: Inventory) -> void:
	_inventory = inventory


## Every ItemData under the items folder, sorted by file name. Exported builds list
## the files as "<name>.tres.remap", so the suffix is stripped before loading.
static func find_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var files := Array(DirAccess.get_files_at(ITEMS_DIR))
	files.sort()
	for file: String in files:
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var data := ResourceLoader.load(ITEMS_DIR + file) as ItemData
		if data:
			items.append(data)
	return items


func _build() -> void:
	for data in find_items():
		var button := Button.new()
		button.text = data.display_name if data.display_name != "" else data.resource_path.get_file()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(give.bind(data))
		_list.add_child(button)


## Puts a fresh copy (default durability) of the item into the inventory.
func give(data: ItemData) -> bool:
	if _inventory == null:
		return false
	var added := _inventory.add(data)
	_status.text = ("Added %s" % data.display_name) if added else "Inventory full"
	return added


## Handles its own key, like the inventory panel, so it still toggles while the mouse
## is free and the player controller ignores input.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_cheats"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_status.text = ""
	show()
	MouseGrab.release()


func close() -> void:
	if not visible:
		return
	hide()
	MouseGrab.capture()
