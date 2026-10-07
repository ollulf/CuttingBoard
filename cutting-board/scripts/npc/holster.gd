class_name Holster
extends Node

## Puts an NPC's weapon away at its hip once it has been out of a fight for a while, and
## draws it back into the same hand when a fight starts. Only a weapon is put away: a
## lamp or anything else carried stays in the hand, and a bare-handed NPC has nothing to
## do here.
##
## The hips are HandSlots like the hands, so the item is the same live object the whole
## time — it keeps its wear, stays out of world physics (nothing bumps into it or picks
## it off the belt) and is let go of like a held item when the NPC dies. They ride on
## the body's Hips bone, so a holstered weapon sways with the walk.

## Seconds out of combat before the weapon goes back on the hip.
@export var sheathe_delay := 3.0
## Seconds from a fight starting to the weapon being back in hand. A blow thrown before
## then draws it at once, so the first swing is never bare-handed.
@export var draw_time := 0.25

@onready var _npc: Npc = owner
@onready var _body: NpcBody = %Body
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hip_right: HandSlot = %HipSlotRight
@onready var _hip_left: HandSlot = %HipSlotLeft

var _calm := 0.0
## Seconds left on a draw under way, below 0 when none is.
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


## Whether a weapon hangs at either hip.
func is_holstered() -> bool:
	return not _hip_right.is_free() or not _hip_left.is_free()


## Moves each hand's weapon to the hip on its side. Anything that is not a weapon stays.
func sheathe() -> void:
	for pair in _pairs():
		var hand: HandSlot = pair[0]
		var hip: HandSlot = pair[1]
		var held := hand.get_item_data()
		if held and held.is_weapon() and hip.is_free():
			var item := hand.release()
			hip.hold(item)
			_hang(item)


## Takes each holstered weapon back into the hand on its side, if that hand is free.
func draw_now() -> void:
	_draw_left = -1.0
	for pair in _pairs():
		var hand: HandSlot = pair[0]
		var hip: HandSlot = pair[1]
		if not hip.is_free() and hand.is_free():
			hand.hold(hip.release())


## The hip slots, for whoever has to empty them — dropping everything on death.
func get_slots() -> Array[HandSlot]:
	return [_hip_right, _hip_left]


## Turns `item` on the hip so its longest side hangs along the slot's +Y, the way the
## hip slots are angled (down and a little back). Items are not modelled the same way
## round — a hammer's handle runs up its Y, a saw's blade forward along -Z — so the
## direction is read off the item's own shape, from its grip towards the far end.
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


## Moves the hip slots onto the body's Hips bone, keeping where they were placed in the
## scene. A body without one (or without a skeleton) leaves them where they are.
func _attach_to_hips() -> void:
	var skeleton := _body.get("skeleton") as Skeleton3D
	if skeleton == null or skeleton.find_bone("Hips") < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HipAttachment"
	attachment.bone_name = "Hips"
	skeleton.add_child(attachment)
	# Measured against the bone at rest: the attachment has not followed it yet.
	var bone := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Hips"))
	for hip in get_slots():
		var offset := bone.affine_inverse() * hip.global_transform
		hip.reparent(attachment, false)
		hip.transform = offset
