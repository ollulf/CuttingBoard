class_name HandSlot
extends Node3D

signal item_held(item: Node3D)
signal item_released(item: Node3D)
signal charge_changed(ratio: float)

const RELEASED_BY_META := &"released_by"
const RELEASED_AT_META := &"released_at"

@export var display_name := "Hand"

@export_range(0.1, 5.0) var charge_time := 0.9

var _held: Node3D = null
var _charging := false
var _charge := 0.0


func _process(delta: float) -> void:
	if not _charging:
		return
	_charge = minf(_charge + delta, charge_time)
	charge_changed.emit(get_charge_ratio())


func is_free() -> bool:
	return _held == null


func get_held() -> Node3D:
	return _held


func get_carryable() -> Carryable:
	if _held == null:
		return null
	return _held.get_node_or_null("Carryable") as Carryable


func get_item_data() -> ItemData:
	var carryable := get_carryable()
	return carryable.item_data if carryable else null


func get_durability() -> int:
	return Destructible.read(_held) if _held else -1


func hold(item: Node3D) -> bool:
	if not is_free() or item == null:
		return false
	_held = item
	item.reparent(self, false)
	item.transform = Transform3D.IDENTITY
	item.tree_exiting.connect(_clear_held)
	item_held.emit(item)
	return true


func release() -> Node3D:
	var item := _held
	if item == null:
		return null
	_clear_held()
	return item


func is_charging() -> bool:
	return _charging


func begin_charge() -> void:
	if is_free():
		return
	_charging = true
	_charge = 0.0


func end_charge() -> float:
	var ratio := get_charge_ratio()
	_stop_charge()
	return ratio


func get_charge_ratio() -> float:
	return _charge / charge_time


func _clear_held() -> void:
	if _held == null:
		return
	var item := _held
	if item.tree_exiting.is_connected(_clear_held):
		item.tree_exiting.disconnect(_clear_held)
	_held = null
	_stop_charge()
	if owner:
		item.set_meta(RELEASED_BY_META, owner)
		item.set_meta(RELEASED_AT_META, Time.get_ticks_msec() / 1000.0)
	item_released.emit(item)


func _stop_charge() -> void:
	_charging = false
	_charge = 0.0
	charge_changed.emit(0.0)
