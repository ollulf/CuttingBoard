class_name HumanBody
extends NpcBody

signal mask_damaged(durability: int)
signal mask_broken

@export var material: Material:
	set(value):
		material = value
		if is_node_ready():
			_apply_material()
@export var mask: MaskData:
	set(value):
		if value == mask:
			return
		mask = value
		if is_node_ready() and not _limp:
			_put_on_mask()
@export var mask_offset := Vector3(0.0, 0.13, -0.135)
@export_range(0.0, 1.0) var mask_pop_chance := 0.7
@export var mask_pop_impulse := 0.6
@export var mask_clear_time := 0.5
@export var head_hit_height := 0.0
@export var mask_break_sound: SoundBank = preload("res://resources/audio/break_wood.tres")
@export var mask_break_effect: PackedScene = preload("res://scenes/vfx/break_burst.tscn")
@export var shattered_mask: ItemData = preload("res://resources/items/shattered_mask.tres")
@export var npc_mask_wear := false
@export var head_hit_mask_wear := 2.0
@export_range(0.0, 1.0) var mask_shatter_chance := 0.75
@export var damaged_mask_left := Vector2(0.1, 0.25)
@export var impulse_scale := 2.5
@export var max_impulse := 60.0
@export var knockback_scale := 3.0

@export var animated := false:
	set(value):
		animated = value
		if is_node_ready() and not _limp and not physical_bones.is_simulating_physics():
			_settle_physical_bones()

@export_group("Flinch")
@export var anchor_bone := &"Hips"
@export_range(0.0, 1.0) var flinch_influence := 0.9
@export var flinch_recovery := 0.55
@export var flinch_linear_damp := 5.0
@export var flinch_angular_damp := 7.0
@export var flinch_gravity_scale := 0.0

@onready var skeleton: Skeleton3D = %Skeleton
@onready var mesh: MeshInstance3D = %Mesh
@onready var physical_bones: PhysicalBoneSimulator3D = %PhysicalBones

var _bones: Array[PhysicalBone3D] = []
var _half_lengths := {}
var _authored := {}
var _limp := false
var _flinch: Tween
var _face: Node3D
var _face_entry: InventoryEntry
var _face_inventory: Inventory
var mask_rng := RandomNumberGenerator.new()
var _dead_mask: ItemData
var _dead_durability := -1

var mask_durability := 0:
	set(value):
		mask_durability = value
		_show_wear()


func _ready() -> void:
	for child in physical_bones.get_children():
		var bone := child as PhysicalBone3D
		if bone == null:
			continue
		_bones.append(bone)
		_half_lengths[bone] = _half_length_of(bone)
		_authored[bone] = [bone.gravity_scale, bone.linear_damp, bone.angular_damp]
	for i in _bones.size():
		for j in range(i + 1, _bones.size()):
			_bones[i].add_collision_exception_with(_bones[j])
	var actor := get_actor() as CollisionObject3D
	if actor and actor != self:
		physical_bones.physical_bones_add_collision_exception(actor.get_rid())
	_settle_physical_bones()
	_apply_material()
	_put_on_mask()


func is_limp() -> bool:
	return _limp


func get_center() -> Vector3:
	var middle := _find_bone(&"Spine")
	return middle.global_position if middle else global_position + Vector3.UP


func get_bone_tail(bone_name: StringName) -> Vector3:
	var bone := _find_bone(bone_name)
	return bone.body_offset.origin * 2.0 if bone else Vector3.ZERO


func get_impulse(info: DamageInfo) -> Vector3:
	if info == null:
		return Vector3.ZERO
	return (info.get_impulse() * impulse_scale).limit_length(max_impulse)


func get_knockback(info: DamageInfo) -> Vector3:
	var impulse := get_impulse(info)
	impulse.y = 0.0
	return impulse * knockback_scale / maxf(get_total_mass(), 1.0)


func get_total_mass() -> float:
	var total := 0.0
	for bone in _bones:
		total += bone.mass
	return total


func flinch(info: DamageInfo) -> void:
	if _limp or info == null:
		return
	var impulse := get_impulse(info)
	if impulse.is_zero_approx():
		return
	var flinching: Array[PhysicalBone3D] = []
	var names: Array[StringName] = []
	for bone in _bones:
		if bone.bone_name != String(anchor_bone):
			flinching.append(bone)
			names.append(StringName(bone.bone_name))
	if flinching.is_empty():
		return
	if not physical_bones.is_simulating_physics():
		for bone in flinching:
			bone.gravity_scale = flinch_gravity_scale
			bone.linear_damp = flinch_linear_damp
			bone.angular_damp = flinch_angular_damp
		physical_bones.influence = 0.0
		physical_bones.active = true
		physical_bones.physical_bones_start_simulation(names)
	_push(_nearest_bone(info.position, flinching), impulse, info.position)

	if _flinch:
		_flinch.kill()
	_flinch = create_tween()
	_flinch.tween_property(physical_bones, "influence", flinch_influence, 0.05)
	_flinch.tween_property(physical_bones, "influence", 0.0, flinch_recovery).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_flinch.tween_callback(_end_flinch)


