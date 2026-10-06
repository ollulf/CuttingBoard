class_name MeleeAttack
extends Node

## Resolves a blow: raycasts forward from the node it sits under and damages whatever is
## within reach. On the player that node is the camera, and the blow is driven by
## ArmAnimator's hit signal rather than by the click, so the damage always lands on the
## frame the arm reaches out — retiming the animation retimes the hit. An NPC puts it
## under its eyes and calls strike() itself.

## How far a blow reaches, in metres. Shorter than the interaction ray on purpose: there
## should be a step you can pick something up from but not punch it from.
@export var reach := 1.6
@export var collision_mask := 1
## Damage of a bare-handed blow. An item in the hand hits for its own impact_damage
## instead — the same number that says how hard it hits when it is thrown.
@export_range(0, 999) var unarmed_damage := 8
## Impulse handed to a struck rigid body, so a punch visibly shoves a barrel about.
@export var knockback := 2.5
## Impulse a blow drives into a character, in newton-seconds per point of damage, so a
## hammer rocks a body further than a fist does. Carried on the hit as its knockback.
@export var knockback_per_damage := 0.8

## What the blow is aimed along: its position is where the swing starts, its -Z where it goes.
@onready var _aim: Node3D = get_parent()


## Strikes whatever is in front of the aim with what this hand is holding. A null hand is
## a bare fist.
func strike(hand: HandSlot) -> void:
	var hit := _cast()
	if hit.is_empty():
		return
	var target: Node3D = hit["collider"]
	var damage := _damage_for(hand)
	if damage <= 0:
		return
	var direction := -_aim.global_transform.basis.z

	var health := Health.find_in(target)
	if health:
		var info := DamageInfo.new(damage, get_owner())
		# Where the blow landed, not the victim's origin: a character's origin is at its
		# feet, and the damage number would come up out of the ground.
		info.position = hit["position"]
		info.direction = direction
		info.knockback = damage * knockback_per_damage
		health.apply_damage(info)
	else:
		# Nothing alive to hurt, so the blow wears the object down instead. That is what
		# lets a fist break a crate without crates needing hit points of their own.
		var destructible := target.get_node_or_null("Destructible") as Destructible
		if destructible:
			destructible.damage(damage)

	var body := target as RigidBody3D
	if body:
		body.apply_central_impulse(direction * knockback)
	# A fallen body's limbs are physical too, so a corpse can be shoved about like a
	# barrel.
	var bone := target as PhysicalBone3D
	if bone:
		bone.apply_impulse(direction * knockback, hit["position"] - bone.global_position)


## What this hand hits for: the held item's own impact damage, or a bare fist. An item
## authored with no impact damage — something that is not a weapon — still lands the
## unarmed blow rather than a harmless one.
func _damage_for(hand: HandSlot) -> int:
	if hand == null:
		return unarmed_damage
	var held := hand.get_held()
	if held == null:
		return unarmed_damage
	var carryable := held.get_node_or_null("Carryable") as Carryable
	if carryable == null or carryable.impact_damage <= 0:
		return unarmed_damage
	return carryable.impact_damage


## What the blow meets, as the ray result — "collider" and the "position" it was struck
## at — or an empty dictionary when it meets nothing.
func _cast() -> Dictionary:
	var space_state := _aim.get_world_3d().direct_space_state
	var origin := _aim.global_position
	var end := origin - _aim.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
	# The ray starts inside the attacker's own capsule, so the body is excluded rather
	# than left to swallow every blow at point-blank range.
	var own_body := get_owner() as CollisionObject3D
	if own_body:
		query.exclude = [own_body.get_rid()]
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	return result if is_instance_valid(collider) else {}
