extends Node3D

## Kick animation concept: three ways the Q kick could look, played on a primitive wooden
## puppet kicking a barrel. Each kick alternates between the first-person view and a side
## view of the same puppet. Concept only; see docs/concepts/kick-animation.md.
##
##   godot --path cutting-board --write-movie <out>.avi --fixed-fps 30 --resolution 960x540
##       --quit-after 150 res://tests/visual/kick_animation_concept.tscn -- --option=a
##
## --option=a  front snap kick: the boot swings up into view from below.
## --option=b  push kick (stomp): knee chambers high, flat boot thrusts, camera dips and recoils.
## --option=c  side kick: hips turn, the leg shoots out sideways, the view rolls with it.

const BARREL_MESH := preload("res://scenes/environment/decoration/barrel_1.tscn")

## Matches Kick.windup: seconds from the press to the strike frame.
const WINDUP := 0.15
## Seconds between kicks in the loop.
const CYCLE := 1.25
## Barrel spot in front of the puppet.
const BARREL_AT := Vector3(0.0, 0.45, -1.15)

## Keyframes per option: [time, hip pitch, knee bend, hip yaw, hip roll, body yaw,
## camera pitch, camera back offset, camera roll]. Angles in degrees, offset in metres.
## Hip pitch swings the leg forward; knee bend folds the shin back; hip roll swings it
## out to the side.
const POSES := {
	"a": [
		[0.00, 0, 0, 0, 0, 0, 0, 0.0, 0],
		[0.10, 35, -95, 0, 0, 0, 0, 0.0, 0],      # knee lifts, shin folded
		[0.15, 78, -8, 0, 0, 0, 2, -0.04, 0],     # strike: shin snaps straight
		[0.22, 82, -5, 0, 0, 0, 1, -0.03, 0],     # follow-through
		[0.38, 30, -70, 0, 0, 0, 0, 0.0, 0],      # rechamber
		[0.55, 0, 0, 0, 0, 0, 0, 0.0, 0],
	],
	"b": [
		[0.00, 0, 0, 0, 0, 0, 0, 0.0, 0],
		[0.11, 95, -120, 0, 0, 0, 6, 0.06, 0],    # chamber: knee to chest, lean back
		[0.15, 70, -10, 0, 0, 0, -7, -0.10, 0],   # strike: flat boot thrust, lunge + dip
		[0.25, 68, -12, 0, 0, 0, -3, 0.05, 0],    # recoil: pushed back off the barrel
		[0.42, 35, -60, 0, 0, 0, 0, 0.0, 0],
		[0.60, 0, 0, 0, 0, 0, 0, 0.0, 0],
	],
	"c": [
		[0.00, 0, 0, 0, 0, 0, 0, 0.0, 0],
		[0.10, 60, -110, 0, 15, 50, 0, 0.0, 8],   # turn hips, chamber across
		[0.15, 15, -5, 0, 80, 85, -2, -0.05, 14], # strike: leg out sideways, view rolls
		[0.24, 12, -8, 0, 78, 85, -1, -0.03, 12],
		[0.42, 40, -80, 0, 20, 40, 0, 0.0, 4],
		[0.62, 0, 0, 0, 0, 0, 0, 0.0, 0],
	],
}

var _option := "a"
var _time := 0.0
var _kick_index := 0
var _struck := false

