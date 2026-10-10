extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const HAMMER := preload("res://scenes/items/hammer.tscn")
const ROCK := preload("res://scenes/items/rock.tscn")
const SAW := preload("res://scenes/items/saw.tscn")
const HAMMER_DATA := preload("res://resources/items/hammer.tres")
const SAW_DATA := preload("res://resources/items/saw.tres")

var _shots_dir := ""
var _clip_only := false
var _walk_only := false
var _swing_only := false
var _player: Node3D
var _side_camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--clip":
			_clip_only = true
		elif arg == "--walk":
			_walk_only = true
		elif arg == "--swing":
			_swing_only = true
		elif arg == "--plain":
			PsxScreen.enabled = false
	_build_stage()
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	for layer in _player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_side_camera = Camera3D.new()
	add_child(_side_camera)
	if _walk_only:
		_walk_clip.call_deferred()
	elif _swing_only:
		_swing_clip.call_deferred()
	else:
		(_clip if _clip_only else _tour).call_deferred()


func _tour() -> void:
	await _wait(0.5)
	var first_person: Camera3D = _player.get_node("%Camera3D")
	first_person.make_current()
	await _shot("01_rest")
	await _pose("punch_unarmed_left", 0.08, "02_punch_left_windup")
	await _pose("punch_unarmed_left", 0.18, "03_punch_left_hit")
	await _pose("punch_unarmed_right", 0.18, "04_punch_right_hit")

	_side_camera.make_current()
	_side_camera.global_position = Vector3(2.0, 1.5, -0.6)
	_side_camera.look_at(Vector3(0.0, 1.3, -0.7), Vector3.UP)
	await _shot("05_side_rest")
	_side_camera.global_position = Vector3(0.0, 2.6, -0.7)
	_side_camera.look_at(Vector3(0.0, 1.3, -0.75), Vector3.FORWARD)
	await _shot("06_top_rest")

	_hold(HAMMER, "%HandSlotRight")
	_hold(ROCK, "%HandSlotLeft")
	first_person.make_current()
	await _shot("07_holding")
	await _pose("punch_unarmed_right", 0.18, "08_holding_punch_right")
	await _pose("punch_weapon_right", 0.16, "08b_swing_right_windup")
	await _pose("punch_weapon_right", 0.3, "08c_swing_right_hit")
	_side_camera.make_current()
	_side_camera.global_position = Vector3(2.0, 1.5, -0.6)
	_side_camera.look_at(Vector3(0.0, 1.3, -0.7), Vector3.UP)
	await _shot("09_side_holding")
	get_tree().quit()


func _clip() -> void:
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	await _wait(0.4)
	var arms: ArmAnimator = _player.get_node("%Arms")
	for arm in [ArmAnimator.Arm.LEFT, ArmAnimator.Arm.RIGHT, ArmAnimator.Arm.LEFT]:
		arms.play_action(&"punch", arm)
		await _wait(0.6)
	get_tree().quit()


func _swing_clip() -> void:
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	_hold(HAMMER, "%HandSlotRight")
	_hold(SAW, "%HandSlotLeft")
	await _wait(0.4)
	var arms: ArmAnimator = _player.get_node("%Arms")
	for arm in [ArmAnimator.Arm.RIGHT, ArmAnimator.Arm.LEFT, ArmAnimator.Arm.RIGHT]:
		arms.play_action(&"punch", arm, HAMMER_DATA if arm == ArmAnimator.Arm.RIGHT else SAW_DATA)
		await _wait(0.8)
	get_tree().quit()


func _walk_clip() -> void:
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	_hold(HAMMER, "%HandSlotRight")
	_hold(ROCK, "%HandSlotLeft")
	for i in 12:
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new()
		post.position = Vector3(-1.5 if i % 2 else 1.5, 0.5, -2.0 * i)
		add_child(post)
	var arms: ArmAnimator = _player.get_node("%Arms")
	var bob := 0.0
	var left_sway := 1.0
	var right_sway := 1.0
	var frames := 0
	while frames < 120:
		var delta := get_physics_process_delta_time()
		bob += delta * _player.arm_bob_frequency
		_player.position.z -= delta * _player.walk_speed
		if frames == 36:
			arms.play_action(&"punch", ArmAnimator.Arm.RIGHT)
		elif frames == 66:
			arms.play_action(&"punch", ArmAnimator.Arm.LEFT)
		var settle: float = delta / _player.arm_action_settle_time
		left_sway = move_toward(left_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.LEFT) else 1.0, settle)
		right_sway = move_toward(right_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.RIGHT) else 1.0, settle)
		_player.pose_arms(sin(bob), 0.0, left_sway, right_sway)
		await get_tree().physics_frame
		frames += 1
	get_tree().quit()


func _hold(scene: PackedScene, hand_path: String) -> void:
	var item: Node3D = scene.instantiate()
	add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(_player)
	(_player.get_node(hand_path) as HandSlot).hold(item)


func _pose(animation: String, time: float, shot_name: String) -> void:
	var player: AnimationPlayer = _player.get_node(
		"%RightPlayer" if animation.ends_with("right") else "%LeftPlayer"
	)
	player.play(animation)
	player.seek(time, true)
	player.pause()
	await _shot(shot_name)
	player.seek(0.0, true)
	player.stop()


func _shot(shot_name: String) -> void:
	await _wait(0.2)
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	floor_mesh.material_override = material
	add_child(floor_mesh)
