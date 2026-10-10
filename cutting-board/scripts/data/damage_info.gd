class_name DamageInfo
extends RefCounted

enum Type { BLUNT, SLASH, PIERCE, FIRE }

var amount: int
var type: Type
var source: Node
var position: Vector3
var direction: Vector3
var knockback := 0.0
var silent := false


func _init(p_amount: int, p_source: Node = null, p_type: Type = Type.BLUNT) -> void:
	amount = p_amount
	source = p_source
	type = p_type


func get_impulse() -> Vector3:
	return direction.normalized() * knockback


func get_attacker(thrown_memory := 4.0) -> Node3D:
	if source == null or not is_instance_valid(source):
		return null
	if source.has_meta(HandSlot.RELEASED_BY_META):
		var thrower: Variant = source.get_meta(HandSlot.RELEASED_BY_META)
		var released_at: float = source.get_meta(HandSlot.RELEASED_AT_META, -INF)
		if is_instance_valid(thrower) and Time.get_ticks_msec() / 1000.0 - released_at <= thrown_memory:
			return thrower as Node3D
	return source as Node3D
