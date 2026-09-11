class_name HandSlot
extends Node3D

## One equip slot on the player's body. A hand holds a single live world object — the
## actual Node3D, with its own component state — which is what makes it different from
## the inventory: the inventory stores lightweight ItemData records, a hand holds the
## real thing. A held item can also be wound up for a throw.

signal item_held(item: Node3D)
signal item_released(item: Node3D)
signal charge_changed(ratio: float)

## Seconds of winding up to reach a full-power throw.
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


func hold(item: Node3D) -> bool:
	if not is_free():
		return false
	_held = item
	item.reparent(self, false)
	item.transform = Transform3D.IDENTITY
	# Connect after reparenting: reparent itself emits tree_exiting, which would
	# otherwise immediately empty the slot we just filled.
	item.tree_exiting.connect(_clear_held)
	item_held.emit(item)
	return true


## Empties the slot and returns what was held; the caller decides where it goes next.
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


## Ends the wind-up and reports how far it got, as 0..1.
func end_charge() -> float:
	var ratio := get_charge_ratio()
	_stop_charge()
	return ratio


func get_charge_ratio() -> float:
	return _charge / charge_time


## The single exit path for a held item, whether it was thrown or destroyed out from
## under the slot, so item_released fires exactly once either way.
func _clear_held() -> void:
	if _held == null:
		return
	var item := _held
	if item.tree_exiting.is_connected(_clear_held):
		item.tree_exiting.disconnect(_clear_held)
	_held = null
	_stop_charge()
	item_released.emit(item)


func _stop_charge() -> void:
	_charging = false
	_charge = 0.0
	charge_changed.emit(0.0)
