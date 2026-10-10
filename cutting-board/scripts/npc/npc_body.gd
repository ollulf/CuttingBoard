class_name NpcBody
extends Node3D

signal went_limp


func get_actor() -> Node3D:
	return owner as Node3D if owner is Node3D else self


func is_limp() -> bool:
	return false


func get_center() -> Vector3:
	return global_position + Vector3.UP


func get_knockback(_info: DamageInfo) -> Vector3:
	return Vector3.ZERO


func flinch(_info: DamageInfo) -> void:
	pass


func go_limp(_info: DamageInfo = null, _carried_velocity := Vector3.ZERO) -> void:
	went_limp.emit()


func stick_point(_point: Vector3, _part: Node) -> Node3D:
	return null


func hit_mask(_info: DamageInfo) -> void:
	pass
