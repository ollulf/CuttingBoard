class_name NpcBody
extends Node3D

## What an NPC needs from the body it wears, whatever shape that body is. Npc talks to
## its body only through these calls, so a non-human body (the Mask-Monger's) can stand
## in for HumanBody by extending this and overriding what it can do. The defaults are a
## body that does nothing: it neither flinches, wears a breakable mask, nor falls.

signal went_limp


## The character wearing this body: the scene it was placed in, or the body itself when
## it stands alone.
func get_actor() -> Node3D:
	return owner as Node3D if owner is Node3D else self


func is_limp() -> bool:
	return false


## The middle of the body, wherever it has fallen: what a death camera looks at.
func get_center() -> Vector3:
	return global_position + Vector3.UP


## How `info` shoves the whole character: a velocity, flat along the ground, for the
## character's own movement to add and then shed.
func get_knockback(_info: DamageInfo) -> Vector3:
	return Vector3.ZERO


## Rocks the body with a hit that did not kill.
func flinch(_info: DamageInfo) -> void:
	pass


## Lets the body fall, for good. `carried_velocity` is how the character was moving.
func go_limp(_info: DamageInfo = null, _carried_velocity := Vector3.ZERO) -> void:
	went_limp.emit()


## A blow that may land on a worn mask.
func hit_mask(_info: DamageInfo) -> void:
	pass
