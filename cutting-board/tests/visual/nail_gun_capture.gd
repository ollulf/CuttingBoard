extends Node3D

## The five nail gun concepts (docs/concepts/nail-gun.md), photographed: all five in a
## line-up, each one close from three quarters, and each held in the player's right hand.
##
##   godot --path cutting-board --write-movie <dir>/x.avi res://tests/visual/nail_gun_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved.

const PLAYER := preload("res://scenes/characters/player.tscn")
const GUNS: Array[Mesh] = [
	preload("res://assets/meshes/props/nail_gun_a_lever_bolt.res"),
	preload("res://assets/meshes/props/nail_gun_b_rope_twister.res"),
	preload("res://assets/meshes/props/nail_gun_c_band_catapult.res"),
	preload("res://assets/meshes/props/nail_gun_d_bellows_puffer.res"),
	preload("res://assets/meshes/props/nail_gun_e_clockwork_knocker.res"),
]
const NAMES := ["a_lever_bolt", "b_rope_twister", "c_band_catapult", "d_bellows_puffer", "e_clockwork_knocker"]
## The tilt the saw is held at (scenes/items/saw.tscn); the guns are pitched further down from it.
const HELD := Transform3D(Basis(Vector3(0.90630776, 0, -0.42261827), Vector3(0.21130913, 0.8660254, 0.45315388),
		Vector3(0.36599815, -0.5, 0.7848855)), Vector3.ZERO)

var _shots_dir := ""
var _stage: Node3D
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
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_tour.call_deferred()


func _tour() -> void:
	await _wait(0.5)
	_camera.make_current()
	var models: Array[MeshInstance3D] = []
	for k in GUNS.size():
		var model := MeshInstance3D.new()
		model.mesh = GUNS[k]
		_stage.add_child(model)
		# Side on, barrel to the left, spaced along X.
		model.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3((k - 2) * 0.55, 1.0, 0.0))
		models.append(model)
	_look(Vector3(0.0, 1.2, 2.2), Vector3(0.0, 1.06, 0.0))
	await _shot("00_lineup")
	for k in models.size():
		for other in models:
			other.visible = other == models[k]
		var at := models[k].global_position + Vector3(0, 0.08, 0)
		_look(at + Vector3(-0.35, 0.22, 0.5), at)
		await _shot("%d_%s_close" % [k + 1, NAMES[k]])
	for model in models:
		model.queue_free()

	var player: Node3D = PLAYER.instantiate()
	_stage.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	for layer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	(player.get_node("%Camera3D") as Camera3D).make_current()
	var slot := player.get_node("%HandSlotRight") as HandSlot
	for k in GUNS.size():
		var item := Node3D.new()
		var model := MeshInstance3D.new()
		model.mesh = GUNS[k]
		model.transform = HELD * Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3.ZERO)
		item.add_child(model)
		_stage.add_child(item)
		slot.hold(item)
		await _shot("%d_%s_in_hand" % [k + 1, NAMES[k]])
		slot.release()
		item.queue_free()
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


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
