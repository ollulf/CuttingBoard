extends Node3D

const VILLAGE := preload("res://scenes/levels/village.tscn")
const TERRAIN := preload("res://scenes/levels/valley_terrain.tscn")
const LIGHTING := preload("res://scenes/levels/lighting/tallow_fair_lighting.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const GLUE_POT := preload("res://assets/meshes/props/wood_glue_a.res")
const MEND_OVERLAY := preload("res://scenes/ui/mend_overlay.tscn")
const ANIM_LIBRARY := "res://tests/visual/glue_use_concept_anims.tres"
const ANIM_NAME := &"use_glue_both"

const BODY_COLOUR := Color(0.42, 0.5, 0.33)
const PLANK_COLOUR := Color(0.52, 0.37, 0.22)
const GLUE_COLOUR := Color(0.95, 0.68, 0.28)
const GLUE_RIM := Color(1.0, 0.82, 0.45)

const EYE := Vector3(1.4, 1.6, 2.8)
const FACING := Vector3(2.6, 1.4, 8.4)
const TILT_DOWN := -62.0

const UPPER_LENGTH := 0.345
const LOWER_LENGTH := 0.3
const UPPER_REST := Vector3(0.0, 0.0, 0.345)
const IDLE_POSE := [Quaternion(0, 0, 0, 1), Quaternion(0.05996, 0, 0, 0.9982), Quaternion(-0.04, 0, 0, 0.9992)]

var _shots_dir := ""
var _save_library := false
var _player: Node3D
var _camera: Camera3D
var _arms: Node3D
var _plank: Node3D
var _crack: Node3D
var _glue_fill: MeshInstance3D
var _overlay: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--save-library":
			_save_library = true
	add_child(LIGHTING.instantiate())
	add_child(TERRAIN.instantiate())
	add_child(VILLAGE.instantiate())
	_build_player()
	_play.call_deferred()


func _build_player() -> void:
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = EYE - Vector3(0.0, 1.6, 0.0)
	var flat := FACING - EYE
	flat.y = 0.0
	_player.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	_camera = _player.get_node("%Camera3D")
	_camera.current = true
	_arms = _player.get_node("%Arms")
	var pivot: Node3D = _player.get_node("%CameraPivot")

	var torso := _box(Vector3(0.46, 0.6, 0.24), BODY_COLOUR)
	torso.position = Vector3(0.0, -0.72, -0.15)
	torso.rotation.x = deg_to_rad(50.0)
	pivot.add_child(torso)
	_plank = _box(Vector3(0.36, 0.11, 0.035), PLANK_COLOUR)
	_plank.position = Vector3(0.0, 0.2, -0.13)
	torso.add_child(_plank)
	_crack = _box(Vector3(0.22, 0.014, 0.01), Color(0.1, 0.06, 0.04))
	_crack.position = Vector3(0.02, 0.0, -0.016)
	_crack.rotation.z = deg_to_rad(-9.0)
	_plank.add_child(_crack)
	_glue_fill = _box(Vector3(0.22, 0.02, 0.012), GLUE_COLOUR)
	var glue_material: StandardMaterial3D = _glue_fill.material_override
	glue_material.emission_enabled = true
	glue_material.emission = GLUE_RIM
	glue_material.emission_energy_multiplier = 1.1
	glue_material.roughness = 0.15
	_glue_fill.position = _crack.position + Vector3(0, 0, -0.003)
	_glue_fill.rotation.z = _crack.rotation.z
	_glue_fill.scale = Vector3(0.001, 1, 1)
	_plank.add_child(_glue_fill)

	var pot := MeshInstance3D.new()
	pot.mesh = GLUE_POT
	pot.position = Vector3(0.0, -0.03, 0.0)
	pot.rotation_degrees = Vector3(-90, 0, 0)
	_player.get_node("%HandSlotRight").add_child(pot)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	lamp.position = Vector3(0.4, -0.3, -1.0)
	pivot.add_child(lamp)

	var layer := CanvasLayer.new()
	add_child(layer)
	_overlay = MEND_OVERLAY.instantiate()
	layer.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)


