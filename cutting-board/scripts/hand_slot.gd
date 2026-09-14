class_name HandSlot
extends Node3D

## One hand on the player's body. It holds a live world Node3D and nothing else.
##
## There is no record waiting in reserve here: a hand either has an object in it or is
## empty. Where an item lives while it is not being held is the inventory's business,
## and which item a number key reaches for is the hotbar's — keeping both of those out
## of the hand is what lets one path serve a barrel grabbed off the ground and a hammer
## pulled out of the bag. A held item can be wound up for a throw.

signal item_held(item: Node3D)
signal item_released(item: Node3D)
signal charge_changed(ratio: float)

## Name shown for this hand in the inventory screen and on the hotbar.
@export var display_name := "Hand"

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


func get_carryable() -> Carryable:
	if _held == null:
		return null
	return _held.get_node_or_null("Carryable") as Carryable


## The inventory record for what this hand is holding, or null when it is empty or has
## hold of something that never came from an item. This is what the hand offers the
## inventory screen: it is the same kind of record a grid square stores, so an item in
## the hand can be dragged into the bag exactly like one being moved between grids.
func get_item_data() -> ItemData:
	var carryable := get_carryable()
	return carryable.item_data if carryable else null


## What the held object has left, or -1 if it does not wear down. Read off the live
## object, since that is where damage has actually been landing.
func get_durability() -> int:
	return Destructible.read(_held) if _held else -1


func hold(item: Node3D) -> bool:
	if not is_free() or item == null:
		return false
	_held = item
	item.reparent(self, false)
	item.transform = Transform3D.IDENTITY
	# Connect after reparenting: reparent itself emits tree_exiting, which would
	# otherwise immediately empty the slot we just filled.
	item.tree_exiting.connect(_clear_held)
	item_held.emit(item)
	return true


## Empties the hand and returns what was held; the caller decides where it goes next.
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


## The single exit path for a held item, whether it was stowed, thrown or destroyed out
## from under the hand, so item_released fires exactly once either way.
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
