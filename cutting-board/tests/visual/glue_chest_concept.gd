extends Node3D

## Concept B of the wood glue use, mocked up in the engine: the view tilts down to a
## cracked plank on the player's own chest, the right hand dabs glue from the pot into
## the crack, the left palm clamps the plank shut and holds, then the view comes back up.
## Mock-up only: the arms are the first-person arm meshes, moved whole by tweens in this
## scene (no elbow bend), nothing here touches the player or the glue's gameplay.
##
##   godot --path cutting-board --write-movie <out>.avi --fixed-fps 30 \
##       res://tests/visual/glue_chest_concept.tscn -- --shots=<dir>
##
## Needs a real window; stills are saved to <dir> at the key beats.

const VILLAGE := preload("res://scenes/levels/village.tscn")
const TERRAIN := preload("res://scenes/levels/valley_terrain.tscn")
const LIGHTING := preload("res://scenes/levels/lighting/tallow_fair_lighting.tscn")
const ARM_LEFT := preload("res://assets/meshes/characters/fp_arm_left.res")
const ARM_RIGHT := preload("res://assets/meshes/characters/fp_arm_right.res")
const GLUE_POT := preload("res://assets/meshes/props/wood_glue_a.res")
const MEND_OVERLAY := preload("res://scenes/ui/mend_overlay.tscn")

## Same green as the player's body material in player.tscn.
const BODY_COLOUR := Color(0.42, 0.5, 0.33)
const PLANK_COLOUR := Color(0.52, 0.37, 0.22)
## The amber of fresh glue, from mend_overlay.tscn.
const GLUE_COLOUR := Color(0.78, 0.5, 0.16)
const GLUE_RIM := Color(0.96, 0.74, 0.36)

## Eye position and the point it faces at rest (the market, as in the Monger capture).
const EYE := Vector3(1.4, 1.6, 2.8)
const FACING := Vector3(2.6, 1.4, 8.4)
## How far the view tilts down to see the chest.
const TILT_DOWN := -66.0

## Arm rest poses in body space, as the player's ArmLeftPivot/ArmRightPivot sit.
const LEFT_REST := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3(-0.7, -0.3, -0.6))
const RIGHT_REST := Transform3D(Basis(Vector3.UP, deg_to_rad(-10.0)), Vector3(0.7, -0.3, -0.6))
## The hand sits this far down the arm mesh's -Z (the HandSlot offset).
const HAND_REACH := 0.3

var _shots_dir := ""
var _body: Node3D
var _camera: Camera3D
var _arm_left: Node3D
var _arm_right: Node3D
var _glue_fill: MeshInstance3D
var _overlay: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	add_child(LIGHTING.instantiate())
	add_child(TERRAIN.instantiate())
	add_child(VILLAGE.instantiate())
	_build_body()
	_play.call_deferred()


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)
	_body.global_position = EYE
	var flat := FACING - EYE
	flat.y = 0.0
	_body.basis = Basis.looking_at(flat.normalized(), Vector3.UP)

	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.02
	_body.add_child(_camera)
	_camera.current = true

	# The torso: a box of the body's green with a plank strapped across the chest.
	var torso := _box(Vector3(0.46, 0.6, 0.24), BODY_COLOUR)
	torso.position = Vector3(0.0, -0.72, -0.15)
	torso.rotation.x = deg_to_rad(30.0)
	_body.add_child(torso)
	var plank := _box(Vector3(0.36, 0.11, 0.035), PLANK_COLOUR)
	plank.position = Vector3(0.0, 0.2, -0.13)
	torso.add_child(plank)
	var crack := _box(Vector3(0.22, 0.012, 0.01), Color(0.12, 0.08, 0.05))
	crack.position = Vector3(0.02, 0.0, -0.016)
	crack.rotation.z = deg_to_rad(-9.0)
	plank.add_child(crack)
	_glue_fill = _box(Vector3(0.22, 0.016, 0.012), GLUE_COLOUR)
	var glue_material: StandardMaterial3D = _glue_fill.material_override
	glue_material.emission_enabled = true
	glue_material.emission = GLUE_RIM
	glue_material.emission_energy_multiplier = 0.35
	glue_material.roughness = 0.2
	_glue_fill.position = crack.position + Vector3(0, 0, -0.002)
	_glue_fill.rotation.z = crack.rotation.z
	_glue_fill.scale = Vector3(0.001, 1, 1)
	plank.add_child(_glue_fill)

	_arm_left = _arm(ARM_LEFT, LEFT_REST)
	_arm_right = _arm(ARM_RIGHT, RIGHT_REST)
	var pot := MeshInstance3D.new()
	pot.mesh = GLUE_POT
	pot.position = Vector3(0.0, 0.02, -HAND_REACH - 0.02)
	pot.rotation_degrees = Vector3(-60, 0, 0)
	_arm_right.get_child(0).add_child(pot)

	# A lantern's warm light just ahead, so the chest reads at night.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	lamp.position = Vector3(0.4, 0.3, -1.2)
	_body.add_child(lamp)

	var layer := CanvasLayer.new()
	add_child(layer)
	_overlay = MEND_OVERLAY.instantiate()
	layer.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)


