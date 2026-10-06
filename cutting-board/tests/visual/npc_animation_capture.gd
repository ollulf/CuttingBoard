extends Node3D

## Frame captures of NPC body animation: walk and run cycles seen from the side, idle
## gestures, a crowd idling out of step, a bandit holding its hammer, and a flinch and a
## death landing on a moving body. Each stage is saved as single frames plus a strip of
## them side by side, on a chequered floor whose half-metre squares show whether feet
## slide.
##
##   godot --path cutting-board res://tests/visual/npc_animation_capture.tscn -- --shots=<dir>
##
## --static switches every BodyAnimator off, which is how NPCs looked before they had
## one. --only=<name>,<name> runs just the stages whose names contain those. Needs a
## real window; under --headless it only runs the stages, which still catches errors.

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

## Width of the slice of each frame that goes into a strip, as a share of the frame.
const STRIP_SLICE := 0.34
const STRIP_HEIGHT := 360

var _shots_dir := ""
var _only: PackedStringArray = []
var _static := false
var _camera: Camera3D
var _follow: Node3D
var _follow_offset := Vector3.ZERO
var _npcs: Array[Npc] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--static":
			_static = true
	PsxScreen.enabled = false
	_build_stage()
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _follow and is_instance_valid(_follow):
		var at := Vector3(_follow.global_position.x, 0.0, _follow.global_position.z)
		_camera.global_position = at + _follow_offset
		_camera.look_at(at + Vector3.UP * 0.9, Vector3.UP)


func _run() -> void:
	await _wait(0.5)
	if _wants("walk"):
		await _cycle("walk", false)
	if _wants("run"):
		await _cycle("run", true)
	if _wants("idle_look"):
		await _idle("idle_look", BodyAnimator.Gesture.LOOK_AROUND, 12, 0.35)
	if _wants("idle_hand"):
		await _idle("idle_hand", BodyAnimator.Gesture.INSPECT_HAND, 8, 0.4)
	if _wants("idle_down"):
		await _idle("idle_down", BodyAnimator.Gesture.LOOK_DOWN, 6, 0.4)
	if _wants("crowd"):
		await _crowd()
	if _wants("bandit"):
		await _bandit()
	if _wants("flinch"):
		await _flinch()
	if _wants("death"):
		await _death()
	get_tree().quit()


# --- Stages -----------------------------------------------------------------------------


## Walks or runs a villager along +X and photographs one stride from the side.
func _cycle(stage: String, run: bool) -> void:
	var npc := _spawn(VILLAGER, Vector3(-20, 0, 0), Vector3(1, 0, 0))
	npc.locomotion.move_to(Vector3(60, 0, 0), run)
	_follow_camera(npc, Vector3(0.0, 1.0, 3.6))
	await _wait(1.5)
	var frames: Array[Image] = []
	for i in 10:
		frames.append(await _shot("%s_%02d" % [stage, i]))
		await _wait(0.06)
	_strip(stage, frames)
	_clear()


## Stands a villager facing the camera and plays one idle gesture.
func _idle(stage: String, gesture: BodyAnimator.Gesture, count: int, spacing: float) -> void:
	var npc := _spawn(VILLAGER, Vector3.ZERO, Vector3(0, 0, 1))
	_fixed_camera(Vector3(0.9, 1.45, 2.3), Vector3(0, 1.15, 0))
	await _wait(0.8)
	_animator(npc).play_gesture(gesture)
	var frames: Array[Image] = []
	for i in count:
		frames.append(await _shot("%s_%02d" % [stage, i]))
		if i == count / 2:
			_report_head(npc, stage)
		await _wait(spacing)
	_strip(stage, frames, 0.42)
	_clear()


## Five villagers left to their own idling, which should never line up.
func _crowd() -> void:
	for i in 5:
		_spawn(VILLAGER, Vector3(-2.4 + i * 1.2, 0, 0), Vector3(0, 0, 1))
	_fixed_camera(Vector3(0, 1.6, 4.6), Vector3(0, 1.0, 0))
	for i in 4:
		await _wait(1.5)
		await _shot("crowd_%02d" % i)
	_clear()


## A bandit holding its hammer: standing, then walking.
func _bandit() -> void:
	var npc := _spawn(BANDIT, Vector3.ZERO, Vector3(0, 0, 1))
	_fixed_camera(Vector3(1.4, 1.4, 2.0), Vector3(0, 1.0, 0))
	await _wait(1.2)
	await _shot("bandit_stand")
	_clear()
	npc = _spawn(BANDIT, Vector3(-20, 0, 0), Vector3(1, 0, 0))
	npc.locomotion.move_to(Vector3(60, 0, 0))
	_follow_camera(npc, Vector3(0.6, 1.0, 3.2))
	await _wait(1.5)
	var frames: Array[Image] = []
	for i in 8:
		frames.append(await _shot("bandit_walk_%02d" % i))
		await _wait(0.07)
	_strip("bandit_walk", frames)
	_clear()