func go_limp(info: DamageInfo = null, carried_velocity := Vector3.ZERO) -> void:
	if _limp:
		return
	_limp = true
	if _flinch:
		_flinch.kill()
		_flinch = null
	for bone in _bones:
		_restore_authored(bone)
	physical_bones.active = true
	physical_bones.physical_bones_start_simulation()
	var blend := create_tween()
	blend.tween_property(physical_bones, "influence", 1.0, 0.08)
	for bone in _bones:
		bone.linear_velocity += carried_velocity
	if info:
		var impulse := get_impulse(info)
		_push(_nearest_bone(info.position, _bones), impulse, info.position)
	_dead_mask = mask
	_dead_durability = mask_durability
	if _face and npc_mask_wear and mask:
		_roll_mask_on_death()
	if _face:
		if randf() < mask_pop_chance or not _leave_mask_on():
			_knock_off_mask.call_deferred(_face, info, carried_velocity)
			_face = null
	went_limp.emit()


func _end_flinch() -> void:
	_flinch = null
	if _limp:
		return
	physical_bones.physical_bones_stop_simulation()
	_settle_physical_bones()
	for bone in _bones:
		_restore_authored(bone)


func _settle_physical_bones() -> void:
	physical_bones.influence = 0.0
	physical_bones.active = animated


func _restore_authored(bone: PhysicalBone3D) -> void:
	var authored: Array = _authored[bone]
	bone.gravity_scale = authored[0]
	bone.linear_damp = authored[1]
	bone.angular_damp = authored[2]


func _push(bone: PhysicalBone3D, impulse: Vector3, at: Vector3) -> void:
	if bone == null or impulse.is_zero_approx():
		return
	if at.is_zero_approx():
		bone.apply_central_impulse(impulse)
	else:
		var offset := (at - bone.global_position).limit_length(_half_lengths[bone] + 0.1)
		bone.apply_impulse(impulse, offset)


func _nearest_bone(point: Vector3, candidates: Array[PhysicalBone3D]) -> PhysicalBone3D:
	if point.is_zero_approx():
		var chest := _find_bone(&"Chest")
		return chest if chest in candidates else candidates.front()
	var nearest: PhysicalBone3D = null
	var nearest_distance := INF
	for bone in candidates:
		var axis := bone.global_basis.y.normalized()
		var half: float = _half_lengths[bone]
		var along := clampf((point - bone.global_position).dot(axis), -half, half)
		var distance := point.distance_to(bone.global_position + axis * along)
		if distance < nearest_distance:
			nearest = bone
			nearest_distance = distance
	return nearest


func _find_bone(bone_name: StringName) -> PhysicalBone3D:
	for bone in _bones:
		if bone.bone_name == String(bone_name):
			return bone
	return null


func _half_length_of(bone: PhysicalBone3D) -> float:
	for child in bone.get_children():
		var shape := (child as CollisionShape3D).shape if child is CollisionShape3D else null
		if shape is CapsuleShape3D:
			var capsule := shape as CapsuleShape3D
			return maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		if shape is BoxShape3D:
			return (shape as BoxShape3D).size.y * 0.5
	return 0.0


func _apply_material() -> void:
	if mesh:
		mesh.material_override = material


func _put_on_mask() -> void:
	if _face:
		_face.queue_free()
		_face = null
	if mask == null or mask.worn_scene == null:
		return
	var attachment := skeleton.get_node_or_null("HeadAttachment") as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = "HeadAttachment"
		attachment.bone_name = "Head"
		skeleton.add_child(attachment)
	_face = mask.worn_scene.instantiate() as Node3D
	_face.position = mask_offset
	attachment.add_child(_face)
	mask_durability = mask.durability


