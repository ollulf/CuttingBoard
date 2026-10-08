extends Node3D

## A bandit backed against a block with the player crowding it, seen from the side, for
## recording whether it holds its ground or shuffles into the wall and out again.
##
##   godot --path cutting-board --write-movie <dir>/out.avi --fixed-fps 30
##       --resolution 960x540 --quit-after 180 res://tests/visual/npc_cornered_capture.tscn

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")

const BLOCK_CENTER := Vector3(0, 0, 0)
const BLOCK_SIZE := Vector3(3, 2, 3)

var _player: Node3D
var _player_spot := Vector3.ZERO
var _player_health: Health
var _camera: Camera3D


func _ready() -> void:
	PsxScreen.enabled = false
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
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.look_at_from_position(Vector3(-2.2, 1.8, 3.6), Vector3(-2.0, 0.9, 0), Vector3.UP)
	_camera.current = true
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 30)
	var block := TestWorld.add_slab(self, BLOCK_SIZE, BLOCK_CENTER + Vector3.UP * BLOCK_SIZE.y * 0.5)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BLOCK_SIZE
	mesh.mesh = box
	block.add_child(mesh)
	await TestWorld.bake(TestWorld.add_nav_region(self))
	var wall_x := BLOCK_CENTER.x - BLOCK_SIZE.x * 0.5
	_player = TestWorld.masked_player(PLAYER) as Node3D
	var bandit: Npc = BANDIT.instantiate()
	add_child(_player)
	add_child(bandit)
	_player_spot = Vector3(wall_x - 1.0, 0.05, 0)
	bandit.global_position = Vector3(wall_x - 0.32, 0.05, 0)
	_player.global_position = _player_spot
	_player_health = _player.get_node("%Health")
	_player_health.max_health = 100000
	_player_health.reset()
	bandit.memory.remember(_player)
	_camera.make_current()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_player.global_position = Vector3(_player_spot.x, _player.global_position.y, _player_spot.z)
	_player_health.reset()
