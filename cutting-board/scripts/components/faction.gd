class_name Faction
extends Node

## Says which side its owner is on. Anything carrying one is an actor: something NPCs
## look out for and form a view of. The player carries one too, so to an NPC the player
## is just another actor of the "player" faction.
##
## A mask is the faction in this world: when the owner has an Equipment beside this node,
## the face it wears in the Mask slot decides its side, so whoever wears a bandit's face
## is taken for a bandit. A bare face, or a mask with no faction, falls back to the
## owner's own side. NPCs carry no Equipment yet, so they keep their scene's side.

## Group every actor is put in, which is how Sight finds what there is to look at
## without searching the whole tree.
const GROUP := &"actors"

## The side its owner is on right now: the worn mask's faction, or own_data without one.
## Set it in the scene to the owner's own side; from there it follows the mask.
@export var data: FactionData

## The owner's own side, taken from `data` when the node is ready: what is left once no
## mask says otherwise.
var own_data: FactionData
var _equipment: Equipment


func _ready() -> void:
	get_parent().add_to_group(GROUP)
	own_data = data
	_equipment = get_parent().get_node_or_null("Equipment") as Equipment
	if _equipment:
		_equipment.changed.connect(_follow_mask)
		_follow_mask()


## Whether this side treats `other`'s side as an enemy. Something with no faction is
## never an enemy — a barrel is not worth running from.
func is_hostile_to(other: Node) -> bool:
	var theirs := find_in(other)
	return data != null and theirs != null and data.is_hostile_to(theirs.data)


static func find_in(node: Node) -> Faction:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Faction") as Faction


## Takes on the side of whatever is in the Mask slot. Runs on every Equipment change —
## a mask put on, taken off, or broken off the face.
func _follow_mask() -> void:
	var mask := _equipment.get_item(Equipment.Slot.MASK) as MaskData
	data = mask.faction if mask and mask.faction else own_data
