class_name MaskMongerBody
extends NpcBody

## The Mask-Monger's body (scenes/characters/mask_monger_model.tscn, built by
## scripts/import/build_mask_monger.gd) and the procedural animation that keeps it alive.
##
## It walks on four limbs in a slow four-beat gait, one limb at a time in the order
## LegL, KnuckleArmR, LegR, KnuckleArmL, at the pace the character really covers ground.
## Standing, its barrel and torso bob as it breathes, its head drifts about, the hand
## puppet now and then flaps its jaw as if haggling, and the masks for sale swing on
## their hooks all the while (more so on the move).
##
## There is no ragdoll: a hit rocks the whole figure on its feet, and death slumps it
## where it stands. A blow meant for a worn mask sets the rack's masks swinging instead.
## All of it is purely visual: nothing here feeds back into Sight, the Brain or
## Locomotion.

@export_group("Walk")
## Metres covered by one full cycle of all four limbs.
@export var stride_length := 1.1
## How far each leg and knuckle-arm swings either side of its rest pose, in degrees.
@export_range(0.0, 60.0) var limb_swing := 22.0
## How far a knee or elbow folds as its limb is carried forward, in degrees.
@export_range(0.0, 90.0) var limb_lift := 30.0
## Below this ground speed, in metres per second, it is standing still.
@export var stand_speed := 0.15
## The ground speed at which the gait is in full swing.
@export var full_gait_speed := 0.9
## How quickly the pose blends between standing and walking, higher is snappier.
@export var gait_blend_speed := 4.0
## How far the barrel and torso rise and roll with each step, in metres and degrees.
@export var walk_bob := 0.03
@export_range(0.0, 20.0) var walk_roll := 4.0

@export_group("Idle")
## Breaths per second, and how far each lifts the barrel and torso, in metres.
@export var breath_rate := 0.3
@export var breath_depth := 0.012
## Furthest the head drifts to either side, in degrees.
@export_range(0.0, 60.0) var head_drift := 18.0
## Seconds between one bout of the puppet's chatter and the next, as a random range.
@export var chatter_pause := Vector2(3.0, 8.0)
## How long a bout of chatter lasts, in seconds, as a random range.
@export var chatter_length := Vector2(0.6, 1.6)
## Jaw flaps per second while chattering, and how wide it opens, in degrees.
@export var jaw_rate := 5.0
@export_range(0.0, 60.0) var jaw_open := 28.0
## How far the rack's masks sway on their hooks, in degrees, standing and walking.
@export_range(0.0, 30.0) var mask_sway := 3.0
@export_range(0.0, 45.0) var walk_mask_sway := 12.0

@export_group("Hits")
## How heavy the character is to shove, in kilograms: a blow's impulse over this is the
## knockback velocity.
@export var mass := 150.0
## How far a blow rocks the figure, in degrees per unit of impulse, and the most it can.
@export var flinch_per_impulse := 0.6
@export_range(0.0, 30.0) var max_flinch := 12.0
## How long the slump takes when it dies, in seconds.
@export var slump_time := 0.8

## The four limbs that step, in the order they step, each with its knee or elbow.
@onready var _limbs: Array[Node3D] = [%LegL, %KnuckleArmR, %LegR, %KnuckleArmL]
@onready var _joints: Array[Node3D] = [%KneeL, %KnuckleElbowR, %KneeR, %KnuckleElbowL]
@onready var _model: Node3D = %Model
@onready var _barrel: Node3D = %Barrel
@onready var _torso: Node3D = %Torso
@onready var _head: Node3D = %Head
@onready var _rack: Node3D = %Rack
@onready var _jaw: Node3D = %Jaw
@onready var _puppet_arm: Node3D = %PuppetArm
@onready var _lantern: Node3D = %Lantern
@onready var _hooks: Array[Node3D] = [%Hook1, %Hook2, %Hook3, %Hook4, %Hook5]

