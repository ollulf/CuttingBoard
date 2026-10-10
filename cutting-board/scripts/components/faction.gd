class_name Faction
extends Node

const GROUP := &"actors"

@export var data: FactionData

var own_data: FactionData
var _equipment: Equipment


func _ready() -> void:
	get_parent().add_to_group(GROUP)
	own_data = data
	_equipment = get_parent().get_node_or_null("Equipment") as Equipment
	if _equipment:
		_equipment.changed.connect(_follow_mask)
		_follow_mask()


func is_hostile_to(other: Node) -> bool:
	if Cheats.hides_from_enemies(other):
		return false
	var theirs := find_in(other)
	return data != null and theirs != null and data.is_hostile_to(theirs.data)


static func find_in(node: Node) -> Faction:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Faction") as Faction


func _follow_mask() -> void:
	var mask := _equipment.get_item(Equipment.Slot.MASK) as MaskData
	data = mask.faction if mask and mask.faction else own_data
