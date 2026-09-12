class_name HandSlot
extends Node3D

## One equip slot on the player's body, which is two things at once.
##
## It has an assignment — the item equipped to it in the equipment window — which is a
## lightweight ItemData record, the same kind of thing the inventory stores. And it has
## what the hand is physically holding, which is a live world Node3D with its own
## component state. Keeping those apart is what lets a hand carry a barrel around while
## a hammer stays equipped: the record waits in the slot, and drawing it spawns the real
## object into the hand. A held item can also be wound up for a throw.

signal item_held(item: Node3D)
signal item_released(item: Node3D)
signal charge_changed(ratio: float)
## Fired when the slot's assignment changes, including when a drawn item is lost.
signal equipped_changed(data: ItemData)

## Name shown for this slot in the equipment window.
@export var display_name := "Hand"
## What may be equipped into this slot from the inventory. Picking objects up out of
## the world is deliberately not restricted — a hand can still carry a barrel — this
## only gates what the equipment window accepts.
@export var equips: ItemData.Type = ItemData.Type.WEAPON

## Seconds of winding up to reach a full-power throw.
@export_range(0.1, 5.0) var charge_time := 0.9

## The item assigned to this slot: a record, not a live object.
var equipped: ItemData = null

var _held: Node3D = null
## Whether what the hand holds is this slot's assigned item, made real.
var _drawn := false
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


## Assigns an item to this slot. Nothing is spawned: the record simply waits here until
## it is drawn.
func equip(data: ItemData) -> bool:
	if data == null or equipped != null or data.item_type != equips:
		return false
	equipped = data
	equipped_changed.emit(equipped)
	return true


## Clears the assignment and hands the record back to the caller to store.
func unequip() -> ItemData:
	var data := equipped
	if data == null:
		return null
	equipped = null
	equipped_changed.emit(null)
	return data


## True while the assigned item is the very object this hand is holding.
func is_drawn() -> bool:
	return _drawn and not is_free()


## Takes hold of the assigned item, made real. The slot stays assigned while it is out,
## and forgets the assignment if that object ever leaves the hand by any other route —
## thrown or destroyed — because it is then loose in the world, not equipment.
func hold_drawn(item: Node3D) -> bool:
	if not hold(item):
		return false
	_drawn = true
	return true


## Puts a drawn item away, returning the world object for the caller to destroy. The
## assignment is deliberately kept: clearing _drawn first means the item leaves by the
## normal exit path without that path treating it as equipment lost to the world.
func sheathe() -> Node3D:
	if not is_drawn():
		return null
	_drawn = false
	return release()


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
	if _drawn:
		_drawn = false
		equipped = null
		equipped_changed.emit(null)
	item_released.emit(item)


func _stop_charge() -> void:
	_charging = false
	_charge = 0.0
	charge_changed.emit(0.0)