## How far through the four-beat cycle the limbs are, in cycles (only its fraction counts).
var _phase := 0.0
## 0 standing .. 1 in full gait.
var _gait := 0.0
var _time := 0.0
var _limp := false
## 0 standing .. 1 slumped dead.
var _slump := 0.0
var _chatter_in := 0.0
var _chatter_left := 0.0
## The whole figure's rock from a blow: an angle (radians) about _jolt_axis, and its speed.
var _jolt := 0.0
var _jolt_speed := 0.0
var _jolt_axis := Vector3.RIGHT
## Each hook's extra swing from a knock, in radians, and its speed.
var _knock: Array[float] = []
var _knock_speed: Array[float] = []
## Rest pose, node -> Transform3D, recorded once so every frame poses from scratch.
var _rest := {}


func _ready() -> void:
	for n: Node3D in _limbs + _joints + _hooks + [
			_model, _barrel, _torso, _head, _rack, _jaw, _puppet_arm, _lantern]:
		_rest[n] = n.transform
	for i in _hooks.size():
		_knock.append(0.0)
		_knock_speed.append(0.0)
	_time = randf() * 10.0
	_chatter_in = randf_range(chatter_pause.x, chatter_pause.y)


func is_limp() -> bool:
	return _limp


## Its chest, wherever it slumped.
func get_center() -> Vector3:
	return _barrel.global_position + Vector3.UP * 0.25


func get_knockback(info: DamageInfo) -> Vector3:
	if info == null:
		return Vector3.ZERO
	var impulse := info.get_impulse()
	impulse.y = 0.0
	return impulse / maxf(mass, 1.0)


## Rocks the whole figure on its feet away from the blow; a second blow adds to the first.
func flinch(info: DamageInfo) -> void:
	if info == null or _limp:
		return
	var impulse := info.get_impulse()
	var push := global_basis.inverse() * Vector3(impulse.x, 0.0, impulse.z)
	if push.length_squared() < 0.0001:
		push = Vector3.BACK
	var axis := Vector3.UP.cross(push.normalized())
	var strength := minf(impulse.length() * flinch_per_impulse, max_flinch)
	# Kept on one axis: a new blow from elsewhere turns the rock already playing out.
	_jolt_axis = axis.normalized()
	_jolt_speed += deg_to_rad(strength) * 9.0


## No ragdoll: it folds where it stands and stays there.
func go_limp(_info: DamageInfo = null, _carried_velocity := Vector3.ZERO) -> void:
	if _limp:
		return
	_limp = true
	_chatter_left = 0.0
	create_tween().tween_property(self, "_slump", 1.0, slump_time) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	went_limp.emit()


## It wears no mask to break; a blow sets the masks for sale swinging instead.
func hit_mask(_info: DamageInfo) -> void:
	for i in _hooks.size():
		_knock_speed[i] += randf_range(-3.0, 3.0)


func _process(delta: float) -> void:
	_time += delta
	var speed := _forward_speed()
	if not _limp:
		_phase += speed / maxf(stride_length, 0.01) * delta
	var target := 0.0
	if not _limp and absf(speed) > stand_speed:
		target = clampf(absf(speed) / full_gait_speed, 0.0, 1.0)
	_gait = move_toward(_gait, target, gait_blend_speed * delta)
	_update_jolt(delta)
	_update_chatter(delta)
	_pose_limbs()
	_pose_body()
	_pose_masks(delta)


## Ground speed along the way the character faces; backwards is negative.
func _forward_speed() -> float:
	var actor := get_actor() as CharacterBody3D
	if actor == null:
		return 0.0
	var velocity := actor.get_real_velocity()
	return velocity.dot(-actor.global_basis.z.normalized())


## Each limb swings back while its foot is down and is carried forward, knee folded,
## once it lifts, a quarter cycle behind the limb before it.
func _pose_limbs() -> void:
	var swing := deg_to_rad(limb_swing) * _gait
	var lift := deg_to_rad(limb_lift) * _gait
	for i in _limbs.size():
		var angle := TAU * (_phase - i * 0.25)
		var limb := _limbs[i]
		var joint := _joints[i]
		var limb_rest: Transform3D = _rest[limb]
		var joint_rest: Transform3D = _rest[joint]
		# The model faces +Z: turning about +X carries a hanging limb backwards.
		limb.basis = Basis(Vector3.RIGHT, swing * sin(angle)) * limb_rest.basis
		var fold := lift * maxf(0.0, -cos(angle))
		# Dead, the legs fold under the sinking body.
		fold += 0.7 * _slump
		joint.basis = joint_rest.basis * Basis(Vector3.RIGHT, fold)
		if _slump > 0.0:
			limb.basis = Basis(Vector3.RIGHT, -0.4 * _slump) * limb.basis


