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

@export_group("Sounds")
## The arm cutting the air, played by play_swing() when the blow is thrown.
@export var swing_sound: SoundBank = preload("res://resources/audio/swing.tres")
## A blow landing on anything with Health, living or not.
@export var hit_body_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
## A blow landing on anything else: a crate, a wall, a dropped hammer.
@export var hit_object_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export_group("")

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
	# The ray already passes through the attacker's own body; this is the backstop for
	# any part of it that was missed, since a blow on yourself is never what was meant.
	if health and health == Health.find_in(get_owner()):
		return
	# A heavier blow lands louder: a hammer over a fist.
	var weight := linear_to_db(clampf(damage / 15.0, 0.7, 1.15))
	Sfx.play_at(hit_body_sound if health else hit_object_sound, hit["position"], weight)
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


## The whoosh of the blow being thrown, from where it starts. Separate from strike()
## because the swing is heard as the arm sets off and the hit only when it arrives.
func play_swing() -> void:
	Sfx.play_at(swing_sound, _aim.global_position)


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
	# The ray starts inside the attacker's own capsule and passes its own arms and
	# chest, whose physical bones follow the animated pose. All of them are excluded,
	# or they would swallow blows at point-blank range — or take them.
	var exclude: Array[RID] = []
	for collider in HumanBody.colliders_of(get_owner()):
		exclude.append(collider.get_rid())
	query.exclude = exclude
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	return result if is_instance_valid(collider) else {}
