extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

const SHOTS := [
	["02_village_square", Vector3(1, 4.5, -36), Vector3(0, 1.5, -58), true, false],
	["03_main_street", Vector3(0.5, 1.8, -20), Vector3(-1, 1.6, -60), true, false],
	["04_smithy", Vector3(4, 5, -45), Vector3(11, 1.5, -66), true, false],
	["05_barn_paddock", Vector3(2, 5, -14), Vector3(-12, 0.5, -32), true, false],
	["07_valley_from_hills", Vector3(5, 20, 75), Vector3(0, 0, -40), true, false],
	["11_masked_villager", Vector3(-0.6, 1.65, -57.6), Vector3(-1.5, 1.5, -59.5), true, false],
	["12_masked_bandit", Vector3(0.8, 1.65, -57.4), Vector3(-0.1, 1.5, -59.3), true, false],
	["13_both_masks", Vector3(-0.5, 1.7, -56.0), Vector3(-0.9, 1.4, -59.4), true, false],
	["14_moon", Vector3(0, 2, -45), Vector3(45, 32, -130), true, false],
	["20_village_square_unfiltered", Vector3(1, 4.5, -36), Vector3(0, 1.5, -58), false, false],
	["21_barn_paddock_unfiltered", Vector3(2, 5, -14), Vector3(-12, 0.5, -32), false, false],
	["15_hud_over_retro_screen", Vector3(1, 4.5, -36), Vector3(0, 1.5, -58), true, true],
]

var _shots_dir := ""
var _only: PackedStringArray = []
var _camera: Camera3D
var _ui_layers: Array[Node] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--render-height="):
			PsxScreen.render_height = arg.trim_prefix("--render-height=").to_int()
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
	var level := LEVEL.instantiate()
	add_child(level)
	_pose(VILLAGER.instantiate(), level, Vector3(-1.5, 0, -59.5), Vector3(-0.6, 0, -57.6))
	_pose(BANDIT.instantiate(), level, Vector3(-0.1, 0, -59.3), Vector3(0.8, 0, -57.4))
	_camera = Camera3D.new()
	level.add_child(_camera)
	_camera.make_current()
	_ui_layers = level.find_children("*", "CanvasLayer", true, false)
	_tour.call_deferred()


func _pose(npc: Node3D, level: Node, at: Vector3, facing: Vector3) -> void:
	level.add_child(npc)
	npc.global_position = at
	npc.look_at(Vector3(facing.x, at.y, facing.z), Vector3.UP)
	npc.process_mode = Node.PROCESS_MODE_DISABLED


func _tour() -> void:
	await _wait(1.5)
	for shot in SHOTS:
		if not _only.is_empty() and not Array(_only).any(func(part): return part in shot[0]):
			continue
		PsxScreen.enabled = shot[3]
		for layer in _ui_layers:
			layer.visible = shot[4]
		_camera.global_position = shot[1]
		_camera.look_at(shot[2], Vector3.UP)
		await _wait(0.4)
		await _save(shot[0])
		print("%s: %d fps" % [shot[0], Engine.get_frames_per_second()])
	get_tree().quit()


func _save(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
