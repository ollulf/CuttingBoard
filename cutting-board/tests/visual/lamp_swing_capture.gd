extends Node3D

const LANTERN_POST := preload("res://scenes/environment/decoration/lantern_post.tscn")
const WIDE_SECONDS := 5.0

var _cam: Camera3D
var _t := 0.0


func _ready() -> void:
	for x in [-4.0, 0.0, 4.0]:
		var post := LANTERN_POST.instantiate()
		post.position = Vector3(x, 0, 0)
		add_child(post)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	add_child(ground)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.04, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.15, 0.17, 0.25)
	add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_place_camera()


func _process(delta: float) -> void:
	_t += delta
	_place_camera()


func _place_camera() -> void:
	if _t < WIDE_SECONDS:
		var k := _t / WIDE_SECONDS
		_cam.fov = 50.0
		_cam.look_at_from_position(Vector3(lerpf(-3.0, 3.0, k), 2.4, 9.0), Vector3(lerpf(-1.0, 1.0, k), 1.6, 0))
	else:
		_cam.fov = 45.0
		_cam.look_at_from_position(Vector3(3.2, 2.6, 2.4), Vector3(0.4, 1.7, -0.1))