## A walking villager struck on the shoulder: the flinch plays over the walk and the
## stride picks up again once it has eased off.
func _flinch() -> void:
	var npc := _spawn(VILLAGER, Vector3(-20, 0, 0), Vector3(1, 0, 0))
	npc.locomotion.move_to(Vector3(60, 0, 0))
	_follow_camera(npc, Vector3(0.0, 1.0, 3.6))
	await _wait(1.5)
	var frames: Array[Image] = []
	frames.append(await _shot("flinch_00"))
	_hit(npc, 1.35, Vector3(0, 0, -1), 5, 12.0)
	for i in range(1, 10):
		await _wait(0.1)
		frames.append(await _shot("flinch_%02d" % i))
	_strip("flinch", frames)
	_clear()


## A running bandit killed mid-stride: the animation lets go and the ragdoll falls.
func _death() -> void:
	var npc := _spawn(BANDIT, Vector3(-20, 0, 0), Vector3(1, 0, 0))
	npc.locomotion.move_to(Vector3(60, 0, 0), true)
	_follow_camera(npc, Vector3(0.0, 1.0, 4.2))
	await _wait(1.5)
	_follow = null
	var frames: Array[Image] = []
	frames.append(await _shot("death_00"))
	_hit(npc, 1.5, Vector3(0, 0, -1), 999, 25.0)
	for i in range(1, 8):
		await _wait(0.15)
		frames.append(await _shot("death_%02d" % i))
	_strip("death", frames, 0.6)
	_clear()


# --- Helpers ----------------------------------------------------------------------------


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Half-metre chequers.
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 1, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 0, Color(0.3, 0.29, 0.26))
	image.set_pixel(0, 1, Color(0.3, 0.29, 0.26))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(100, 100, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	ground.add_child(floor_mesh)
	add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()


func _spawn(scene: PackedScene, at: Vector3, facing: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	# Placed before it enters the tree: added at the origin first, the body's bones would
	# sit there for a frame and shove whichever NPC stands at the origin.
	npc.position = at + Vector3.UP * 0.02
	add_child(npc)
	npc.look_at(npc.global_position + facing, Vector3.UP)
	npc.brain.shut_down()
	npc.sight.set_physics_process(false)
	if _static:
		_animator(npc).process_mode = Node.PROCESS_MODE_DISABLED
	_npcs.append(npc)
	return npc


func _animator(npc: Npc) -> BodyAnimator:
	return npc.get_node("%BodyAnimator") as BodyAnimator


func _clear() -> void:
	_follow = null
	for npc in _npcs:
		npc.queue_free()
	_npcs.clear()
	# Items the NPCs dropped are left in the level; clear those too.
	for child in get_children():
		if child is RigidBody3D:
			child.queue_free()


func _follow_camera(target: Node3D, offset: Vector3) -> void:
	_follow = target
	_follow_offset = offset


func _fixed_camera(at: Vector3, looking_at: Vector3) -> void:
	_follow = null
	_camera.global_position = at
	_camera.look_at(looking_at, Vector3.UP)


## Hits `npc` at `height` above its feet, travelling along `direction` in world space,
## through its Health like any real blow.
func _hit(npc: Npc, height: float, direction: Vector3, damage: int, knockback: float) -> void:
	var info := DamageInfo.new(damage)
	info.position = npc.global_position + Vector3.UP * height - direction * 0.15
	info.direction = direction
	info.knockback = knockback
	npc.health.apply_damage(info)


## The physical bones are what blows and the interaction ray hit, so they have to follow
## the animated pose rather than stay where the rest pose left them. Prints how far the
## head's physical bone is from the animated head, in metres and degrees.
func _report_head(npc: Npc, label: String) -> void:
	var skeleton := npc.body.skeleton
	var bone := npc.body.physical_bones.get_node("Head") as PhysicalBone3D
	var animated := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
	var physical := bone.global_transform * bone.body_offset.affine_inverse()
	var turn := animated.basis.get_rotation_quaternion().angle_to(physical.basis.get_rotation_quaternion())
	var rest_turn := animated.basis.get_rotation_quaternion().angle_to(skeleton.global_basis.get_rotation_quaternion())
	print("%s: head physical bone off the animated head by %.3f m, %.1f deg (head turned %.1f deg from rest)" % [
		label, animated.origin.distance_to(physical.origin), rad_to_deg(turn), rad_to_deg(rest_turn),
	])


func _wants(stage: String) -> bool:
	return _only.is_empty() or Array(_only).any(func(part: String) -> bool: return part in stage)


func _shot(shot_name: String) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if not _shots_dir.is_empty():
		image.save_png(_shots_dir.path_join("%s.png" % shot_name))
	return image


## Puts the middle slice of each frame side by side and saves it as one image.
func _strip(stage: String, frames: Array[Image], slice := STRIP_SLICE) -> void:
	if _shots_dir.is_empty() or frames.is_empty() or frames[0] == null:
		return
	var size := frames[0].get_size()
	var width := int(size.x * slice)
	var area := Rect2i((size.x - width) / 2, 0, width, size.y)
	var strip := Image.create(width * frames.size(), size.y, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], area, Vector2i(width * i, 0))
	var scale := float(STRIP_HEIGHT) / size.y
	strip.resize(int(strip.get_width() * scale), STRIP_HEIGHT, Image.INTERPOLATE_LANCZOS)
	strip.save_png(_shots_dir.path_join("strip_%s.png" % stage))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
