extends Node3D

const BODY := preload("res://scenes/characters/human_body.tscn")
const MASK := preload("res://resources/items/villager_mask.tres")

const BREAK_TIME := 0.8
const WALK_SPEED := 0.32
const STEP_RATE := 0.55
const END_TIME := 9.5

const KEYS_COMMON := [
	[0.0, {}],
	[BREAK_TIME, {}],
	[1.1, {"hdp": 20.0, "sp": 4.0, "cp": 8.0, "ua": -12.0, "fa": 25.0, "spread": 10.0}],
	[1.9, {"hdp": 10.0, "sp": -3.0, "cp": -5.0, "ua": 86.0, "fa": 6.0}],
	[2.3, {"hdp": 10.0, "sp": -3.0, "cp": -5.0, "ua": 86.0, "fa": 6.0, "walk": 1.0}],
	[4.5, {"hdp": 6.0, "sp": -4.0, "cp": -6.0, "ua": 84.0, "fa": 8.0, "walk": 1.0}],
	[4.9, {"hdp": 0.0, "sp": -5.0, "cp": -6.0, "ua": 80.0, "fa": 8.0}],
	[6.0, {"hy": -0.36, "sh": 90.0, "sp": -10.0, "cp": -10.0, "hdp": -8.0, "ua": 68.0, "fa": 12.0}],
	[6.6, {"hy": -0.36, "sh": 90.0, "sp": -18.0, "cp": -16.0, "hdp": -28.0, "ua": 50.0, "fa": 16.0}],
]
const KEYS_A := [
	[7.7, {"hy": -0.36, "sh": 8.0, "sp": 2.0, "cp": 0.0, "hdp": -4.0, "hdy": 55.0, "ua": 150.0, "fa": 4.0, "rp": -86.0, "fall": 1.0}],
	[END_TIME, {"hy": -0.36, "sh": 5.0, "sp": 2.0, "cp": 0.0, "hdp": -2.0, "hdy": 60.0, "ua": 154.0, "fa": 2.0, "rp": -88.0}],
]
const KEYS_B := [
	[7.0, {"hy": -0.36, "sh": 90.0, "sp": -24.0, "cp": -18.0, "hdp": -35.0, "hdy": 0.0, "hdr": 12.0, "ua": 20.0, "fa": 20.0, "rr": 6.0}],
	[8.0, {"hy": -0.36, "sh": 70.0, "th": 20.0, "sp": -14.0, "cp": -10.0, "hdp": -10.0, "hdr": 30.0, "ua": 8.0, "fa": 30.0, "spread": 20.0, "rr": 84.0, "fall": 1.0}],
	[END_TIME, {"hy": -0.36, "sh": 68.0, "th": 22.0, "sp": -12.0, "cp": -10.0, "hdp": -8.0, "hdr": 34.0, "ua": 6.0, "fa": 32.0, "spread": 22.0, "rr": 86.0}],
]

var _variant := "a"
var _shots_dir := ""
var _shot_times: Array[float] = [0.5, 1.2, 3.2, 6.4, 9.2]
var _taken := 0
var _time := 0.0
var _broken := false
var _walked := 0.0
var _phase := 0.0
var _keys: Array = []
var _root: Node3D
var _body: HumanBody
var _skeleton: Skeleton3D
var _index := {}
var _rest := {}
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			_variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_keys = KEYS_COMMON + (KEYS_B if _variant == "b" else KEYS_A)
	_build_stage()
	_root = Node3D.new()
	add_child(_root)
	_body = BODY.instantiate()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.5, 0.8)
	_body.material = material
	_body.mask = MASK
	_root.add_child(_body)
	_skeleton = _body.skeleton
	for i in _skeleton.get_bone_count():
		var bone_name := StringName(_skeleton.get_bone_name(i))
		_index[bone_name] = i
		_rest[bone_name] = _skeleton.get_bone_rest(i).origin
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()
	_camera.look_at_from_position(Vector3(3.7, 1.6, -2.1), Vector3(0.0, 0.75, -0.9))
	_apply(0.0)


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.42, 0.42, 0.5)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.9, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.36, 0.31, 0.24)
	floor_mesh.material_override = floor_material
	ground.add_child(floor_mesh)
	add_child(ground)


func _process(delta: float) -> void:
	_time += delta
	if not _broken and _time >= BREAK_TIME:
		_broken = true
		_body.break_mask()
	_apply(delta)
	if _taken < _shot_times.size() and _time >= _shot_times[_taken]:
		_shoot(_taken)
		_taken += 1
	if _time >= END_TIME + 0.5:
		get_tree().quit()


func _shoot(index: int) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_shots_dir, _variant, index])


