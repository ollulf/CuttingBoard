class_name MaskData
extends ItemData

## A mask as an item: the record a villager's or a bandit's face becomes once it is off
## them, and what the player wears in the Mask slot. On top of what every item has, it
## knows the face it puts on a body and whose face that is.
##
## A mask is the faction in this world — whoever wears a bandit's face is taken for a
## bandit — but nothing reads `faction` yet. It is here so that wearing one can start to
## mean something without every mask having to be authored again.

## The face hung on the head of whoever wears this: a plain Node3D scene, facing -Z, with
## its origin at the middle of the face. HumanBody instances it; it has no physics or
## scripts of its own. Held as a scene, not a path — unlike world_scene_path, nothing in
## it points back at this record.
@export var worn_scene: PackedScene
## The faction this face belongs to.
@export var faction: FactionData


func _init() -> void:
	item_type = Type.MASK
