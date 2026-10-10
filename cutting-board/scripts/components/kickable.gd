class_name Kickable
extends Node

## Marks the prop it sits under as something the player's Kick can target. Only props
## with this child are kicked (NPCs are kicked without one); see kick.gd.

## Scales the push a kick gives this prop, so a heavy thing meant to roll can take more
## than its mass alone would allow.
@export_range(0.0, 4.0, 0.05) var force_multiplier := 1.0
## Whether the boot itself wears the prop down by the kick's damage. Off for a prop meant
## to be kicked about, like a barrel: it wears only from what it slams into (ImpactDamage).
@export var kick_wears := true


## The Kickable under `node`, or null.
static func find_in(node: Node) -> Kickable:
	return node.get_node_or_null("Kickable") as Kickable if node else null
