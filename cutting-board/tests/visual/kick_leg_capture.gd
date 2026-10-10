extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const BARREL := preload("res://scenes/items/barrel.tscn")

var _player: Node3D
var _barrel: RigidBody3D


func _ready() -> void:
	_build_stage()
	_player = PLAYER.instantiate()
	add_child(_player)
	for layer in _player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	for shot in 2:
		_spawn_barrel(Vector3(0.0, 0.0, -1.25 - 0.2 * shot))
		_player.get_node("%CameraPivot").rotation.x = deg_to_rad(-38.0 + 6.0 * shot)
		await get_tree().create_timer(0.6).timeout
		_player.get_node("%Kick").press()
		await get_tree().create_timer(1.3).timeout


func _spawn_barrel(at: Vector3) -> void:
	if _barrel:
		_barrel.queue_free()
	_barrel = BARREL.instantiate()
	_barrel.position = at + Vector3.UP * 0.05
	add_child(_barrel)


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	floor_mesh.material_override = material
	ground.add_child(floor_mesh)
	add_child(ground)
