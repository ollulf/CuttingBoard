extends Node3D

const MONGER := preload("res://scenes/characters/mask_monger_model.tscn")
const MASK := preload("res://scenes/characters/masks/villager_mask.tscn")
const BOTTLE := preload("res://scenes/items/soul_bottle.tscn")

const HAND_OFF := 0.0
const TOSS := 0.8
const IGNITE := 1.5
const SPIRAL := 2.5
const BOTTLE_UP := 3.7
const SET_DOWN := 4.6
const END := 5.8

const APEX := Vector3(0.0, 2.5, -0.6)

var _time := 0.0
var _monger: Node3D
var _puppet_arm: Node3D
var _lantern_arm: Node3D
var _head: Node3D
var _jaw: Node3D
var _hand: Node3D
var _arm_rest: Basis
var _lantern_rest: Basis
var _head_rest: Basis
var _jaw_rest: Basis
var _mask: Node3D
var _flare: MeshInstance3D
var _flare_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _embers: CPUParticles3D
var _shavings: CPUParticles3D
var _smoke: CPUParticles3D
var _soul: MeshInstance3D
var _soul_light: OmniLight3D
var _bottle: Node3D
var _camera: Camera3D
var _mask_start := Vector3(0.35, 1.25, -1.9)
var _bottle_ground := Vector3(0.35, 0.11, -1.0)


func _ready() -> void:
	var wide := "--wide" in OS.get_cmdline_user_args()
	PsxScreen.enabled = "--plain" not in OS.get_cmdline_user_args() and PsxScreen.enabled
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.06, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.35, 0.45)
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(-0.8, 0.5, 0.0)
	moon.light_energy = 0.5
	moon.light_color = Color(0.7, 0.75, 1.0)
	add_child(moon)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.3, 0.25)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	_monger = MONGER.instantiate()
	add_child(_monger)
	_puppet_arm = _monger.get_node("%PuppetArm")
	_lantern_arm = _monger.get_node("%LanternArm")
	_head = _monger.get_node("%Head")
	_jaw = _monger.get_node("%Jaw")
	_hand = _monger.get_node("%Puppet")
	_arm_rest = _puppet_arm.basis
	_lantern_rest = _lantern_arm.basis
	_head_rest = _head.basis
	_jaw_rest = _jaw.basis

	_mask = MASK.instantiate()
	add_child(_mask)
	_flare = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.36)
	_flare.mesh = quad
	_flare_mat = StandardMaterial3D.new()
	_flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flare_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.0)
	_flare.material_override = _flare_mat
	_flare.position = Vector3(0, 0, -0.01)
	_flare.rotation.y = PI
	_mask.add_child(_flare)

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.2)
	_fire_light.omni_range = 5.0
	_fire_light.light_energy = 0.0
	add_child(_fire_light)
	_embers = _make_particles(Color(1.0, 0.6, 0.15), 0.03, 60, Vector3(0, 2.0, 0), 1.0)
	_shavings = _make_particles(Color(0.75, 0.6, 0.4), 0.04, 24, Vector3(0, 1.0, 0), 1.2)
	_shavings.gravity = Vector3(0, -6, 0)
	_smoke = _make_particles(Color(0.55, 0.5, 0.6, 0.6), 0.09, 40, Vector3(0, -0.3, 0), 1.6)
	_smoke.gravity = Vector3(0, -0.2, 0)
	_smoke.initial_velocity_max = 0.4

	_soul = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	_soul.mesh = sphere
	var soul_mat := StandardMaterial3D.new()
	soul_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soul_mat.albedo_color = Color(1.0, 0.75, 0.3)
	_soul.material_override = soul_mat
	_soul.visible = false
	add_child(_soul)
	_soul_light = OmniLight3D.new()
	_soul_light.light_color = Color(1.0, 0.7, 0.3)
	_soul_light.omni_range = 2.0
	_soul.add_child(_soul_light)

	_bottle = BOTTLE.instantiate()
	(_bottle as RigidBody3D).freeze = true
	_bottle.visible = false
	add_child(_bottle)

	_camera = Camera3D.new()
	_camera.fov = 70.0 if not wide else 50.0
	add_child(_camera)
	if wide:
		_camera.look_at_from_position(Vector3(-2.4, 1.8, -3.6), Vector3(0, 1.4, -0.5))
	else:
		_camera.look_at_from_position(Vector3(0.2, 1.65, -3.0), Vector3(0, 1.25, -0.6))
	_camera.make_current()