func _pose_body() -> void:
	var breath := sin(_time * TAU * breath_rate) * breath_depth * (1.0 - _gait)
	var step := -cos(TAU * _phase * 2.0) * walk_bob * _gait
	var roll := sin(TAU * _phase) * deg_to_rad(walk_roll) * _gait
	var rise := Vector3.UP * (breath + step)
	for n: Node3D in [_barrel, _torso, _rack]:
		var rest: Transform3D = _rest[n]
		n.position = rest.origin + rise
		n.basis = Basis(Vector3.BACK, roll) * rest.basis
	# The torso leans into the walk, and slumps forward over the barrel when dead.
	_torso.basis = Basis(Vector3.RIGHT, 0.08 * _gait + 0.5 * _slump) * _torso.basis

	var head_rest: Transform3D = _rest[_head]
	var drift := sin(_time * 0.37) * sin(_time * 0.23 + 1.0) * deg_to_rad(head_drift)
	_head.basis = Basis(Vector3.UP, drift * (1.0 - _slump)) * Basis(Vector3.RIGHT, 0.6 * _slump) \
			* head_rest.basis

	var jaw_rest: Transform3D = _rest[_jaw]
	var arm_rest: Transform3D = _rest[_puppet_arm]
	var open := 0.0
	var waggle := 0.0
	if _chatter_left > 0.0:
		open = absf(sin(_time * PI * jaw_rate)) * deg_to_rad(jaw_open)
		waggle = sin(_time * TAU * jaw_rate * 0.5) * 0.08
	_jaw.basis = jaw_rest.basis * Basis(Vector3.RIGHT, open)
	_puppet_arm.basis = Basis(Vector3.BACK, waggle) * Basis(Vector3.RIGHT, 0.9 * _slump) \
			* arm_rest.basis

	# The lantern hangs from its hook and lags behind the steps.
	var lantern_rest: Transform3D = _rest[_lantern]
	var sway := sin(TAU * _phase * 2.0 - 0.8) * 0.18 * _gait + sin(_time * 1.3) * 0.03
	_lantern.basis = Basis(Vector3.RIGHT, sway) * lantern_rest.basis

	var model_rest: Transform3D = _rest[_model]
	_model.position = model_rest.origin + Vector3.DOWN * 0.3 * _slump
	_model.basis = Basis(_jolt_axis, _jolt) * Basis(Vector3.BACK, 0.25 * _slump) \
			* model_rest.basis


## The masks sway about their hooks, side to side, a little out of step with each other.
func _pose_masks(delta: float) -> void:
	var amount := deg_to_rad(lerpf(mask_sway, walk_mask_sway, _gait)) * (1.0 - _slump)
	for i in _hooks.size():
		# A knock swings on and dies away like a pendulum.
		_knock_speed[i] += (-30.0 * _knock[i] - 1.5 * _knock_speed[i]) * delta
		_knock[i] += _knock_speed[i] * delta
		var hook := _hooks[i]
		var rest: Transform3D = _rest[hook]
		var swing := sin(_time * 1.7 + i * 1.3) * amount + _knock[i]
		hook.basis = Basis(Vector3.BACK, swing) * rest.basis


## The rock from a blow springs back to standing.
func _update_jolt(delta: float) -> void:
	_jolt_speed += (-90.0 * _jolt - 10.0 * _jolt_speed) * delta
	_jolt += _jolt_speed * delta


func _update_chatter(delta: float) -> void:
	if _limp:
		return
	if _chatter_left > 0.0:
		_chatter_left -= delta
		return
	_chatter_in -= delta
	if _chatter_in <= 0.0:
		_chatter_left = randf_range(chatter_length.x, chatter_length.y)
		_chatter_in = randf_range(chatter_pause.x, chatter_pause.y)