func stick_point(point: Vector3, part: Node) -> Node3D:
	var bone := part as PhysicalBone3D
	if bone == null or not bone in _bones:
		if _bones.is_empty():
			return null
		bone = _nearest_bone(point, _bones)
	var attachment_name: String = "Stuck" + bone.bone_name
	var attachment := skeleton.get_node_or_null(attachment_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		attachment.bone_name = bone.bone_name
		skeleton.add_child(attachment)
	return attachment


func is_head_hit(point: Vector3) -> bool:
	var head := skeleton.find_bone("Head")
	if point.is_zero_approx() or head < 0:
		return false
	var frame := skeleton.global_transform * skeleton.get_bone_global_pose(head)
	return (frame.affine_inverse() * point).y >= head_hit_height


func hit_mask(info: DamageInfo) -> void:
	if _limp or _face == null or info == null or info.amount <= 0 or mask.durability <= 0:
		return
	var wear := info.amount
	if is_head_hit(info.position):
		if npc_mask_wear:
			wear = roundi(info.amount * head_hit_mask_wear)
	elif not npc_mask_wear:
		return
	var health := Health.find_in(get_actor())
	if npc_mask_wear and health and not health.is_alive():
		return
	mask_durability = maxi(mask_durability - wear, 0)
	mask_damaged.emit(mask_durability)
	if mask_durability == 0:
		_break_mask()


func break_mask() -> void:
	if _face and not _limp:
		_break_mask()


func _break_mask() -> void:
	var face := _face
	_face = null
	Sfx.play_at(mask_break_sound, face.global_position)
	var camera := get_viewport().get_camera_3d()
	var from_inside := camera != null and get_actor().is_ancestor_of(camera)
	if mask_break_effect and not from_inside:
		var burst := mask_break_effect.instantiate() as Node3D
		burst.top_level = true
		if burst is BreakBurst:
			(burst as BreakBurst).setup(face, global_position.y)
		else:
			burst.position = face.global_position
		var tree := get_tree()
		(tree.current_scene if tree.current_scene else tree.root).add_child(burst)
	_drop_shattered.call_deferred(face.global_transform)
	face.queue_free()
	mask = null
	mask_broken.emit()


func _drop_shattered(at: Transform3D) -> void:
	var level := get_actor().get_parent()
	var loose := shattered_mask.spawn() as RigidBody3D if shattered_mask else null
	if level == null or loose == null:
		return
	level.add_child(loose)
	loose.global_transform = at
	keep_clear_of(loose, get_actor(), mask_clear_time)


func _roll_mask_on_death() -> void:
	var fate := MaskWear.roll_on_death(mask_rng, mask, mask_durability, mask_shatter_chance,
			damaged_mask_left, shattered_mask)
	_dead_mask = fate[0]
	_dead_durability = fate[1]
	mask_durability = 0 if _dead_durability < 0 else _dead_durability


func _show_wear() -> void:
	if _face == null or mask == null or mask.durability <= 0:
		return
	MaskWear.show_crack(_face, float(mask_durability) / mask.durability)


func _knock_off_mask(face: Node3D, info: DamageInfo, carried_velocity: Vector3) -> void:
	var at := face.global_transform
	face.queue_free()
	var level := get_actor().get_parent()
	var loose := _dead_mask.spawn() as RigidBody3D if _dead_mask else null
	if level == null or loose == null:
		return
	level.add_child(loose)
	Destructible.write(loose, _dead_durability)
	loose.global_transform = at
	keep_clear_of(loose, get_actor(), mask_clear_time)
	var push := get_impulse(info).normalized() if info else Vector3.ZERO
	var away := -at.basis.z
	loose.linear_velocity = carried_velocity
	loose.apply_central_impulse((push + away * 0.6 + Vector3.UP * 0.8).normalized() * mask_pop_impulse)
	loose.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02)


func _leave_mask_on() -> bool:
	var inventory := get_actor().get_node_or_null("Inventory") as Inventory
	if inventory == null or _dead_mask == null:
		return false
	_face_entry = inventory.store(_dead_mask, _dead_durability)
	if _face_entry == null:
		return false
	_face_inventory = inventory
	inventory.changed.connect(_on_face_inventory_changed)
	return true


func _on_face_inventory_changed() -> void:
	if _face_inventory.get_entries().has(_face_entry):
		return
	_face_inventory.changed.disconnect(_on_face_inventory_changed)
	_face_inventory = null
	_face_entry = null
	if _face:
		_face.queue_free()
		_face = null


static func colliders_of(actor: Node) -> Array[CollisionObject3D]:
	var colliders: Array[CollisionObject3D] = []
	if actor == null or not is_instance_valid(actor):
		return colliders
	if actor is CollisionObject3D:
		colliders.append(actor)
	for bone in actor.find_children("*", "PhysicalBone3D", true, false):
		colliders.append(bone)
	return colliders


static func keep_clear_of(item: PhysicsBody3D, actor: Node, seconds := 0.3) -> void:
	var own_ids: Array[int] = []
	for collider in colliders_of(actor):
		item.add_collision_exception_with(collider)
		own_ids.append(collider.get_instance_id())
	var item_id := item.get_instance_id()
	item.get_tree().create_timer(seconds).timeout.connect(
		func() -> void:
			var thrown := instance_from_id(item_id) as PhysicsBody3D
			if thrown == null:
				return
			for id in own_ids:
				var collider := instance_from_id(id) as Node
				if collider:
					thrown.remove_collision_exception_with(collider)
	)


static func actor_of(node: Node) -> Node:
	if not node is PhysicalBone3D:
		return node
	var at := node.get_parent()
	while at:
		if at is NpcBody:
			return (at as NpcBody).get_actor()
		at = at.get_parent()
	return node
