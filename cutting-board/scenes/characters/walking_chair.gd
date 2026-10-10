extends Node3D

signal mask_damaged(durability: int)
signal mask_broken

@export var mask: MaskData:
	set(value):
		if value == mask:
			return
		mask = value
		if is_node_ready():
			_put_on_mask()
@export var mask_offset := Vector3(0.0, 0.0, -0.165)
@export var stride := 0.6
@export var lift := 0.12
@export var animate := true
@export var step_sound: SoundBank = preload("res://resources/audio/chair_step.tres")

@export_group("Mask wear")
@export var head_hit_mask_wear := 2.0
@export var head_hit_radius := 0.3
@export_range(0.0, 1.0) var mask_shatter_chance := 0.75
@export var damaged_mask_left := Vector2(0.1, 0.25)
@export var mask_break_sound: SoundBank = preload("res://resources/audio/break_wood.tres")
@export var mask_break_effect: PackedScene = preload("res://scenes/vfx/break_burst.tscn")
@export var shattered_mask: ItemData = preload("res://resources/items/shattered_mask.tres")
@export_group("")

const THIGH := 0.46
const SHIN := 0.62
const CORNERS := ["FL", "FR", "BL", "BR"]
const BEAT := {"BL": 0.0, "FL": 0.25, "BR": 0.5, "FR": 0.75}
const SWING_WALK := 0.2
const SWING_RUN := 0.32
const RUN_SPEED := 1.2
const BEAT_JITTER := 0.025
const STEP_JITTER := 0.15
const SETTLE_RATE := 1.6

var _face: Node3D
var mask_rng := RandomNumberGenerator.new()
var mask_durability := 0:
	set(value):
		mask_durability = value
		if _face and mask and mask.durability > 0:
			MaskWear.show_crack(_face, float(mask_durability) / mask.durability)
var _limbs := {}
var _home := {}
var _plant := {}
var _hand := {}
var _hand_basis := {}
var _phase := 0.0
var _next_lift := {}
var _on_beat := {}
var _swing := {}
var _swing_len := {}
var _step_scale := {}
var _lift_scale := {}
var _under_way := false
var _rng := RandomNumberGenerator.new()
var _last_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _moving := 0.0
var _idle_time := 0.0
var _body_rest := Vector3.ZERO
var _collapse := -1.0

var attack_crouch := 0.0
var attack_arms := 0.0
var _attacking := false


func _ready() -> void:
	_put_on_mask()
	_body_rest = (%Body as Node3D).position
	var inv := global_transform.affine_inverse()
	for corner in CORNERS:
		var wrist := get_node("%Wrist" + corner) as Node3D
		_limbs[corner] = [get_node("%Hip" + corner), get_node("%Knee" + corner), wrist]
		_home[corner] = (inv * wrist.global_position) * Vector3(0.85, 1.0, 0.8)
		_hand_basis[corner] = global_basis.inverse() * wrist.global_basis
	var fl: Vector3 = _home["FL"]
	_home["FR"] = Vector3(-fl.x, fl.y, fl.z)
	var mirror := Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	_hand_basis["FR"] = mirror * (_hand_basis["FL"] as Basis) * mirror
	_rng.randomize()
	for corner in CORNERS:
		_plant[corner] = global_transform * (_home[corner] as Vector3)
		_hand[corner] = _plant[corner]
		_swing[corner] = -1.0
		_swing_len[corner] = SWING_WALK
		_step_scale[corner] = 1.0
		_lift_scale[corner] = 1.0
		_on_beat[corner] = BEAT[corner]
		_next_lift[corner] = BEAT[corner]
	_last_pos = global_position
	var anim := get_node_or_null("%AnimationPlayer") as AnimationPlayer
	if anim:
		anim.stop()


