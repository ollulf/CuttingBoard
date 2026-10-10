extends Node3D

const JUNK := [
	"finger_joint", "string_knot", "hinge_pin", "sawdust_pouch", "lacquer_flake",
	"dowel", "screw_eye", "eye_bead", "ember_knot", "peg_teeth",
]
const FLOOR_COLOR := Color(0.16, 0.11, 0.08)
const SPACING := 0.22

var _shots_dir := ""
var _camera: Camera3D
var _pieces: Array[Node3D] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.035, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.36, 0.3)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-30.0), 0.0)
	add_child(sun)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.65, 0.35)
	lantern.light_energy = 1.4
	lantern.omni_range = 2.0
	lantern.position = Vector3(-0.3, 0.5, 0.4)
	add_child(lantern)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 3.0)
	ground.mesh = plane
	var floor_paint := StandardMaterial3D.new()
	floor_paint.albedo_color = FLOOR_COLOR
	ground.material_override = floor_paint
	add_child(ground)
	for k in JUNK.size():
		var piece := Node3D.new()
		piece.position = Vector3((k % 5 - 2) * SPACING, 0.0, (k / 5 - 0.5) * SPACING)
		var shape := MeshInstance3D.new()
		shape.mesh = load("res://assets/meshes/props/junk_%s.res" % JUNK[k])
		var box := shape.mesh.get_aabb()
		shape.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		piece.add_child(shape)
		add_child(piece)
		_pieces.append(piece)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.make_current()
	_run.call_deferred()


func _process(delta: float) -> void:
	for piece in _pieces:
		piece.rotation.y += delta * 0.8


func _run() -> void:
	_look(Vector3(0.0, 0.64, 0.62), Vector3(0.0, 0.0, 0.03))
	await _shot("sheet")
	await _wait(2.5)
	await _shot("sheet_turned")
	for k in JUNK.size():
		var at := _pieces[k].position
		_look(at + Vector3(0.0, 0.13, 0.19), at + Vector3(0.0, 0.025, 0.0))
		await _wait(0.4)
		await _shot(JUNK[k])
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
