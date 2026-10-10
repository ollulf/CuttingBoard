class_name BodyAnimator
extends Node

enum Gesture { LOOK_AROUND, GLANCE, LOOK_DOWN, LOOK_UP, STRETCH_NECK, SHIFT_WEIGHT, INSPECT_HAND }

@export_group("Walk")
@export_range(0.0, 60.0) var walk_swing := 24.0
@export_range(0.0, 80.0) var run_swing := 38.0
@export_range(0.0, 120.0) var walk_knee_lift := 40.0
@export_range(0.0, 140.0) var run_knee_lift := 95.0
@export_range(0.0, 1.0) var run_flight := 0.45
@export_range(0.0, 60.0) var walk_arm_swing := 16.0
@export_range(0.0, 80.0) var run_arm_swing := 40.0
@export_range(0.0, 120.0) var walk_elbow_bend := 12.0
@export_range(0.0, 140.0) var run_elbow_bend := 80.0
@export_range(0.0, 30.0) var walk_lean := 3.0
@export_range(0.0, 40.0) var run_lean := 12.0
@export_range(0.0, 20.0) var hip_twist := 6.0
@export var run_bounce := 0.04
@export var stand_speed := 0.15
@export var gait_blend_speed := 6.0
@export var step_sound: SoundBank = preload("res://resources/audio/step_npc.tres")

@export_group("Idle")
@export var breath_rate := 0.23
@export_range(0.0, 10.0) var breath_depth := 2.0
@export var weight_shift := 0.025
@export var gesture_pause := Vector2(1.5, 5.5)
@export_range(0.0, 90.0) var look_range := 60.0
@export_range(0.0, 1.0) var chest_follow := 0.3

@export_group("Holding")
@export var grip_reach := 0.28
@export var hold_blend_speed := 8.0

const CHOP_CONTACT := 0.3
const JAB_CONTACT := 0.15

const CHOP_KEYS := [
	[0.24, Vector3(0.26, 1.72, 0.12), 55.0],
	[CHOP_CONTACT, Vector3(0.18, 1.2, -0.5), -60.0],
	[0.38, Vector3(0.22, 1.02, -0.42), -75.0],
	[0.6, Vector3.INF, 0.0],
]
const JAB_KEYS := [
	[0.09, Vector3(0.3, 1.12, 0.06), 0.0],
	[JAB_CONTACT, Vector3(0.16, 1.36, -0.52), -10.0],
	[0.34, Vector3.INF, 0.0],
]

@onready var _body: HumanBody = %Body
@onready var _skeleton: Skeleton3D = _body.skeleton
@onready var _actor: CharacterBody3D = owner
@onready var _locomotion: Locomotion = %Locomotion
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _hand_left: HandSlot = %HandSlotLeft

var _index := {}
var _rest := {}
var _tail := {}
var _leg_length := 0.0
var _sole_height := 0.0

var _velocity := Vector3.ZERO
var _gait := 0.0
var _phase := 0.0
var _hold := {&"Right": 0.0, &"Left": 0.0}

var _swing_hand: HandSlot
var _swing_keys: Array = []
var _swing_time := 0.0
var _slot_rest := {}

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _breath_offset := 0.0
var _steps: Array[Dictionary] = []
var _step_left := 0.0
var _pause := 0.0
var _look := Vector3.ZERO
var _look_target := Vector3.ZERO
var _look_speed := 3.0
var _inspect := 0.0
var _inspect_target := 0.0
var _inspect_side := 1.0
var _lean_side := 0.0
var _lean_side_target := 1.0
var _collapse: BlindCollapse


func _ready() -> void:
	_rng.randomize()
	for i in _skeleton.get_bone_count():
		var bone_name := StringName(_skeleton.get_bone_name(i))
		_index[bone_name] = i
		_rest[bone_name] = _skeleton.get_bone_rest(i).origin
		_tail[bone_name] = _body.get_bone_tail(bone_name)
	_leg_length = (_tail[&"RightThigh"] as Vector3).length() + (_tail[&"RightShin"] as Vector3).length()
	_sole_height = _model_rest(&"RightShin").y + (_tail[&"RightShin"] as Vector3).y
	_time = _rng.randf_range(0.0, 100.0)
	_breath_offset = _rng.randf() * TAU
	_pause = _rng.randf_range(0.0, gesture_pause.y)
	_lean_side_target = 1.0 if _rng.randf() < 0.5 else -1.0
	_body.went_limp.connect(set_process.bind(false))
	_body.animated = true
	_slot_rest[_hand_right] = _hand_right.transform
	_slot_rest[_hand_left] = _hand_left.transform


