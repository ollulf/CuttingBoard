extends Node3D

## The moon that watches. It is a billboard kept at a fixed direction and distance from
## the camera, so it hangs in the sky like a real moon and never gets closer, but it is
## drawn with depth so trees and hills pass in front of it.
##
## Its pupil looks at the player from an imagined eye `eye_distance` out along the same
## direction from the world origin. Walk across the valley and the eye turns to follow,
## slowly, a little behind; stand in the middle of the village and it stares straight
## at you.
##
## The moon light (a DirectionalLight3D) is aimed along the same direction by
## aim_light_from_moon(), so moonlight falls from where the moon is drawn.

## Direction from the viewer to the moon. Need not be normalised.
@export var direction := Vector3(0.45, 0.3, -0.85):
	set(value):
		direction = value
		if is_node_ready():
			aim_light_from_moon()
## How far from the camera the moon is drawn, in metres. Beyond the terrain, so
## everything in the level can pass in front of it.
@export var distance := 320.0
## Edge length of the moon's quad, in metres at `distance`.
@export var size := 60.0
## Where the imagined eye sits, in metres from the world origin along `direction`. Closer
## makes the pupil swing further as the player walks.
@export var eye_distance := 140.0
## Multiplies how far the pupil moves for a given turn of the gaze.
@export var gaze_gain := 1.5
## How far the pupil can move off centre, in disc radii.
@export var max_pupil_offset := 0.55
## How quickly the gaze catches up with the player; small values make it lag and creep.
@export var follow_speed := 0.6
## Extra pull of the pupil towards whatever the player looks at, 0..1; it seems to try
## to see what you see.
@export_range(0.0, 1.0) var look_along := 0.15
## The light to keep aimed from the moon, if any.
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
	# Face the camera, upright.
	look_at(camera.global_position, Vector3.UP, true)
	_quad.scale = Vector3.ONE * size

	# The pupil's frame: right and up across the moon's face as the viewer sees it.
	var right := to_moon.cross(Vector3.UP).normalized()
	var up := right.cross(to_moon).normalized()
	# Gazing straight back down the moon's direction, at the world origin, is the centre
	# of the disc; any sideways part of the gaze moves the pupil that way.
	var eye := to_moon * eye_distance
	var gaze := (camera.global_position - eye).normalized()
	var target := Vector2(gaze.dot(right), gaze.dot(up)) * gaze_gain
	var look := -camera.global_basis.z
	target += Vector2(look.dot(right), look.dot(up)) * look_along
	target = target.limit_length(max_pupil_offset)
	_gaze = _gaze.lerp(target, clampf(follow_speed * delta, 0.0, 1.0))
	var material := _quad.get_active_material(0) as ShaderMaterial
	if material:
		# UV y runs down the quad.
		material.set_shader_parameter(&"pupil_offset", Vector2(_gaze.x, -_gaze.y))


## Points `light` so that it shines from the moon's direction.
func aim_light_from_moon() -> void:
	if light == null:
		return
	var to_moon := direction.normalized()
	# A light shines along its -Z; looking_at aims -Z at the target.
	light.global_basis = Basis.looking_at(-to_moon, Vector3.UP)