func _process(delta: float) -> void:
	if not animate or delta <= 0.0:
		return
	if _collapse >= 0.0:
		_collapse = minf(_collapse + delta * 2.5, 1.0)
		_pose_collapsed()
		return
	if _attacking:
		_pose_attack()
		return
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	_velocity = _velocity.lerp(moved / delta, minf(1.0, delta * 8.0))
	var walking := moved.length() > 0.0005
	_moving = move_toward(_moving, 1.0 if walking else 0.0, delta * 3.0)
	if walking and not _under_way and _airborne() == 0:
		_set_off()
	var advance := 0.0
	if walking:
		advance = minf(moved.length() / stride, 0.3)
		_idle_time = 0.0
	elif _airborne() > 0 or _needs_settle():
		advance = delta * SETTLE_RATE
		_idle_time = 0.0
	else:
		_under_way = false
		_idle_time += delta
	_phase += advance
	_step(advance, walking)
	_place_hands()
	_pose_body()
	for corner in CORNERS:
		_solve(corner)


func planted_hand(corner: String) -> Variant:
	if (_hand[corner] as Vector3).is_equal_approx(_plant[corner]):
		return _plant[corner]
	return null


func begin_attack() -> void:
	_attacking = true
	attack_crouch = 0.0
	attack_arms = 0.0


func end_attack() -> void:
	_attacking = false
	attack_crouch = 0.0
	attack_arms = 0.0
	for corner in CORNERS:
		var home: Vector3 = _home[corner]
		var p: Vector3 = global_transform * home
		p.y = global_position.y + home.y
		_plant[corner] = p
		_hand[corner] = p
		_swing[corner] = -1.0
	_under_way = false
	_last_pos = global_position
	_velocity = Vector3.ZERO


func is_attacking() -> bool:
	return _attacking


func _pose_attack() -> void:
	_last_pos = global_position
	var crouch := attack_crouch
	var body := %Body as Node3D
	body.position = _body_rest + Vector3(0.0, -0.05 - 0.16 * crouch, 0.18 * crouch)
	body.rotation = Vector3(0.3 * crouch, 0.0, 0.0)
	(%Head as Node3D).rotation = Vector3(0.2 * crouch, 0.0, 0.0)
	var arms := maxf(attack_arms, crouch * 0.5)
	for corner in CORNERS:
		var home: Vector3 = _home[corner]
		var rest: Vector3 = home
		if corner.begins_with("B"):
			rest += Vector3(0.0, 0.0, -0.1 * crouch)
			_hand[corner] = global_transform * rest
			continue
		var side := signf(home.x)
		var raised := Vector3(side * 0.3, 0.85, -0.55)
		var slammed := Vector3(side * 0.22, home.y, -0.95)
		var local := home.lerp(raised, smoothstep(0.0, 1.0, minf(arms, 1.0)))
		if arms > 1.0:
			local = raised.lerp(slammed, smoothstep(0.0, 1.0, arms - 1.0))
		_hand[corner] = global_transform * local
	for corner in CORNERS:
		_solve(corner)


func collapse(level: Node) -> Node3D:
	if _collapse >= 0.0:
		return null
	_collapse = 0.0
	for corner in CORNERS:
		_plant[corner] = _hand[corner]
	return _drop_mask(level)


func stick_point(_point: Vector3, _part: Node) -> Node3D:
	return %Body as Node3D


func is_collapsed() -> bool:
	return _collapse >= 0.0


func _drop_mask(level: Node) -> Node3D:
	if _face == null or mask == null or level == null:
		return null
	var at := _face.global_transform
	_face.queue_free()
	_face = null
	var dropped: ItemData = mask
	var left := -1
	if mask.durability > 0:
		var fate := MaskWear.roll_on_death(mask_rng, mask, mask_durability, mask_shatter_chance,
				damaged_mask_left, shattered_mask)
		dropped = fate[0]
		left = fate[1]
	var loose := dropped.spawn() if dropped else null
	if loose == null:
		return null
	level.add_child(loose)
	Destructible.write(loose, left)
	loose.global_transform = at
	if loose is RigidBody3D:
		var away := -at.basis.z
		(loose as RigidBody3D).apply_central_impulse((away * 0.6 + Vector3.UP * 0.8).normalized() * 1.2)
	return loose