func swing(hand: HandSlot, armed: bool) -> void:
	if _swing_hand and _swing_hand != hand:
		_swing_hand.transform = _slot_rest[_swing_hand]
	_swing_hand = hand
	_swing_keys = CHOP_KEYS if armed else JAB_KEYS
	_swing_time = 0.0


func play_blind_collapse() -> BlindCollapse:
	if _swing_hand:
		_swing_hand.transform = _slot_rest[_swing_hand]
		_swing_hand = null
	_collapse = BlindCollapse.new(_body)
	return _collapse


func get_collapse() -> BlindCollapse:
	return _collapse


func contact_time(armed: bool) -> float:
	return CHOP_CONTACT if armed else JAB_CONTACT


func is_swinging() -> bool:
	return _swing_hand != null


func play_gesture(gesture: Gesture) -> void:
	_steps = _gesture(gesture)
	_step_left = 0.0


func _process(delta: float) -> void:
	if _body.is_limp():
		set_process(false)
		return
	if _collapse:
		_collapse.advance(delta)
		return
	_time += delta

	var world := _actor.get_real_velocity()
	world.y = 0.0
	var local := _body.global_basis.inverse() * world
	_velocity = _velocity.lerp(local, _blend(10.0, delta))
	var speed := _velocity.length()
	var moving := speed > stand_speed
	_gait = lerpf(_gait, clampf(speed / maxf(_locomotion.walk_speed * 0.5, 0.01), 0.0, 1.0) if moving else 0.0, _blend(gait_blend_speed, delta))

	_update_gestures(delta)
	_update_swing(delta)
	_update_holding(delta)
	_pose(delta, speed)


