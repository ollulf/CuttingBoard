class_name CheatMenu
extends Control

const ITEMS_DIR := "res://resources/items/"
const TYPE_ORDER: Array[ItemData.Type] = [
	ItemData.Type.WEAPON,
	ItemData.Type.MASK,
	ItemData.Type.HEAD,
	ItemData.Type.BODY,
	ItemData.Type.PACK,
	ItemData.Type.MISC,
]
const TYPE_HEADERS := {
	ItemData.Type.WEAPON: "Weapons",
	ItemData.Type.MASK: "Masks",
	ItemData.Type.HEAD: "Head",
	ItemData.Type.BODY: "Body",
	ItemData.Type.PACK: "Packs",
	ItemData.Type.MISC: "Misc",
}
const HEADER_GROUP := &"cheat_menu_headers"

@onready var _list: VBoxContainer = %ItemList
@onready var _status: Label = %Status
@onready var _infinite_health: CheckButton = %InfiniteHealth
@onready var _no_aggro: CheckButton = %NoAggro

var _inventory: Inventory


func _ready() -> void:
	hide()
	_infinite_health.set_pressed_no_signal(Cheats.infinite_health)
	_no_aggro.set_pressed_no_signal(Cheats.no_aggro)
	_infinite_health.toggled.connect(set_infinite_health)
	_no_aggro.toggled.connect(set_no_aggro)
	_build()


func bind(inventory: Inventory) -> void:
	_inventory = inventory


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


static func label_for(data: ItemData) -> String:
	return data.display_name if data.display_name != "" else data.resource_path.get_file()


static func type_rank(data: ItemData) -> int:
	var rank := TYPE_ORDER.find(data.item_type)
	return rank if rank >= 0 else TYPE_ORDER.size()


static func sorted_items() -> Array[ItemData]:
	var items := find_items()
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var rank_a := type_rank(a)
		var rank_b := type_rank(b)
		if rank_a != rank_b:
			return rank_a < rank_b
		return label_for(a).naturalnocasecmp_to(label_for(b)) < 0)
	return items


func _build() -> void:
	var current_rank := -1
	for data in sorted_items():
		var rank := type_rank(data)
		if rank != current_rank:
			current_rank = rank
			var header := Label.new()
			header.text = TYPE_HEADERS.get(data.item_type, "Other")
			header.modulate = Color(0.859, 0.678, 0.361)
			header.add_to_group(HEADER_GROUP)
			_list.add_child(header)
		var button := Button.new()
		button.text = label_for(data)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(give.bind(data))
		_list.add_child(button)


func give(data: ItemData) -> bool:
	if _inventory == null:
		return false
	var added := _inventory.add(data)
	_status.text = ("Added %s" % data.display_name) if added else "Inventory full"
	return added


func set_infinite_health(on: bool) -> void:
	Cheats.infinite_health = on
	_infinite_health.set_pressed_no_signal(on)
	_status.text = "Infinite health %s" % ("on" if on else "off")


func set_no_aggro(on: bool) -> void:
	Cheats.set_no_aggro(on, get_tree())
	_no_aggro.set_pressed_no_signal(on)
	_status.text = "No aggro %s" % ("on" if on else "off")


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