func _pose_collapsed() -> void:
	var c := smoothstep(0.0, 1.0, _collapse)
	for corner in CORNERS:
		var home: Vector3 = _home[corner]
		var splayed: Vector3 = global_transform * Vector3(home.x * 2.2, home.y, home.z * 1.8)
		_hand[corner] = (_plant[corner] as Vector3).lerp(splayed, c)
	var body := %Body as Node3D
	body.position = _body_rest.lerp(Vector3(0.0, 0.35, 0.0), c)
	body.rotation = Vector3(0.2 * c, 0.0, 0.25 * c)
	(%Head as Node3D).rotation = Vector3(0.6 * c, 0.0, 0.4 * c)
	for corner in CORNERS:
		_solve(corner)


func _put_on_mask() -> void:
	if _face:
		_face.queue_free()
		_face = null
	if mask == null or mask.worn_scene == null:
		return
	_face = mask.worn_scene.instantiate() as Node3D
	_face.position = mask_offset
	%Head.add_child(_face)
	mask_durability = mask.durability


func hit_mask(info: DamageInfo) -> void:
	if is_collapsed() or _face == null or mask == null or info == null or info.amount <= 0 \
			or mask.durability <= 0:
		return
	var wear := info.amount
	if is_head_hit(info.position):
		wear = roundi(info.amount * head_hit_mask_wear)
	mask_durability = maxi(mask_durability - wear, 0)
	mask_damaged.emit(mask_durability)
	if mask_durability == 0:
		_break_mask()


func is_head_hit(point: Vector3) -> bool:
	if point.is_zero_approx():
		return false
	return point.distance_to((%Head as Node3D).global_position) <= head_hit_radius


func _break_mask() -> void:
	var face := _face
	_face = null
	Sfx.play_at(mask_break_sound, face.global_position)
	if mask_break_effect:
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
	var actor := owner if owner else self
	var level := actor.get_parent()
	var loose := shattered_mask.spawn() as RigidBody3D if shattered_mask else null
	if level == null or loose == null:
		return
	level.add_child(loose)
	loose.global_transform = at
	HumanBody.keep_clear_of(loose, actor, 0.5)


func _airborne() -> int:
	var count := 0
	for corner in CORNERS:
		if _swing[corner] >= 0.0:
			count += 1
	return count


func _needs_settle() -> bool:
	for corner in CORNERS:
		if _out_of_place(corner):
			return true
	return false


func _out_of_place(corner: String) -> bool:
	return (_plant[corner] as Vector3).distance_to(_target(corner)) > stride * 0.15


func _set_off() -> void:
	var dir := _velocity.normalized()
	var first: String = CORNERS[0]
	var behind := INF
	for corner in CORNERS:
		var home: Vector3 = global_transform * (_home[corner] as Vector3)
		var lag := ((_plant[corner] as Vector3) - home).dot(dir) + (home - global_position).dot(dir) * 0.1
		if lag < behind:
			behind = lag
			first = corner
	for corner in CORNERS:
		_on_beat[corner] = _phase + fposmod(BEAT[corner] - BEAT[first], 1.0)
		_next_lift[corner] = _on_beat[corner]
		if corner != first:
			_next_lift[corner] += _rng.randf_range(-BEAT_JITTER, BEAT_JITTER)
	_under_way = true


func _step(advance: float, walking: bool) -> void:
	for corner in CORNERS:
		if _swing[corner] < 0.0:
			continue
		_swing[corner] += advance / (_swing_len[corner] as float)
		if _swing[corner] >= 1.0:
			_swing[corner] = -1.0
			_plant[corner] = _target(corner)
			Sfx.play_at(step_sound, _plant[corner])
	var speed := _velocity.length() if walking else 0.0
	var most_up := 2 if speed > RUN_SPEED else 1
	var order := CORNERS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return _next_lift[a] < _next_lift[b])
	for corner in order:
		if _swing[corner] >= 0.0 or _phase < _next_lift[corner]:
			continue
		if not walking and not _out_of_place(corner):
			_on_beat[corner] += 1.0
			_next_lift[corner] += 1.0
			continue
		if _airborne() >= most_up:
			break
		_swing[corner] = 0.0
		_swing_len[corner] = lerpf(SWING_WALK, SWING_RUN, clampf((speed - 0.8) / 0.8, 0.0, 1.0))
		_step_scale[corner] = 1.0 + _rng.randf_range(-STEP_JITTER, STEP_JITTER)
		_lift_scale[corner] = _rng.randf_range(0.75, 1.3)
		_on_beat[corner] += 1.0
		_next_lift[corner] = maxf(_on_beat[corner], _phase + 0.5) + _rng.randf_range(-BEAT_JITTER, BEAT_JITTER)


