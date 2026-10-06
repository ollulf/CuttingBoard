class_name Usable
extends Node

## Lets an object respond to an "interact" action without being carried (levers, chests, campfires).
## Some things are used from the hand instead — a pot of glue — which held_verb opts into.

@export var uses_remaining := -1 ## -1 = infinite
## What a plain click does with this object while it is held, shown on the hand prompt
## ("Apply" reads "Apply Wood Glue"). Blank means it is not used from the hand at all, so
## a click with it swings or punches as before; that is every item until it opts in.
@export var held_verb := ""

signal used(by: Node)

## Asked before every use when set, with whoever is using it; returning false refuses the
## use and spends nothing — glue does nothing for someone who is not hurt.
var can_use := Callable()


## Returns whether the object was actually used.
func use(by: Node) -> bool:
	if uses_remaining == 0:
		return false
	if can_use.is_valid() and not can_use.call(by):
		return false
	if uses_remaining > 0:
		uses_remaining -= 1
	used.emit(by)
	return true


## What the interact prompt offers `by` when this object is under the crosshair ("Give
## mask"), or "" for no prompt. Plain Usables offer none; a trade like the Mask-Monger's
## overrides it.
func get_prompt(_by: Node) -> String:
	return ""


func is_used_in_hand() -> bool:
	return not held_verb.is_empty()


## The Usable on `node`, or null if it has none.
static func find_in(node: Node) -> Usable:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Usable") as Usable
