class_name BlindCollapse
extends RefCounted

const WALK_SPEED := 0.32
const STEP_RATE := 0.55
const RAGDOLL_TIME := 7.2
const END_TIME := 8.7

const KEYS := [
	[0.0, {}],
	[0.3, {"hdp": 20.0, "sp": 4.0, "cp": 8.0, "ua": -12.0, "fa": 25.0, "spread": 10.0}],
	[1.1, {"hdp": 10.0, "sp": -3.0, "cp": -5.0, "ua": 86.0, "fa": 6.0}],
	[1.5, {"hdp": 10.0, "sp": -3.0, "cp": -5.0, "ua": 86.0, "fa": 6.0, "walk": 1.0}],
	[3.7, {"hdp": 6.0, "sp": -4.0, "cp": -6.0, "ua": 84.0, "fa": 8.0, "walk": 1.0}],
	[4.1, {"hdp": 0.0, "sp": -5.0, "cp": -6.0, "ua": 80.0, "fa": 8.0}],
	[5.2, {"hy": -0.36, "sh": 90.0, "sp": -10.0, "cp": -10.0, "hdp": -8.0, "ua": 68.0, "fa": 12.0}],
	[5.8, {"hy": -0.36, "sh": 90.0, "sp": -18.0, "cp": -16.0, "hdp": -28.0, "ua": 50.0, "fa": 16.0}],
	[6.9, {"hy": -0.36, "sh": 8.0, "sp": 2.0, "cp": 0.0, "hdp": -4.0, "hdy": 55.0, "ua": 150.0, "fa": 4.0, "rp": -86.0, "fall": 1.0}],
	[END_TIME, {"hy": -0.36, "sh": 5.0, "sp": 2.0, "cp": 0.0, "hdp": -2.0, "hdy": 60.0, "ua": 154.0, "fa": 2.0, "rp": -88.0}],
]
const CHANNELS := ["hy", "sp", "cp", "hdp", "hdy", "ua", "fa", "th", "sh", "rp", "walk", "spread"]

var time := 0.0

var _body: HumanBody
var _skeleton: Skeleton3D
var _base: Transform3D
var _index := {}
var _rest := {}
var _phase := 0.0
var _speed := 0.0


func _init(body: HumanBody) -> void:
	_body = body
	_skeleton = body.skeleton
	_base = body.transform
	for i in _skeleton.get_bone_count():
		var bone_name := StringName(_skeleton.get_bone_name(i))
		_index[bone_name] = i
		_rest[bone_name] = _skeleton.get_bone_rest(i).origin


func advance(delta: float) -> void:
	time += delta
	_apply(delta)


func is_down() -> bool:
	return time >= RAGDOLL_TIME


func is_over() -> bool:
	return time >= END_TIME


func step_speed() -> float:
	return _speed


func _sample(t: float) -> Dictionary:
	var before: Array = KEYS[0]
	for key: Array in KEYS:
		if key[0] > t:
			var span: float = key[0] - before[0]
			var f := clampf((t - before[0]) / maxf(span, 0.001), 0.0, 1.0)
			f = f * f if (key[1] as Dictionary).get("fall", 0.0) > 0.0 else smoothstep(0.0, 1.0, f)
			return _mix(before[1], key[1], f)
		before = key
	return _mix(before[1], before[1], 0.0)


func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k: String in CHANNELS:
		out[k] = lerpf(a.get(k, 0.0), b.get(k, 0.0), f)
	return out


func _apply(delta: float) -> void:
	var p := _sample(time)
	var walk: float = p["walk"]
	_phase += TAU * STEP_RATE * delta * walk
	var s := sin(_phase)
	var c := cos(_phase)
	_speed = WALK_SPEED * walk * absf(s) * 1.6

	var grope := sin(time * 2.3) * walk
	var search := sin(time * 1.1 + 1.5)
	var listen := clampf(time * 2.0, 0.0, 1.0) * (1.0 - clampf((time - 4.4) * 1.2, 0.0, 1.0))

	var hips_rot := Basis.from_euler(Vector3(0.0, deg_to_rad(5.0) * s * walk, deg_to_rad(3.0) * c * walk))
	var spine_rot := Basis.from_euler(Vector3(deg_to_rad(p["sp"]), -deg_to_rad(4.0) * s * walk, 0.0))
	var chest_rot := Basis.from_euler(Vector3(deg_to_rad(p["cp"]), deg_to_rad(6.0) * grope, 0.0))
	var head_rot := Basis.from_euler(Vector3(
		deg_to_rad(p["hdp"]),
		deg_to_rad(p["hdy"]) + deg_to_rad(28.0) * search * listen,
		deg_to_rad(8.0) * search * listen))
	var bob := -0.025 * absf(c) * walk

	_pose(&"Hips", hips_rot, Vector3(0.0, p["hy"] + bob, 0.0))
	_pose(&"Spine", spine_rot)
	_pose(&"Chest", chest_rot)
	_pose(&"Head", head_rot)
	for side in [&"Right", &"Left"]:
		var mirror := 1.0 if side == &"Right" else -1.0
		var leg_s := s * mirror
		var leg_c := c * mirror
		var thigh := deg_to_rad(p["th"]) + deg_to_rad(18.0) * leg_s * walk
		var shin := deg_to_rad(p["sh"]) + deg_to_rad(30.0) * maxf(leg_c, 0.0) * walk
		_pose(StringName(side + "Thigh"), Basis(Vector3.RIGHT, thigh))
		_pose(StringName(side + "Shin"), Basis(Vector3.RIGHT, -shin))
		var reach := deg_to_rad(p["ua"]) + deg_to_rad(9.0) * grope * mirror
		var inward := -mirror * deg_to_rad(6.0) * clampf(p["ua"] / 80.0, 0.0, 1.0) + mirror * deg_to_rad(p["spread"])
		var sweep := deg_to_rad(10.0) * sin(time * 1.7 + mirror) * walk
		_pose(StringName(side + "UpperArm"), Basis.from_euler(Vector3(reach, sweep, inward)))
		_pose(StringName(side + "Forearm"), Basis.from_euler(Vector3(deg_to_rad(p["fa"]), 0.0, 0.0)))

	var pivot := Vector3(0.0, lerpf(0.06, 0.15, absf(p["rp"]) / 88.0), 0.0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(p["rp"]))
	_body.transform = _base * Transform3D(Basis.IDENTITY, pivot) * Transform3D(tilt, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)


func _pose(bone_name: StringName, rotation: Basis, offset := Vector3.ZERO) -> void:
	var i: int = _index.get(bone_name, -1)
	if i < 0:
		return
	_skeleton.set_bone_pose_rotation(i, rotation.get_rotation_quaternion())
	_skeleton.set_bone_pose_position(i, (_rest[bone_name] as Vector3) + offset)