func _sample(t: float) -> Dictionary:
	var before: Array = _keys[0]
	for key: Array in _keys:
		if key[0] > t:
			var span: float = key[0] - before[0]
			var f := clampf((t - before[0]) / maxf(span, 0.001), 0.0, 1.0)
			f = f * f if (key[1] as Dictionary).get("fall", 0.0) > 0.0 else smoothstep(0.0, 1.0, f)
			return _mix(before[1], key[1], f)
		before = key
	return _mix(before[1], before[1], 0.0)


func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in ["hy", "hp", "sp", "cp", "hdp", "hdy", "hdr", "ua", "fa", "th", "sh", "rp", "rr", "walk", "spread"]:
		out[k] = lerpf(a.get(k, 0.0), b.get(k, 0.0), f)
	return out


func _apply(delta: float) -> void:
	var p := _sample(_time)
	var walk: float = p["walk"]
	_phase += TAU * STEP_RATE * delta * walk
	var s := sin(_phase)
	var c := cos(_phase)
	var push := maxf(0.0, absf(s)) * 1.6
	_walked += WALK_SPEED * walk * push * delta
	_root.position = Vector3(0.0, 0.0, -_walked)

	var grope := sin(_time * 2.3) * walk
	var search := sin(_time * 1.1 + 0.6)
	var listen: float = clampf((_time - BREAK_TIME) * 2.0, 0.0, 1.0) * (1.0 - clampf((_time - 5.2) * 1.2, 0.0, 1.0))

	var hips_rot := Basis.from_euler(Vector3(deg_to_rad(p["hp"]), deg_to_rad(5.0) * s * walk, deg_to_rad(3.0) * c * walk))
	var spine_rot := Basis.from_euler(Vector3(deg_to_rad(p["sp"]), -deg_to_rad(4.0) * s * walk, 0.0))
	var chest_rot := Basis.from_euler(Vector3(deg_to_rad(p["cp"]), deg_to_rad(6.0) * grope, 0.0))
	var head_rot := Basis.from_euler(Vector3(
		deg_to_rad(p["hdp"]),
		deg_to_rad(p["hdy"]) + deg_to_rad(28.0) * search * listen,
		deg_to_rad(p["hdr"]) + deg_to_rad(8.0) * search * listen))
	var bob := -0.025 * absf(c) * walk

	_pose(&"Hips", hips_rot, Vector3(0.0, p["hy"] + bob, 0.0))
	_pose(&"Spine", spine_rot)
	_pose(&"Chest", chest_rot)
	_pose(&"Head", head_rot)
	for side in [&"Right", &"Left"]:
		var mirror := 1.0 if side == &"Right" else -1.0
		var leg_s := s if side == &"Right" else -s
		var leg_c := c if side == &"Right" else -c
		var thigh := deg_to_rad(p["th"]) + deg_to_rad(18.0) * leg_s * walk
		var shin := deg_to_rad(p["sh"]) + deg_to_rad(30.0) * maxf(leg_c, 0.0) * walk
		_pose(StringName(side + "Thigh"), Basis(Vector3.RIGHT, thigh))
		_pose(StringName(side + "Shin"), Basis(Vector3.RIGHT, -shin))
		var reach := deg_to_rad(p["ua"]) + deg_to_rad(9.0) * grope * mirror
		var inward := -mirror * deg_to_rad(6.0) * clampf(p["ua"] / 80.0, 0.0, 1.0) + mirror * deg_to_rad(p["spread"])
		var sweep := deg_to_rad(10.0) * sin(_time * 1.7 + mirror) * walk
		_pose(StringName(side + "UpperArm"), Basis.from_euler(Vector3(reach, sweep, inward)))
		_pose(StringName(side + "Forearm"), Basis.from_euler(Vector3(deg_to_rad(p["fa"]), 0.0, 0.0)))

	var pivot := Vector3(0.0, lerpf(0.06, 0.15, absf(p["rp"]) / 88.0), 0.0)
	if _variant == "b":
		pivot = Vector3(0.12, lerpf(0.06, 0.16, absf(p["rr"]) / 86.0), 0.0)
	var tilt := Basis.from_euler(Vector3(deg_to_rad(p["rp"]), 0.0, -deg_to_rad(p["rr"])))
	_body.transform = Transform3D(Basis.IDENTITY, pivot) * Transform3D(tilt, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)


func _pose(bone_name: StringName, rotation: Basis, offset := Vector3.ZERO) -> void:
	var i: int = _index.get(bone_name, -1)
	if i < 0:
		return
	_skeleton.set_bone_pose_rotation(i, rotation.get_rotation_quaternion())
	_skeleton.set_bone_pose_position(i, (_rest[bone_name] as Vector3) + offset)
