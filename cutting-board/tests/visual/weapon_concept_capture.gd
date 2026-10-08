extends Node3D

## The ten weapon ideas (docs/concepts/weapon-ideas.md, meshes from
## tools/import/build_weapon_concepts.gd), photographed: all ten in two rows, straight on and from
## three quarters, then each one close and turned so its working end shows.
##
##   godot --path cutting-board --write-movie <dir>/x.avi res://tests/visual/weapon_concept_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved.

const NAMES := ["marionette_cross", "pegged_rolling_pin", "chair_leg_club", "oven_peel",
		"clothes_peg_knuckles", "loom_shuttle", "mousetrap_mace", "pendulum_maul",
		"back_scratcher_rake", "rocker_sickle"]
const SPACING := 0.42

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
	for k in NAMES.size():
		var model := MeshInstance3D.new()
		model.mesh = load("res://assets/meshes/props/weapon_concept_%s.res" % NAMES[k])
		_stage.add_child(model)
		# Two rows of five, each weapon centred on its slot by its bounds, turned a little.
		var box := model.mesh.get_aabb()
		var slot := Vector3((k % 5 - 2) * SPACING, 1.25 - (k / 5) * 0.95, 0.0)
		model.basis = Basis(Vector3.UP, 0.5)
		model.position = slot - model.basis * box.get_center()
		models.append(model)
	_look(Vector3(0.0, 0.85, 3.4), Vector3(0.0, 0.8, 0.0))
	await _shot("00_lineup")
	_look(Vector3(-1.9, 1.7, 2.8), Vector3(0.0, 0.8, 0.0))
	await _shot("00_lineup_high")
	for k in models.size():
		for other in models:
			other.visible = other == models[k]
		# Laid over on a diagonal so a long handle fills the wide frame, working end up right.
		var box := models[k].mesh.get_aabb()
		var at := models[k].global_transform * box.get_center()
		models[k].basis = Basis(Vector3.BACK, -0.9) * Basis(Vector3.UP, 0.7)
		models[k].position = at - models[k].basis * box.get_center()
		var reach := maxf(box.get_longest_axis_size() * 1.05, 0.3)
		_look(at + Vector3(0.15, 0.25, 1.0).normalized() * reach, at)
		await _shot("%02d_%s" % [k + 1, NAMES[k]])
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
	floor_mesh.position.y = -0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
