extends Node3D

const HUMAN_BODY := preload("res://scenes/characters/human_body.tscn")
const DISSOLVE := preload("res://assets/shaders/corpse_dissolve.gdshader")

const BODY_COLOUR := Color(0.7, 0.2, 0.18)
const EMBER := Color(1.0, 0.5, 0.15)
const SAWDUST := Color(0.95, 0.8, 0.5)
const LOOT_TIME := 1.8
const EFFECT_TIME := 3.0
const TITLES := {
	"A": "A  Ember dissolve",
	"B": "B  Fall apart and sink",
	"C": "C  Fall apart into sawdust",
}

var _variant := "A"
var _body: HumanBody
var _material: ShaderMaterial
var _status: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			_variant = arg.trim_prefix("--variant=").to_upper()
	_build_world()
	_build_body()
	_build_overlay()
	_play.call_deferred()


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.14, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.5, 0.46)
	environment.ambient_light_energy = 0.4
	environment.glow_enabled = false
	environment.glow_intensity = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	plane.mesh = plane_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.32, 0.3)
	floor_material.roughness = 1.0
	plane.material_override = floor_material
	floor_body.add_child(plane)
	add_child(floor_body)

	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.9, 1.05, 1.3), Vector3(0.0, 0.1, -0.1))
	camera.current = true


func _build_body() -> void:
	_body = HUMAN_BODY.instantiate()
	_material = ShaderMaterial.new()
	_material.shader = DISSOLVE
	_material.set_shader_parameter(&"albedo", BODY_COLOUR)
	if _variant == "C":
		_material.set_shader_parameter(&"edge_color", SAWDUST)
		_material.set_shader_parameter(&"char_color", Color(0.75, 0.6, 0.38))
		_material.set_shader_parameter(&"edge_energy", 1.2)
		_material.set_shader_parameter(&"noise_scale", 14.0)
	else:
		_material.set_shader_parameter(&"edge_color", EMBER)
	_body.material = _material
	add_child(_body)
	_body.position = Vector3(0.0, 0.05, 0.0)
	_body.rotation_degrees = Vector3(0, 70, 0)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = TITLES.get(_variant, _variant)
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override(&"font_size", 30)
	title.add_theme_color_override(&"font_outline_color", Color.BLACK)
	title.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(title)
	_status = Label.new()
	_status.text = "Bandit killed, inventory: hammer, rock x2"
	_status.position = Vector2(24, 62)
	_status.add_theme_font_size_override(&"font_size", 20)
	_status.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_status.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_status)


func _play() -> void:
	_body.go_limp(null, Vector3(0.0, 0.0, -1.2))
	await get_tree().create_timer(LOOT_TIME, true, true).timeout
	_status.text = "Looted, inventory: empty"
	await get_tree().create_timer(0.4, true, true).timeout
	match _variant:
		"B":
			_fall_apart(false)
		"C":
			_fall_apart(true)
		_:
			_dissolve(EFFECT_TIME)


func _dissolve(duration: float) -> void:
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_set_progress, 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(
		Tween.TRANS_SINE
	)


func _set_progress(value: float) -> void:
	_material.set_shader_parameter(&"progress", value)


func _fall_apart(with_dissolve: bool) -> void:
	var bones: Array[PhysicalBone3D] = []
	for child in _body.physical_bones.get_children():
		if child is PhysicalBone3D:
			bones.append(child)
	for bone in bones:
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	_material.set_shader_parameter(&"split", 1.0)
	for bone in bones:
		var outward := (bone.global_position - _body.get_center())
		outward.y = 0.0
		var kick := outward.normalized() * _rng.randf_range(0.6, 1.4) + Vector3.UP * _rng.randf_range(1.2, 2.2)
		bone.apply_central_impulse(kick * bone.mass)
		bone.angular_velocity = Vector3(
			_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6)
		)
	if with_dissolve:
		await get_tree().create_timer(0.35, true, true).timeout
		_dissolve(EFFECT_TIME)
		return
	await get_tree().create_timer(1.3, true, true).timeout
	for bone in bones:
		bone.collision_layer = 0
		bone.collision_mask = 0
		bone.gravity_scale = 0.0
		bone.linear_damp = 0.0
		bone.angular_damp = 6.0
		bone.linear_velocity = Vector3.DOWN * _rng.randf_range(0.12, 0.2)