func _arm(mesh: Mesh, rest: Transform3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.transform = rest
	_body.add_child(pivot)
	var arm := MeshInstance3D.new()
	arm.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = BODY_COLOUR
	arm.material_override = material
	pivot.add_child(arm)
	return pivot


func _box(size: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	return mesh


## An arm pose whose hand lands on `hand` (body space), the arm reaching in from `from`.
## The mesh is rigid, so a bent elbow is faked by aiming the whole forearm.
func _reach(hand: Vector3, from: Vector3) -> Transform3D:
	var direction := (hand - from).normalized()
	var basis := Basis.looking_at(direction, Vector3.UP)
	return Transform3D(basis, hand - direction * HAND_REACH)


func _play() -> void:
	await _wait(0.6)
	await _shot("01_rest")
	var crack := Vector3(0.02, -0.47, -0.18)
	var dab_at := _reach(crack + Vector3(0.0, 0.0, -0.06), Vector3(0.45, -0.95, -0.55))
	var dab_in := _reach(crack + Vector3(0.0, 0.0, -0.03), Vector3(0.45, -0.95, -0.55))
	var clamp_at := _reach(crack + Vector3(-0.02, 0.02, -0.07), Vector3(-0.5, -0.85, -0.6))
	var clamp_in := _reach(crack + Vector3(-0.02, 0.02, -0.04), Vector3(-0.5, -0.85, -0.6))
	var right_aside := _reach(Vector3(0.3, -0.45, -0.35), Vector3(0.6, -0.9, -0.6))

	# 0.0-0.5 s: tilt down, pot comes up to the crack (pop).
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "rotation_degrees:x", TILT_DOWN, 0.5)
	tween.parallel().tween_property(_arm_right, "transform", dab_at, 0.5)
	await tween.finished
	await _shot("02_tilted")

	# 0.5-1.3 s: two dabs, the glue fills the crack.
	for i in 2:
		tween = create_tween().set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_arm_right, "transform", dab_in, 0.15).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_glue_fill, "scale:x", 0.5 + 0.5 * i, 0.15)
		tween.tween_property(_arm_right, "transform", dab_at, 0.25).set_ease(Tween.EASE_IN_OUT)
		if i == 0:
			await get_tree().create_timer(0.15).timeout
			await _shot("03_dab")
		await tween.finished

	# 1.3-1.6 s: pot away, the left palm comes in and clamps (creak).
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_arm_right, "transform", right_aside, 0.3)
	tween.parallel().tween_property(_arm_left, "transform", clamp_at, 0.3)
	tween.tween_property(_arm_left, "transform", clamp_in, 0.1)
	await tween.finished

	# 1.6-2.3 s: hold the clamp, two knocks of pressure; heal lands at the end (glow).
	await _shot("04_clamp")
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	for i in 2:
		tween.tween_property(_arm_left, "transform", clamp_in.translated_local(Vector3(0, 0, -0.012)), 0.12)
		tween.tween_property(_arm_left, "transform", clamp_in, 0.23)
	await tween.finished
	_overlay.set("_glow", 0.45)
	_overlay.call("_apply")
	await _shot("05_heal")

	# 2.3-2.8 s: arms drop back, view comes up.
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "rotation_degrees:x", 0.0, 0.5)
	tween.parallel().tween_property(_arm_left, "transform", LEFT_REST, 0.5)
	tween.parallel().tween_property(_arm_right, "transform", RIGHT_REST, 0.5)
	await tween.finished
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
