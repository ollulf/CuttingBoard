extends Node3D

## The five setting weapons that made it into the game, photographed: each held in the
## player's right hand at rest and mid-swing, then where it lies in the test level.
##
##   godot --path cutting-board res://tests/visual/setting_weapons_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved. --skip-level leaves out the
## shots of the level.

const PLAYER := preload("res://scenes/characters/player.tscn")
const LEVEL := preload("res://scenes/levels/test_level.tscn")
const WEAPONS := [
	"pegged_rolling_pin", "chair_leg_club", "clothes_peg_knuckles", "back_scratcher_rake",
	"rocker_sickle",
]
## Node names they are placed under in the level.
const PLACED := [
	"PeggedRollingPin", "ChairLegClub", "ClothesPegKnuckles", "BackScratcherRake", "RockerSickle",
]

var _shots_dir := ""
var _skip_level := false
var _stage: Node3D
var _player: Node3D
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--skip-level":
			_skip_level = true
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
	var hand := _player.get_node("%HandSlotRight") as HandSlot
	(_player.get_node("%Camera3D") as Camera3D).make_current()
	for name in WEAPONS:
		var data := load("res://resources/items/%s.tres" % name) as ItemData
		var weapon := data.spawn()
		_stage.add_child(weapon)
		(weapon.get_node("Carryable") as Carryable).take(_player)
		hand.hold(weapon)
		await _shot("%s_1_held" % name)
		await _pose("punch_unarmed_right", 0.18, "%s_2_swing" % name)
		hand.release().queue_free()

	if _skip_level:
		get_tree().quit()
		return
	_stage.queue_free()
	var level := LEVEL.instantiate()
	add_child(level)
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await _wait(3.0)
	_camera.make_current()
	for name in PLACED:
		var placed := level.find_child(name, true, false) as Node3D
		print(name, " lies at ", placed.global_position if placed else "nowhere")
		if placed:
			var at := placed.global_position
			_look(at + Vector3(-0.9, 1.0, 1.0), at)
			await _shot("place_%s" % name)
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


## Freezes an arm animation at `time`, photographs it, and returns the arm to rest.
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
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
