extends Node3D

@export var direction := Vector3(0.45, 0.3, -0.85):
	set(value):
		direction = value
		if is_node_ready():
			aim_light_from_moon()
@export var distance := 320.0
@export var size := 60.0
@export var eye_distance := 140.0
@export var gaze_gain := 1.5
@export var max_pupil_offset := 0.55
@export var follow_speed := 0.6
@export_range(0.0, 1.0) var look_along := 0.15
@export var light: DirectionalLight3D

@onready var _quad: MeshInstance3D = %MoonQuad

var _gaze := Vector2.ZERO


func _ready() -> void:
	aim_light_from_moon()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_moon := direction.normalized()
	global_position = camera.global_position + to_moon * distance
	look_at(camera.global_position, Vector3.UP, true)
	_quad.scale = Vector3.ONE * size

	var right := to_moon.cross(Vector3.UP).normalized()
	var up := right.cross(to_moon).normalized()
	var eye := to_moon * eye_distance
	var gaze := (camera.global_position - eye).normalized()
	var target := Vector2(gaze.dot(right), gaze.dot(up)) * gaze_gain
	var look := -camera.global_basis.z
	target += Vector2(look.dot(right), look.dot(up)) * look_along
	target = target.limit_length(max_pupil_offset)
	_gaze = _gaze.lerp(target, clampf(follow_speed * delta, 0.0, 1.0))
	var material := _quad.get_active_material(0) as ShaderMaterial
	if material:
		material.set_shader_parameter(&"pupil_offset", Vector2(_gaze.x, -_gaze.y))


func aim_light_from_moon() -> void:
	if light == null:
		return
	var to_moon := direction.normalized()
	light.global_basis = Basis.looking_at(-to_moon, Vector3.UP)
