class_name Faction
extends Node

## Says which side its owner is on. Anything carrying one is an actor: something NPCs
## look out for and form a view of. The player carries one too, so to an NPC the player
## is just another actor of the "player" faction.

## Group every actor is put in, which is how Sight finds what there is to look at
## without searching the whole tree.
const GROUP := &"actors"

@export var data: FactionData


func _ready() -> void:
	get_parent().add_to_group(GROUP)


## Whether this side treats `other`'s side as an enemy. Something with no faction is
## never an enemy — a barrel is not worth running from.
func is_hostile_to(other: Node) -> bool:
	var theirs := find_in(other)
	return data != null and theirs != null and data.is_hostile_to(theirs.data)


static func find_in(node: Node) -> Faction:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Faction") as Faction