var _body: Node3D
var _hip: Node3D
var _knee: Node3D
var _head: Node3D
var _fp_camera: Camera3D
var _side_camera: Camera3D
var _barrel: RigidBody3D
var _label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--option="):
			_option = arg.trim_prefix("--option=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	_build_stage()
	_build_puppet()
	_reset_barrel()
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	layer.add_child(_label)
	_time = -0.4


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= CYCLE:
		_time -= CYCLE
		_kick_index += 1
		_struck = false
		_reset_barrel()
	var first_person := _kick_index % 2 == 0
	(_fp_camera if first_person else _side_camera).make_current()
	_label.text = "%s  —  %s" % [_title(), "first person" if first_person else "side view"]
	_apply_pose(_sample(maxf(_time, 0.0)))
	if not _struck and _time >= WINDUP:
		_struck = true
		_strike()


func _title() -> String:
	match _option:
		"b": return "B  push kick (stomp)"
		"c": return "C  side kick"
	return "A  front snap kick"


func _sample(t: float) -> Array:
	var keys: Array = POSES[_option]
	if t >= keys[-1][0]:
		return keys[-1].slice(1)
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var w := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			var out := []
			for j in range(1, a.size()):
				out.append(lerpf(a[j], b[j], w))
			return out
	return keys[0].slice(1)


func _apply_pose(p: Array) -> void:
	_hip.rotation_degrees = Vector3(p[0], p[2], p[3])
	_knee.rotation_degrees = Vector3(p[1], 0, 0)
	_body.rotation_degrees.y = p[4]
	# The camera keeps looking at the barrel while the hips turn; only the extra
	# pitch, push and roll of the kick reach the view.
	_head.rotation_degrees = Vector3(-24.0 + p[5], -p[4] * 0.8, -p[7])
	_head.position = Vector3(0, 1.6, 0) + Vector3(0, 0, p[6]).rotated(Vector3.UP, deg_to_rad(-p[4] * 0.8))


func _strike() -> void:
	var dir := Vector3(0, 0, -1)
	if _option == "c":
		dir = Vector3(-0.15, 0, -1)
	var push := dir.normalized() * 6.5 + Vector3.UP * 2.2
	_barrel.apply_impulse(push * _barrel.mass, Vector3(0, 0.1, 0.3))


func _reset_barrel() -> void:
	if _barrel:
		_barrel.queue_free()
	_barrel = RigidBody3D.new()
	_barrel.mass = 40.0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 0.9
	cyl.radius = 0.475
	shape.shape = cyl
	_barrel.add_child(shape)
	var mesh := BARREL_MESH.instantiate()
	mesh.position.y = -0.45
	_barrel.add_child(mesh)
	_barrel.position = BARREL_AT
	add_child(_barrel)


func _wood(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, layer := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = _wood(color)
	mi.layers = layer
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _build_puppet() -> void:
	var light_wood := Color(0.78, 0.6, 0.4)
	var dark_wood := Color(0.5, 0.34, 0.2)
	var leather := Color(0.25, 0.16, 0.1)
	_body = Node3D.new()
	add_child(_body)
	# Layer 2 parts are hidden from the first-person camera, like the player's own body.
	var torso := BoxMesh.new()
	torso.size = Vector3(0.38, 0.55, 0.22)
	_part(_body, torso, Vector3(0, 1.22, 0), light_wood, 2)
	var pelvis := BoxMesh.new()
	pelvis.size = Vector3(0.34, 0.16, 0.2)
	_part(_body, pelvis, Vector3(0, 0.9, 0), dark_wood, 2)
	var head_ball := SphereMesh.new()
	head_ball.radius = 0.13
	head_ball.height = 0.28
	_part(_body, head_ball, Vector3(0, 1.62, 0), light_wood, 2)
	for side in [-1.0, 1.0]:
		_part(_body, _capsule(0.045, 0.6), Vector3(0.24 * side, 1.18, 0), light_wood, 2)
	# Standing leg.
	_part(_body, _capsule(0.06, 0.48), Vector3(-0.1, 0.64, 0), light_wood)
	_part(_body, _capsule(0.05, 0.46), Vector3(-0.1, 0.24, 0), light_wood)
	var boot := BoxMesh.new()
	boot.size = Vector3(0.12, 0.09, 0.26)
	_part(_body, boot, Vector3(-0.1, 0.045, -0.05), leather)
	# Kicking leg: hip pivot, thigh, knee pivot, shin, boot.
	_hip = Node3D.new()
	_hip.position = Vector3(0.1, 0.86, 0)
	_body.add_child(_hip)
	_part(_hip, _capsule(0.06, 0.48), Vector3(0, -0.22, 0), light_wood)
	_knee = Node3D.new()
	_knee.position = Vector3(0, -0.42, 0)
	_hip.add_child(_knee)
	_part(_knee, SphereMesh.new(), Vector3.ZERO, dark_wood).scale = Vector3.ONE * 0.13
	_part(_knee, _capsule(0.05, 0.46), Vector3(0, -0.2, 0), light_wood)
	_part(_knee, boot, Vector3(0, -0.4, -0.05), leather)

	_head = Node3D.new()
	_body.add_child(_head)
	_fp_camera = Camera3D.new()
	_fp_camera.fov = 75.0
	_fp_camera.near = 0.05
	_fp_camera.cull_mask = 1
	_head.add_child(_fp_camera)
	_side_camera = Camera3D.new()
	_side_camera.fov = 50.0
	add_child(_side_camera)
	_side_camera.position = Vector3(3.2, 1.1, -0.6)
	_side_camera.look_at(Vector3(0, 0.75, -0.7), Vector3.UP)


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.68, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	_part(ground, plane, Vector3.ZERO, Color(0.36, 0.42, 0.25))
	add_child(ground)
