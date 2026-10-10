extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

const TIMELINE := [[0.5, 0, 8], [1.2, 0, 8], [2.0, 1, 8], [2.8, 1, 22], [3.8, 0, 22]]

var _bodies: Array[Node3D] = []
var _time := 0.0
var _next := 0


func _ready() -> void:
	PsxScreen.enabled = "--retro" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	for i in 2:
		var body: Node3D = (VILLAGER if i == 0 else BANDIT).instantiate()
		add_child(body)
		body.global_position = Vector3(-0.9 + i * 1.8, 0.0, 0.0)
		body.rotation.y = PI
		body.process_mode = Node.PROCESS_MODE_DISABLED
		_bodies.append(body)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.5, 2.2), Vector3(0, 1.2, 0))
	camera.make_current()


func _process(delta: float) -> void:
	_time += delta
	if _next >= TIMELINE.size() or _time < TIMELINE[_next][0]:
		return
	var step: Array = TIMELINE[_next]
	_next += 1
	var body := _bodies[step[1]]
	var side := -1.0 if step[1] == 0 else 1.0
	var info := DamageInfo.new(step[2])
	info.position = body.global_position + Vector3(side * 0.2, 1.3, 0.1)
	info.direction = Vector3(-side, 0.1, -0.3).normalized()
	Health.find_in(body).apply_damage(info)
	print("t=%.1f hit %s for %d" % [_time, body.name, step[2]])
