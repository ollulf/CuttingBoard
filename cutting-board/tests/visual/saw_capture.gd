extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const SAW := preload("res://scenes/items/saw.tscn")
const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _shots_dir := ""
var _stage: Node3D
var _player: Node3D
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	_stage = Node3D.new()
	add_child(_stage)
	_build_stage(_stage)
	_player = PLAYER.instantiate()
	_stage.add_child(_player)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	for layer in _player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_camera = Camera3D.new()
	add_child(_camera)
	_tour.call_deferred()


func _tour() -> void:
	await _wait(0.5)
	var saw: Node3D = SAW.instantiate()
	_stage.add_child(saw)
	(saw.get_node("Carryable") as Carryable).take(_player)
	(_player.get_node("%HandSlotRight") as HandSlot).hold(saw)
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	await _shot("01_holding")
	await _pose("punch_unarmed_right", 0.08, "02_swing_windup")
	await _pose("punch_unarmed_right", 0.18, "03_swing_hit")

	_camera.make_current()
	_look(Vector3(2.0, 1.5, -0.6), Vector3(0.0, 1.3, -0.7))
	await _shot("04_side_holding")
	_look(Vector3(1.0, 1.9, 0.6), Vector3(0.3, 1.3, -0.8))
	await _shot("05_behind_holding")

	saw = (_player.get_node("%HandSlotRight") as HandSlot).release()
	saw.reparent(_stage)
	_player.queue_free()
	var upright := (saw.get_node("Mesh") as Node3D).basis.inverse()
	saw.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5) * upright, Vector3(0.0, 1.0, 0.0))
	_look(Vector3(0.0, 1.1, 0.9), Vector3(0.0, 1.0, 0.0))
	await _shot("06_close_side")
	_look(Vector3(0.5, 1.35, 0.6), Vector3(0.0, 1.0, 0.0))
	await _shot("07_close_angle")

	_stage.queue_free()
	var level := LEVEL.instantiate()
	add_child(level)
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await _wait(2.0)
	_camera.make_current()
	var placed := level.find_child("Saw", true, false) as Node3D
	print("saw in the village at ", placed.global_position if placed else "nowhere")
	if placed:
		var at := placed.global_position
		_look(at + Vector3(-0.5, 0.7, 0.6), at + Vector3(0.0, 0.0, -0.25))
		await _shot("08_village_close")
		_look(at + Vector3(-4.0, 1.7, 3.0), at + Vector3(0.0, 0.3, 0.0))
		await _shot("09_village_wide")
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _pose(animation: String, time: float, shot_name: String) -> void:
	var player: AnimationPlayer = _player.get_node("%RightPlayer")
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


func _build_stage(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
