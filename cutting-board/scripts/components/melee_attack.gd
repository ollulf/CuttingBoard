class_name MeleeAttack
extends Node

@export var reach := 1.6
@export var collision_mask := 1
@export_range(0, 999) var unarmed_damage := 8
@export var knockback := 2.5
@export var knockback_per_damage := 0.8

@export_group("Sounds")
@export var swing_sound: SoundBank = preload("res://resources/audio/swing.tres")
@export var hit_body_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
@export var hit_object_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export_group("")

@onready var _aim: Node3D = get_parent()


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
	if health and health == Health.find_in(get_owner()):
		return
	var weight := linear_to_db(clampf(damage / 15.0, 0.7, 1.15))
	Sfx.play_at(hit_body_sound if health else hit_object_sound, hit["position"], weight)
	if health:
		var info := DamageInfo.new(damage, get_owner())
		info.position = hit["position"]
		info.direction = direction
		info.knockback = damage * knockback_per_damage
		health.apply_damage(info)
	else:
		var destructible := target.get_node_or_null("Destructible") as Destructible
		if destructible:
			destructible.damage(damage)

	var body := target as RigidBody3D
	if body:
		body.apply_central_impulse(direction * knockback)
	var bone := target as PhysicalBone3D
	if bone:
		bone.apply_impulse(direction * knockback, hit["position"] - bone.global_position)
	_wear(hand)


func play_swing() -> void:
	Sfx.play_at(swing_sound, _aim.global_position)


func _wear(hand: HandSlot) -> void:
	var data := hand.get_item_data() if hand else null
	if data == null or data.wear_per_hit <= 0:
		return
	var destructible := hand.get_held().get_node_or_null("Destructible") as Destructible
	if destructible:
		destructible.damage(data.wear_per_hit, true)


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


func _cast() -> Dictionary:
	var space_state := _aim.get_world_3d().direct_space_state
	var origin := _aim.global_position
	var end := origin - _aim.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
	var exclude: Array[RID] = []
	for collider in HumanBody.colliders_of(get_owner()):
		exclude.append(collider.get_rid())
	query.exclude = exclude
	var result := space_state.intersect_ray(query)
	var collider := result.get("collider") as Node3D
	return result if is_instance_valid(collider) else {}