func _target(corner: String) -> Vector3:
	var home: Vector3 = _home[corner]
	var t: Vector3 = global_transform * home
	if _velocity.length() > 0.05 and _moving > 0.5:
		t += _velocity.normalized() * stride * 0.35 * (_step_scale[corner] as float)
	t.y = global_position.y + home.y
	return t


func _place_hands() -> void:
	for corner in CORNERS:
		var u: float = _swing[corner]
		if u < 0.0:
			_hand[corner] = _plant[corner]
			continue
		var p: Vector3 = (_plant[corner] as Vector3).lerp(_target(corner), smoothstep(0.0, 1.0, u))
		p.y += sin(u * PI) * lift * (_lift_scale[corner] as float)
		_hand[corner] = p
	_idle_gestures()


func _idle_gestures() -> void:
	var still := 1.0 - _moving
	if still <= 0.0 or _idle_time <= 0.0:
		return
	var beat := fposmod(_idle_time, 5.0)
	var tap := maxf(0.0, sin(_idle_time * 9.0)) * 0.05
	tap *= smoothstep(1.0, 1.5, beat) * (1.0 - smoothstep(3.5, 4.0, beat))
	_hand["FL"] = (_hand["FL"] as Vector3) + Vector3.UP * tap * still
	var cycle := fposmod(_idle_time, 11.0)
	var reach := smoothstep(6.0, 6.8, cycle) * (1.0 - smoothstep(8.6, 9.4, cycle)) * still
	if reach > 0.0:
		var out: Vector3 = global_transform * Vector3(0.3, 0.8, -0.8)
		_hand["FR"] = (_hand["FR"] as Vector3).lerp(out, reach)


func _pose_body() -> void:
	var cycle := _phase * TAU
	var body := %Body as Node3D
	var crouch := -0.05 - 0.16 * _moving
	var shift := Vector3(0.0, crouch, 0.0)
	var lean := Vector3.ZERO
	for corner in CORNERS:
		var u: float = _swing[corner]
		if u < 0.0:
			continue
		var w := sin(u * PI)
		var home: Vector3 = _home[corner]
		var side := signf(home.x)
		var end := signf(home.z)
		shift += Vector3(-side * 0.035, -0.02, -end * 0.025) * w
		lean += Vector3(-end * 0.035, 0.0, side * 0.05) * w
	body.position = _body_rest + shift
	body.rotation = lean
	var tilt := 0.25 * sin(_idle_time * 0.8) * (1.0 - _moving)
	(%Head as Node3D).rotation = Vector3(0.0, 0.0, tilt - 0.12 * sin(cycle) * _moving)


func _solve(corner: String) -> void:
	var bones: Array = _limbs[corner]
	var hip: Node3D = bones[0]
	var p := hip.global_position
	var to: Vector3 = (_hand[corner] as Vector3) - p
	var d := clampf(to.length(), absf(THIGH - SHIN) + 0.01, THIGH + SHIN - 0.001)
	var dir := to.normalized()
	var pole := (global_basis.x * signf(hip.position.x) + global_basis.y * 0.6).normalized()
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var axis := dir.cross(perp).normalized()
	var cos_a := clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0)
	var k := p + (dir * cos_a + perp * sqrt(1.0 - cos_a * cos_a)) * THIGH
	var w := p + dir * d
	hip.global_basis = _bone_basis(axis, (p - k).normalized())
	(bones[1] as Node3D).global_basis = _bone_basis(axis, (k - w).normalized())
	(bones[2] as Node3D).global_basis = global_basis * (_hand_basis[corner] as Basis)


func _bone_basis(axis: Vector3, y: Vector3) -> Basis:
	var z := axis.cross(y).normalized()
	return Basis(y.cross(z).normalized(), y, z)
