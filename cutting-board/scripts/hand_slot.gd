class_name HandSlot
extends Node3D

## One equip slot on the player's body. A hand holds a single live world object — the
## actual Node3D, with its own component state — which is what makes it different from
## the inventory: the inventory stores lightweight ItemData records, a hand holds the
## real thing.

signal item_held(item: Node3D)
signal item_released(item: Node3D)

var _held: Node3D = null


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
	item_released.emit(item)
	return item


## Keeps the slot usable when the held item is destroyed out from under it.
func _clear_held() -> void:
	if _held == null:
		return
	if _held.tree_exiting.is_connected(_clear_held):
		_held.tree_exiting.disconnect(_clear_held)
	_held = null
