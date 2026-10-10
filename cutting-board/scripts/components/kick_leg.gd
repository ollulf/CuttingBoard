class_name KickLeg
extends Node3D

## The first-person leg of the kick: a side kick (docs/concepts/kick-animation.md, option
## C). The knee comes up across from the lower right, the leg shoots out with the boot
## turned edge-on and the view rolls with the hips, then everything settles back. Sits
## under the camera next to the arms; the leg is only drawn while a kick plays.
##
## Like the arms, the motion is an Animation on an AnimationPlayer, with a method track
## at the strike frame. It is built here from the KEYS table rather than kept in a .tres,
## so the pose numbers sit next to the rig they move. play_kick() stretches it so the
## strike frame lands on the Kick's own strike frame, `windup` after the press.
##
## The roll is purely visual: the player adds view_roll to the camera's z rotation, and a
## roll about the camera's own sight line leaves the crosshair direction, and with it the
## kick's aim, exactly as it was.

## Fired from the animation's method track on the strike frame.
signal struck

## Seconds into the animation the boot lands; KEYS are timed for this.
const STRIKE_TIME := 0.15
## Keyframes: [time, hip pitch, hip yaw, hip roll, knee bend, boot twist, roll weight].
## Angles in degrees in the camera's space (-Z ahead, the leg hanging down -Y at rest);
## the roll weight scales view_roll_degrees.
const KEYS := [
	[0.00, 0, 0, 0, 0, 0, 0.0],
	[0.10, 95, -30, 10, -120, 40, 0.6],      # chamber: knee up across from the lower right
	[0.15, 118, 9, 0, -4, 80, 1.0],          # strike: leg out, boot edge-on, view rolled
	[0.24, 114, 8, 0, -8, 80, 0.8],          # hold on the target
	[0.40, 60, -25, 5, -90, 40, 0.2],        # rechamber; the roll is nearly back
	[0.58, 0, 0, 0, 0, 0, 0.0],
]
const ANIMATION := &"kick_side"

## How far the view rolls at the strike, in degrees. Round 1's prototype used 14; 10 keeps
## the hip turn readable without tipping the horizon too far.
@export var view_roll_degrees := 10.0
## Where the hip sits relative to the camera: low, a little right and behind the eye.
@export var hip_offset := Vector3(0.2, -0.7, 0.05)
@export var thigh_length := 0.46
@export var shin_length := 0.44
## The leg's cloth; the player gives it the arms' body material.
@export var material: Material
@export var boot_material: Material

## Radians of camera roll the animation asks for right now; the player adds it to the
## camera's z rotation.
var view_roll := 0.0
## Weight of the roll curve, animated by the kick and turned into view_roll.
var roll_weight := 0.0:
	set(value):
		roll_weight = value
		view_roll = deg_to_rad(view_roll_degrees) * value

var _player: AnimationPlayer
var _hip: Node3D
var _knee: Node3D
var _ankle: Node3D


func _ready() -> void:
	_build_rig()
	_player = AnimationPlayer.new()
	_player.name = "LegPlayer"
	add_child(_player)
	_player.root_node = NodePath("..")
	# Stepped with physics, like the Kick's own windup, so the strike frames agree.
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var library := AnimationLibrary.new()
	library.add_animation(ANIMATION, _build_animation())
	_player.add_animation_library(&"", library)
	_player.animation_finished.connect(_on_finished.unbind(1))
	visible = false


## Plays the side kick so its strike frame lands `windup` seconds from now.
func play_kick(windup: float) -> void:
	_player.speed_scale = STRIKE_TIME / maxf(windup, 0.01)
	_player.stop()
	_player.play(ANIMATION)
	visible = true


func is_playing() -> bool:
	return _player.is_playing()


## Called from the animation's method track on the strike frame.
func emit_strike() -> void:
	struck.emit()


func _on_finished() -> void:
	visible = false
	roll_weight = 0.0


func _build_rig() -> void:
	if material == null:
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = Color(0.42, 0.5, 0.33)
		material = cloth
	if boot_material == null:
		var leather := StandardMaterial3D.new()
		leather.albedo_color = Color(0.25, 0.16, 0.1)
		leather.roughness = 0.9
		boot_material = leather
	_hip = Node3D.new()
	_hip.name = "Hip"
	_hip.position = hip_offset
	add_child(_hip)
	_part(_hip, _capsule(0.075, thigh_length + 0.1), Vector3(0, -thigh_length * 0.5, 0), material)
	_knee = Node3D.new()
	_knee.name = "Knee"
	_knee.position = Vector3(0, -thigh_length, 0)
	_hip.add_child(_knee)
	_part(_knee, _capsule(0.06, shin_length + 0.08), Vector3(0, -shin_length * 0.5, 0), material)
	_ankle = Node3D.new()
	_ankle.name = "Ankle"
	_ankle.position = Vector3(0, -shin_length, 0)
	_knee.add_child(_ankle)
	var boot := BoxMesh.new()
	boot.size = Vector3(0.13, 0.11, 0.29)
	_part(_ankle, boot, Vector3(0, -0.04, -0.06), boot_material)


func _part(parent: Node3D, mesh: Mesh, at: Vector3, part_material: Material) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = part_material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	return capsule


func _build_animation() -> Animation:
	var animation := Animation.new()
	animation.length = KEYS[-1][0]
	var hip := _track(animation, Animation.TYPE_ROTATION_3D, "Hip")
	var knee := _track(animation, Animation.TYPE_ROTATION_3D, "Hip/Knee")
	var ankle := _track(animation, Animation.TYPE_ROTATION_3D, "Hip/Knee/Ankle")
	var roll := _track(animation, Animation.TYPE_VALUE, ".:roll_weight")
	for key: Array in KEYS:
		var time: float = key[0]
		var hip_euler := Vector3(key[1], key[2], key[3]) * (PI / 180.0)
		animation.rotation_track_insert_key(hip, time, Quaternion.from_euler(hip_euler))
		animation.rotation_track_insert_key(knee, time, Quaternion(Vector3.RIGHT, deg_to_rad(key[4])))
		animation.rotation_track_insert_key(ankle, time, Quaternion(Vector3.UP, deg_to_rad(key[5])))
		animation.track_insert_key(roll, time, float(key[6]))
	var method := _track(animation, Animation.TYPE_METHOD, ".")
	animation.track_insert_key(method, STRIKE_TIME, {"method": &"emit_strike", "args": []})
	return animation


func _track(animation: Animation, type: Animation.TrackType, path: String) -> int:
	var track := animation.add_track(type)
	animation.track_set_path(track, NodePath(path))
	if type != Animation.TYPE_METHOD:
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track
