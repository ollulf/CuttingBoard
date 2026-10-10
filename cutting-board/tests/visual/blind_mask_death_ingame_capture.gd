extends Node3D

const BANDIT := preload("res://scenes/characters/bandit.tscn")

var _bandit: Npc
var _time := 0.0
var _broken := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.55, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.7, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.make_current()
	camera.look_at_from_position(Vector3(3.6, 1.9, -1.6), Vector3(0.0, 0.6, -1.2))
	_setup.call_deferred()


func _setup() -> void:
	TestWorld.add_floor(self, 30)
	await TestWorld.bake(TestWorld.add_nav_region(self))
	_bandit = BANDIT.instantiate() as Npc
	_bandit.position = Vector3(0, 0.05, 0)
	add_child(_bandit)
	_bandit.brain.shut_down.call_deferred()


func _process(delta: float) -> void:
	if _bandit == null:
		return
	_time += delta
	if not _broken and _time >= 1.0:
		_broken = true
		_bandit.body.break_mask()