func _pose(delta: float, speed: float) -> void:
	var walk := _gait
	var stand := 1.0 - walk
	var run := clampf(inverse_lerp(_locomotion.walk_speed, _locomotion.run_speed, speed), 0.0, 1.0)
	var pace := clampf(speed / maxf(_locomotion.walk_speed, 0.01), 0.35, 1.0)

	var swing := deg_to_rad(lerpf(walk_swing, run_swing, run)) * pace
	var stride := 4.0 * _leg_length * sin(maxf(swing, 0.05)) * (1.0 + run_flight * run)
	var last_phase := _phase
	_phase = fmod(_phase + TAU * speed / stride * delta, TAU)
	_update_steps(last_phase, run)
	var s := sin(_phase)
	var c := cos(_phase)

	var heading := _velocity.normalized() if speed > 0.01 else Vector3.FORWARD
	var leg_axis := heading.cross(Vector3.UP).normalized()
	var ahead := -heading.z

	var breath := sin(_time * TAU * breath_rate + _breath_offset)
	_lean_side = lerpf(_lean_side, _lean_side_target, _blend(0.8, delta))
	var sway := (_lean_side * 0.8 + 0.2 * sin(_time * 0.37 + _breath_offset)) * weight_shift * stand
	var sway_roll := -sway * 2.0

	var lean := deg_to_rad(lerpf(walk_lean, run_lean, run)) * walk * ahead
	var twist := deg_to_rad(hip_twist) * s * walk
	var hips_rot := Basis.from_euler(Vector3(0.0, twist, sway_roll + deg_to_rad(3.0) * c * walk))
	var spine_rot := Basis.from_euler(Vector3(-lean * 0.5 + deg_to_rad(breath_depth) * 0.3 * breath * stand, -twist * 0.6 + _look.y * chest_follow * 0.4, -sway_roll * 0.6))
	var chest_rot := Basis.from_euler(Vector3(-lean * 0.5 - deg_to_rad(breath_depth) * breath * stand, -twist * 0.9 + _look.y * chest_follow * 0.6, -sway_roll * 0.4))
	var head_rot := Basis.from_euler(Vector3(lean * 0.8 + _look.x, -_look.y * chest_follow + _look.y + twist * 0.5, _look.z))

	var knee_lift := deg_to_rad(lerpf(walk_knee_lift, run_knee_lift, run)) * pace
	var stance_bend := deg_to_rad(lerpf(4.0, 22.0, run)) * pace
	var legs := {}
	for side in [&"Right", &"Left"]:
		var leg_phase := 0.0 if side == &"Right" else PI
		var leg_s := sin(_phase + leg_phase)
		var leg_c := cos(_phase + leg_phase)
		var thigh_swing := swing * leg_s * walk
		var plant := -asin(clampf(sway / _leg_length, -0.5, 0.5))
		var thigh := Basis(leg_axis, thigh_swing) * Basis.from_euler(Vector3(0.0, 0.0, plant))
		thigh = hips_rot.inverse() * thigh
		var swinging := maxf(leg_c, 0.0)
		var bend := (knee_lift * swinging * swinging + stance_bend * maxf(-leg_c, 0.0)) * walk
		var shin := Basis(Vector3.RIGHT, -bend)
		legs[side] = [thigh, shin]

	var arm_swing := deg_to_rad(lerpf(walk_arm_swing, run_arm_swing, run)) * pace * walk * ahead
	var elbow := deg_to_rad(lerpf(walk_elbow_bend, run_elbow_bend, run)) * walk + deg_to_rad(8.0) * stand
	var arms := {}
	for side in [&"Right", &"Left"]:
		var sign_side := 1.0 if side == &"Right" else -1.0
		var arm_s := -s if side == &"Right" else s
		var upper := Basis.from_euler(Vector3(arm_swing * arm_s + deg_to_rad(1.0) * breath * stand, 0.0, sign_side * deg_to_rad(2.0) * run))
		var fore := Basis.from_euler(Vector3(elbow, 0.0, 0.0))
		var inspect := _inspect * stand * (1.0 if sign_side == _inspect_side else 0.0)
		if inspect > 0.0:
			upper = upper.slerp(Basis.from_euler(Vector3(deg_to_rad(45.0), 0.0, -sign_side * deg_to_rad(8.0))), inspect)
			fore = fore.slerp(Basis.from_euler(Vector3(deg_to_rad(65.0), 0.0, -sign_side * deg_to_rad(20.0))), inspect)
		arms[side] = [upper, fore]

	var hips_offset := Vector3(sway, 0.0, 0.0)
	var low_sole := INF
	for side in [&"Right", &"Left"]:
		low_sole = minf(low_sole, _sole_y(side, hips_rot, legs[side][0], legs[side][1]))
	hips_offset.y = _sole_height - low_sole
	hips_offset.y += run_bounce * run * walk * absf(s) * 2.0 - run_bounce * run * walk

	var hips_t := Transform3D(hips_rot, _model_rest(&"Hips") + hips_offset)
	var spine_t := hips_t * Transform3D(spine_rot, _rest[&"Spine"])
	var chest_t := spine_t * Transform3D(chest_rot, _rest[&"Chest"])
	for side in [&"Right", &"Left"]:
		var held: float = _hold[side]
		if held > 0.001:
			var reach := _reach(side, chest_t)
			if not reach.is_empty():
				arms[side][0] = (arms[side][0] as Basis).slerp(reach[0], held)
				arms[side][1] = (arms[side][1] as Basis).slerp(reach[1], held)

	_pose_bone(&"Hips", hips_rot, hips_offset)
	_pose_bone(&"Spine", spine_rot)
	_pose_bone(&"Chest", chest_rot)
	_pose_bone(&"Head", head_rot)
	for side in [&"Right", &"Left"]:
		_pose_bone(StringName(side + "Thigh"), legs[side][0])
		_pose_bone(StringName(side + "Shin"), legs[side][1])
		_pose_bone(StringName(side + "UpperArm"), arms[side][0])
		_pose_bone(StringName(side + "Forearm"), arms[side][1])


func _update_steps(last_phase: float, run: float) -> void:
	if _gait < 0.5:
		return
	var from := fposmod(last_phase - PI * 0.5, TAU)
	var to := fposmod(_phase - PI * 0.5, TAU)
	if to < from or (from < PI and to >= PI):
		Sfx.play_at(step_sound, _actor.global_position, linear_to_db(lerpf(0.8, 1.3, run)))


func _sole_y(side: StringName, hips: Basis, thigh: Basis, shin: Basis) -> float:
	var thigh_name := StringName(side + "Thigh")
	var shin_name := StringName(side + "Shin")
	var hip: Vector3 = _model_rest(&"Hips") + hips * _rest[thigh_name]
	var knee: Vector3 = hip + hips * thigh * _rest[shin_name]
	return (knee + hips * thigh * shin * _tail[shin_name]).y