func _box(size: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	return mesh


func _build_animation() -> Animation:
	_camera.rotation.x = deg_to_rad(TILT_DOWN)
	var to_world := _plank.global_transform
	var crack := _crack.position
	var aside := Vector3(0.22, -0.08, -0.16)
	var keys := [
		[0.0, null, 0.0, null, 0.0, 0.0],
		[0.5, Vector3(0.0, 0.0, -0.12), 25.0, null, 0.0, TILT_DOWN],
		[0.65, Vector3(0.0, 0.0, -0.075), 40.0, null, 0.0, TILT_DOWN],
		[0.9, Vector3(0.03, 0.0, -0.12), 25.0, null, 0.0, TILT_DOWN],
		[1.05, Vector3(0.05, 0.0, -0.075), 40.0, null, 0.0, TILT_DOWN],
		[1.3, Vector3(0.05, 0.0, -0.12), 25.0, null, 0.0, TILT_DOWN],
		[1.6, aside, 10.0, Vector3(0.05, 0.0, -0.09), 55.0, TILT_DOWN],
		[1.72, aside, 10.0, Vector3(0.05, 0.0, -0.045), 70.0, TILT_DOWN],
		[1.84, aside, 10.0, Vector3(0.05, 0.0, -0.035), 72.0, TILT_DOWN],
		[2.07, aside, 10.0, Vector3(0.05, 0.0, -0.045), 70.0, TILT_DOWN],
		[2.19, aside, 10.0, Vector3(0.05, 0.0, -0.035), 72.0, TILT_DOWN],
		[2.3, aside, 10.0, Vector3(0.05, 0.0, -0.045), 70.0, TILT_DOWN],
		[2.8, null, 0.0, null, 0.0, 0.0],
	]
	var animation := Animation.new()
	animation.length = 2.8
	animation.step = 0.01
	var tilt := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(tilt, NodePath("..:rotation:x"))
	animation.track_set_interpolation_type(tilt, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		animation.track_insert_key(tilt, key[0], deg_to_rad(key[5]))
	for side in ["Left", "Right"]:
		var skeleton: Skeleton3D = _player.get_node("%%Arm%sSkeleton" % side)
		var base := "Arm%sPivot/Arm%sSkeleton:" % [side, side]
		var tracks := []
		for bone in ["UpperArm", "Forearm", "Hand"]:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(base + bone))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
			tracks.append(track)
		var cut_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(cut_track, NodePath(base + "UpperArm"))
		animation.track_set_interpolation_type(cut_track, Animation.INTERPOLATION_CUBIC)
		var outward := -1.0 if side == "Left" else 1.0
		var to_skeleton := skeleton.global_transform.affine_inverse()
		var reach_cut := UPPER_REST + Vector3(-outward * 0.25, -0.15, 0.05)
		for key in keys:
			var target = key[3] if side == "Left" else key[1]
			var wrist: float = key[4] if side == "Left" else key[2]
			var pose: Array = IDLE_POSE
			var cut := UPPER_REST
			if target != null:
				cut = reach_cut
				pose = _reach(cut, to_skeleton * (to_world * (crack + target)), Vector3(outward, 0.0, -1.0), wrist)
			animation.position_track_insert_key(cut_track, key[0], cut)
			for i in 3:
				animation.rotation_track_insert_key(tracks[i], key[0], pose[i])
	_camera.rotation.x = 0.0
	return animation


func _reach(cut: Vector3, palm: Vector3, hint: Vector3, wrist: float) -> Array:
	var to_palm := palm - cut
	var distance := clampf(to_palm.length(), 0.05, UPPER_LENGTH + LOWER_LENGTH - 0.01)
	var along := to_palm.normalized()
	var cos_shoulder := (UPPER_LENGTH * UPPER_LENGTH + distance * distance - LOWER_LENGTH * LOWER_LENGTH) \
			/ (2.0 * UPPER_LENGTH * distance)
	var shoulder := acos(clampf(cos_shoulder, -1.0, 1.0))
	var bend := (hint - along * hint.dot(along)).normalized()
	var elbow := cut + UPPER_LENGTH * (along * cos(shoulder) + bend * sin(shoulder))
	var upper := Basis.looking_at(elbow - cut, Vector3.UP)
	var fore := Basis.looking_at(cut + along * distance - elbow, Vector3.UP)
	return [
		upper.get_rotation_quaternion(),
		(upper.inverse() * fore).get_rotation_quaternion(),
		Quaternion(Vector3.RIGHT, deg_to_rad(wrist)),
	]


func _play() -> void:
	var library := AnimationLibrary.new()
	library.add_animation(ANIM_NAME, _build_animation())
	if _save_library:
		ResourceSaver.save(library, ANIM_LIBRARY)
	var anim_player := AnimationPlayer.new()
	anim_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_arms.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	anim_player.add_animation_library(&"concept", library)

	await _wait(0.6)
	await _shot("01_rest")
	anim_player.play(&"concept/" + ANIM_NAME)
	await _wait(0.5)
	await _shot("02_tilted")
	await _wait(0.15)
	create_tween().tween_property(_glue_fill, "scale:x", 0.55, 0.15)
	await _wait(0.05)
	await _shot("03_dab")
	await _wait(0.35)
	create_tween().tween_property(_glue_fill, "scale:x", 1.0, 0.15)
	await _wait(0.75)
	await _shot("04_clamp")
	await _wait(0.25)
	_overlay.set("_glow", 0.45)
	_overlay.call("_apply")
	await _shot("05_heal")
	await anim_player.animation_finished
	await _wait(0.6)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("%s.png" % shot_name))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
