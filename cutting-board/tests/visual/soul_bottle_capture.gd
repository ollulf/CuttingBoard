extends Node3D

## The soul in a bottle on a plank floor at night. Two tours:
##
##   --tour=concepts  (default) the three concept bottles, a|b|c, each close up and then
##                    all three side by side;
##   --tour=idle      the default bottle close up for a few seconds, the wisp bobbing and
##                    blinking: run it under Movie Maker to record it as a clip.
##
##   godot --path cutting-board res://tests/visual/soul_bottle_capture.tscn -- --shots=<dir>
##
## Needs a real window; under --headless nothing is saved.

const BOTTLE := preload("res://scenes/items/soul_bottle.tscn")
const FLOOR := preload("res://assets/materials/environment/wooden_planks.tres")
const CONCEPTS := {
	"a": preload("res://assets/meshes/props/soul_bottle_a.res"),
	"b": preload("res://assets/meshes/props/soul_bottle_b.res"),
	"c": preload("res://assets/meshes/props/soul_bottle_c.res"),
}

var _shots_dir := ""
var _tour := "concepts"
## --colour=ember shows the red soul instead of the default amber.
var _colour := ""
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--colour="):
			_colour = arg.trim_prefix("--colour=")
		elif arg.begins_with("--tour="):
			_tour = arg.trim_prefix("--tour=")
	_stage()
	_run.call_deferred()


func _stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.05, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.3, 0.5)
	environment.ambient_light_energy = 0.5
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	plane.material = FLOOR
	ground.mesh = plane
	add_child(ground)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.light_energy = 0.9
	lantern.omni_range = 2.5
	lantern.position = Vector3(-0.6, 0.7, 0.4)
	add_child(lantern)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()


func _run() -> void:
	var row: Array[Node3D] = []
	for key in CONCEPTS:
		var bottle := BOTTLE.instantiate() as RigidBody3D
		bottle.freeze = true
		if _colour == "ember":
			bottle.soul_colour = bottle.EMBER
		add_child(bottle)
		(bottle.get_node("MeshInstance3D") as MeshInstance3D).mesh = CONCEPTS[key]
		bottle.position = Vector3.UP * _lift(CONCEPTS[key])
		row.append(bottle)
	if _tour == "idle":
		for i in row.size():
			row[i].visible = i == 0
		_look(Vector3(0.0, row[0].position.y + 0.03, 0.3), row[0].position)
		await _wait(6.0)
		get_tree().quit()
		return
	for i in row.size():
		for other in row:
			other.visible = other == row[i]
		_look(Vector3(-0.16, 0.2, 0.55), Vector3(0.0, 0.07, 0.0))
		await _shot("%s_close" % CONCEPTS.keys()[i])
		_look(Vector3(0.0, row[i].position.y + 0.03, 0.3), row[i].position)
		await _shot("%s_face" % CONCEPTS.keys()[i])
	for i in row.size():
		row[i].visible = true
		row[i].position.x = 0.22 * (i - 1)
	_look(Vector3(0.0, 0.25, 0.85), Vector3(0.0, 0.07, 0.0))
	await _shot("lineup")
	get_tree().quit()


## How far the mesh's origin has to sit above the ground for its bottom to touch it.
func _lift(mesh: Mesh) -> float:
	return -mesh.get_aabb().position.y


func _look(from: Vector3, at: Vector3) -> void:
	_camera.position = from
	_camera.look_at(at, Vector3.UP)


func _shot(shot_name: String) -> void:
	await _wait(0.4)
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