func _make_particles(color: Color, size: float, amount: int, gravity: Vector3,
		lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = gravity
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	add_child(p)
	return p


func _process(delta: float) -> void:
	_time += delta
	var t := _time
	var hand := _hand.global_position

	var reach := _bump(t, HAND_OFF, TOSS) * 0.6 + _bump(t, TOSS, IGNITE) * 1.3 \
			+ _bump(t, BOTTLE_UP - 0.2, SET_DOWN + 0.5) * 1.0
	_puppet_arm.basis = _arm_rest * Basis(Vector3.RIGHT, reach)
	var lift := _bump(t, TOSS + 0.2, SPIRAL + 0.3) * 1.4
	_lantern_arm.basis = _lantern_rest * Basis(Vector3.RIGHT, lift)
	var look := _bump(t, TOSS, SPIRAL + 0.8) * 0.5
	_head.basis = _head_rest * Basis(Vector3.RIGHT, look)
	var jaw := 0.0
	if t > IGNITE and t < IGNITE + 0.6:
		jaw = 0.6
	elif t > SPIRAL and t < BOTTLE_UP + 0.6:
		jaw = 0.25 + 0.25 * sin(t * 40.0)
	elif t > SET_DOWN + 0.3 and t < END - 0.3:
		jaw = 0.2 + 0.2 * sin(t * 25.0)
	_jaw.basis = _jaw_rest * Basis(Vector3.RIGHT, jaw)

	if t < TOSS:
		var k := smoothstep(HAND_OFF, TOSS, t)
		_mask.global_position = _mask_start.lerp(hand + Vector3(0, 0.15, -0.1), k)
		_mask.rotation = Vector3.ZERO
	elif t < IGNITE + 0.9:
		var k := clampf((t - TOSS) / (IGNITE - TOSS), 0.0, 1.0)
		var from := hand + Vector3(0, 0.15, -0.1)
		var arc := from.lerp(APEX, 1.0 - pow(1.0 - k, 2.0))
		_mask.global_position = arc + Vector3(0, sin(t * 3.0) * 0.03, 0)
		_mask.rotation = Vector3(0, 0, (t - TOSS) * 5.0 * (1.0 - k * 0.8))
	var burn := clampf((t - IGNITE) / 0.9, 0.0, 1.0)
	_mask.visible = t < IGNITE + 0.9
	_mask.scale = Vector3.ONE * (1.0 + burn * 0.25) * (1.0 - smoothstep(0.6, 1.0, burn))
	_flare_mat.albedo_color.a = _bump(t, IGNITE - 0.05, IGNITE + 0.9) * 1.2
	_fire_light.global_position = APEX
	_fire_light.light_energy = _bump(t, IGNITE - 0.1, SPIRAL + 0.2) * 4.0
	for p: CPUParticles3D in [_embers, _shavings, _smoke]:
		p.global_position = APEX
	_embers.emitting = t > IGNITE and t < IGNITE + 0.8
	_shavings.emitting = t > IGNITE and t < IGNITE + 0.3
	_smoke.emitting = t > IGNITE + 0.4 and t < SPIRAL + 0.6

	var vial_mouth := hand + Vector3(0, 0.35, -0.05)
	_soul.visible = t > SPIRAL - 0.2 and t < BOTTLE_UP + 0.5
	if _soul.visible:
		var k := clampf((t - (SPIRAL - 0.2)) / (BOTTLE_UP + 0.5 - (SPIRAL - 0.2)), 0.0, 1.0)
		var radius := 0.5 * (1.0 - k)
		var angle := k * TAU * 2.5
		_soul.global_position = APEX.lerp(vial_mouth, k * k * (3.0 - 2.0 * k)) \
				+ Vector3(cos(angle), 0, sin(angle)) * radius
		_soul.scale = Vector3.ONE * (1.0 - k * 0.6) * (1.0 + 0.15 * sin(t * 20.0))
		_soul_light.light_energy = 1.5

	_bottle.visible = t > BOTTLE_UP
	if t > BOTTLE_UP and t < SET_DOWN:
		_bottle.global_position = hand + Vector3(0, 0.2, -0.05)
		var pop := _bump(t, BOTTLE_UP + 0.75, BOTTLE_UP + 0.9)
		_bottle.scale = Vector3(1.0 + pop * 0.2, 1.0 - pop * 0.2, 1.0 + pop * 0.2) \
				* minf(1.0, (t - BOTTLE_UP) / 0.15)
	elif t >= SET_DOWN:
		var k := clampf((t - SET_DOWN) / 0.6, 0.0, 1.0)
		var from := hand + Vector3(0, 0.2, -0.05)
		var p := from.lerp(_bottle_ground, k) + Vector3(0, sin(k * PI) * 0.4, 0)
		var bounce := absf(sin(clampf((t - SET_DOWN - 0.6) / 0.4, 0.0, 1.0) * PI)) * 0.08 \
				* (1.0 - clampf((t - SET_DOWN - 0.6) / 0.4, 0.0, 1.0))
		_bottle.global_position = p + Vector3(0, bounce, 0)
		_bottle.scale = Vector3.ONE
		_bottle.rotation.z = (1.0 - k) * 0.6

	if t > END:
		get_tree().quit()


func _bump(t: float, start: float, end: float) -> float:
	if t <= start or t >= end:
		return 0.0
	var k := (t - start) / (end - start)
	return smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