func _reach(side: StringName, chest: Transform3D) -> Array:
	var hand := _hand_right if side == &"Right" else _hand_left
	var upper_name := StringName(side + "UpperArm")
	var fore_name := StringName(side + "Forearm")
	var to_model := _skeleton.global_transform.affine_inverse()
	var target := to_model * hand.global_position
	var shoulder: Vector3 = chest * (_rest[upper_name] as Vector3)
	var upper_rest: Vector3 = _rest[fore_name]
	var fore_rest: Vector3 = (_tail[fore_name] as Vector3).normalized() * grip_reach
	var a := upper_rest.length()
	var b := fore_rest.length()
	var to_target := target - shoulder
	var d := clampf(to_target.length(), absf(a - b) + 0.01, a + b - 0.001)
	var direction := to_target.normalized()
	var pole := Vector3(0.4 if side == &"Right" else -0.4, -0.6, 1.0)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var cos_shoulder := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := shoulder + (direction * cos_shoulder + pole * sqrt(1.0 - cos_shoulder * cos_shoulder)) * a

	var chest_q := chest.basis.get_rotation_quaternion()
	var upper_now := chest_q * upper_rest.normalized()
	var upper_global := Quaternion(upper_now, (elbow - shoulder).normalized()) * chest_q
	var fore_now := upper_global * fore_rest.normalized()
	var fore_global := Quaternion(fore_now, (shoulder + direction * d - elbow).normalized()) * upper_global
	return [Basis(chest_q.inverse() * upper_global), Basis(upper_global.inverse() * fore_global)]


func _pose_bone(bone_name: StringName, rotation: Basis, offset := Vector3.ZERO) -> void:
	var i: int = _index.get(bone_name, -1)
	if i < 0:
		return
	_skeleton.set_bone_pose_rotation(i, rotation.get_rotation_quaternion())
	_skeleton.set_bone_pose_position(i, (_rest[bone_name] as Vector3) + offset)


func _model_rest(bone_name: StringName) -> Vector3:
	return _skeleton.get_bone_global_rest(_index[bone_name]).origin


func _update_holding(delta: float) -> void:
	for side in [&"Right", &"Left"]:
		var hand := _hand_right if side == &"Right" else _hand_left
		if hand == _swing_hand:
			_hold[side] = 1.0
			continue
		var target := 0.0 if hand.is_free() else 1.0
		_hold[side] = lerpf(_hold[side], target, _blend(hold_blend_speed, delta))


func _update_swing(delta: float) -> void:
	if _swing_hand == null:
		return
	_swing_time += delta
	var rest: Transform3D = _slot_rest[_swing_hand]
	var mirror := 1.0 if _swing_hand == _hand_right else -1.0
	var from_time := 0.0
	var from_pos := rest.origin
	var from_pitch := 0.0
	for key: Array in _swing_keys:
		var key_time: float = key[0]
		var key_pos: Vector3 = key[1]
		key_pos = rest.origin if key_pos == Vector3.INF else Vector3(key_pos.x * mirror, key_pos.y, key_pos.z)
		var key_pitch: float = key[2]
		if _swing_time < key_time:
			var t := clampf((_swing_time - from_time) / maxf(key_time - from_time, 0.001), 0.0, 1.0)
			t = t * t if is_equal_approx(key_time, CHOP_CONTACT) or is_equal_approx(key_time, JAB_CONTACT) else smoothstep(0.0, 1.0, t)
			var pitch := deg_to_rad(lerpf(from_pitch, key_pitch, t))
			_swing_hand.transform = Transform3D(Basis(Vector3.RIGHT, pitch) * rest.basis, from_pos.lerp(key_pos, t))
			return
		from_time = key_time
		from_pos = key_pos
		from_pitch = key_pitch
	_swing_hand.transform = rest
	_swing_hand = null


func _update_gestures(delta: float) -> void:
	var busy := _locomotion.has_facing()
	if busy:
		_steps.clear()
		_look_target = Vector3.ZERO
		_inspect_target = 0.0
		_look_speed = 6.0
	elif _steps.is_empty():
		_pause -= delta * (1.0 - _gait * 0.6)
		if _pause <= 0.0:
			_steps = _gesture(_pick_gesture())
			_step_left = 0.0
	if not _steps.is_empty():
		_step_left -= delta
		if _step_left <= 0.0:
			var step: Dictionary = _steps.pop_front()
			_step_left = step.get("time", 1.0)
			_look_target = step.get("look", Vector3.ZERO)
			_look_speed = step.get("speed", 3.0)
			_inspect_target = step.get("inspect", 0.0)
			if step.has("lean"):
				_lean_side_target = step["lean"]
			if _steps.is_empty():
				_pause = _rng.randf_range(gesture_pause.x, gesture_pause.y) + _step_left
	var target := _look_target * (1.0 - _gait * 0.6)
	_look = _look.lerp(target, _blend(_look_speed, delta))
	_inspect = lerpf(_inspect, _inspect_target * (1.0 - _gait), _blend(4.0, delta))


