extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

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
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	ground.add_child(floor_mesh)
	add_child(ground)

	var npcs: Array[Npc] = []
	for i in 2:
		var npc: Npc = (VILLAGER if i == 0 else BANDIT).instantiate()
		add_child(npc)
		npc.global_position = Vector3(-0.8 + i * 1.6, 0.0, 0.0)
		npc.rotation.y = PI
		npcs.append(npc)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.look_at_from_position(Vector3(0, 1.6, 3.6), Vector3(0, 0.9, 0))
	_camera.make_current()
	await get_tree().physics_frame
	for npc in npcs:
		npc.brain.shut_down()
		npc.body.mask_pop_chance = 1.0
	await get_tree().create_timer(0.5).timeout
	for npc in npcs:
		var info := DamageInfo.new(9999)
		info.position = npc.global_position + Vector3(0, 1.5, 0.2)
		info.direction = Vector3(0, 0.2, -1)
		info.knockback = 8.0
		npc.health.apply_damage(info)
	await get_tree().create_timer(2.2).timeout
	_camera.look_at_from_position(Vector3(0, 3.2, 1.6), Vector3(0, 0.0, 0.0))
	for carryable in find_children("Carryable", "Carryable", true, false):
		var item := carryable.get_parent() as Node3D
		print("%s at %s" % [(carryable as Carryable).item_data.display_name, item.global_position])
