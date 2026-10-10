class_name Holster
extends Node

@export var sheathe_delay := 3.0
@export var draw_time := 0.25

@onready var _npc: Npc = owner
@onready var _body: NpcBody = %Body
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hip_right: HandSlot = %HipSlotRight
@onready var _hip_left: HandSlot = %HipSlotLeft

var _calm := 0.0
var _draw_left := -1.0


func _ready() -> void:
	_attach_to_hips()


func _physics_process(delta: float) -> void:
	if not _npc.health.is_alive():
		return
	if _npc.is_in_combat():
		_calm = 0.0
		if not is_holstered():
			_draw_left = -1.0
		elif _draw_left < 0.0:
			_draw_left = draw_time
		else:
			_draw_left -= delta
			if _draw_left <= 0.0:
				draw_now()
		return
	_draw_left = -1.0
	_calm += delta
	if _calm >= sheathe_delay:
		sheathe()


func is_holstered() -> bool:
	return not _hip_right.is_free() or not _hip_left.is_free()


func sheathe() -> void:
	for pair in _pairs():
		var hand: HandSlot = pair[0]
		var hip: HandSlot = pair[1]
		var held := hand.get_item_data()
		if held and held.is_weapon() and hip.is_free():
			var item := hand.release()
			hip.hold(item)
			_hang(item)


func draw_now() -> void:
	_draw_left = -1.0
	for pair in _pairs():
		var hand: HandSlot = pair[0]
		var hip: HandSlot = pair[1]
		if not hip.is_free() and hand.is_free():
			hand.hold(hip.release())


func get_slots() -> Array[HandSlot]:
	return [_hip_right, _hip_left]


func _hang(item: Node3D) -> void:
	var to_item := item.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in item.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := to_item * visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return
	var axis := bounds.get_longest_axis_index()
	var along := Vector3.ZERO
	along[axis] = 1.0 if bounds.get_center()[axis] >= 0.0 else -1.0
	item.transform = Transform3D(Basis(Quaternion(along, Vector3.UP)), Vector3.ZERO)


func _pairs() -> Array:
	return [[_hand_right, _hip_right], [_hand_left, _hip_left]]


func _attach_to_hips() -> void:
	var skeleton := _body.get("skeleton") as Skeleton3D
	if skeleton == null or skeleton.find_bone("Hips") < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HipAttachment"
	attachment.bone_name = "Hips"
	skeleton.add_child(attachment)
	var bone := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Hips"))
	for hip in get_slots():
		var offset := bone.affine_inverse() * hip.global_transform
		hip.reparent(attachment, false)
		hip.transform = offset