func _pick_gesture() -> Gesture:
	var weights := {
		Gesture.LOOK_AROUND: 3.0,
		Gesture.GLANCE: 3.0,
		Gesture.LOOK_DOWN: 1.5,
		Gesture.LOOK_UP: 1.0,
		Gesture.STRETCH_NECK: 0.7,
		Gesture.SHIFT_WEIGHT: 2.0,
		Gesture.INSPECT_HAND: 1.2 if _gait < 0.1 else 0.0,
	}
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	var roll := _rng.randf() * total
	for gesture: Gesture in weights:
		roll -= weights[gesture]
		if roll <= 0.0:
			return gesture
	return Gesture.GLANCE


func _gesture(gesture: Gesture) -> Array[Dictionary]:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var range_rad := deg_to_rad(look_range)
	var steps: Array[Dictionary] = []
	match gesture:
		Gesture.LOOK_AROUND:
			steps.append({"look": Vector3(_deg(-4, 6), side * range_rad * _rng.randf_range(0.6, 1.0), _deg(-4, 4)), "time": _rng.randf_range(1.0, 1.8), "speed": 2.5})
			steps.append({"look": Vector3(_deg(-4, 6), -side * range_rad * _rng.randf_range(0.5, 0.9), _deg(-4, 4)), "time": _rng.randf_range(1.0, 1.8), "speed": 2.0})
			steps.append({"look": Vector3.ZERO, "time": 0.6, "speed": 2.5})
		Gesture.GLANCE:
			steps.append({"look": Vector3(_deg(-5, 8), side * range_rad * _rng.randf_range(0.7, 1.1), 0.0), "time": _rng.randf_range(0.5, 0.9), "speed": 9.0})
			steps.append({"look": Vector3.ZERO, "time": 0.4, "speed": 5.0})
		Gesture.LOOK_DOWN:
			steps.append({"look": Vector3(-_deg(25, 38), _deg(-20, 20), _deg(-6, 6)), "time": _rng.randf_range(1.4, 2.6), "speed": 2.5})
			steps.append({"look": Vector3.ZERO, "time": 0.5, "speed": 3.0})
		Gesture.LOOK_UP:
			steps.append({"look": Vector3(_deg(18, 28), _deg(-25, 25), _deg(-5, 5)), "time": _rng.randf_range(1.5, 2.5), "speed": 2.0})
			steps.append({"look": Vector3.ZERO, "time": 0.6, "speed": 2.5})
		Gesture.STRETCH_NECK:
			steps.append({"look": Vector3(0.0, 0.0, side * _deg(18, 26)), "time": 0.9, "speed": 3.0})
			steps.append({"look": Vector3(0.0, 0.0, -side * _deg(18, 26)), "time": 1.0, "speed": 3.0})
			steps.append({"look": Vector3.ZERO, "time": 0.5, "speed": 3.0})
		Gesture.SHIFT_WEIGHT:
			steps.append({"look": Vector3(_deg(-3, 3), _deg(-12, 12), 0.0), "time": 1.6, "speed": 1.5, "lean": -_lean_side_target})
			steps.append({"look": Vector3.ZERO, "time": 0.4, "speed": 2.0})
		Gesture.INSPECT_HAND:
			var hand := _hand_right if side > 0.0 else _hand_left
			if not hand.is_free():
				side = -side
				hand = _hand_right if side > 0.0 else _hand_left
			if not hand.is_free():
				return _gesture(Gesture.LOOK_DOWN)
			_inspect_side = side
			steps.append({"look": Vector3(-deg_to_rad(38.0), -side * deg_to_rad(14.0), side * deg_to_rad(5.0)), "inspect": 1.0, "time": _rng.randf_range(1.8, 3.0), "speed": 3.0})
			steps.append({"look": Vector3.ZERO, "inspect": 0.0, "time": 0.7, "speed": 3.0})
	return steps


func _deg(low: float, high: float) -> float:
	return deg_to_rad(_rng.randf_range(low, high))


func _blend(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
