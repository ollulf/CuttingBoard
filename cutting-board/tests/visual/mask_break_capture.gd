extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const ITEMS := [
	preload("res://scenes/items/villager_mask.tscn"),
	preload("res://scenes/items/bandit_mask.tscn"),
]


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
	var items: Array[RigidBody3D] = []
	for i in 2:
		var npc: Npc = (VILLAGER if i == 0 else BANDIT).instantiate()
		add_child(npc)
		npc.global_position = Vector3(-0.9 + i * 1.8, 0.0, 0.0)
		npc.rotation.y = PI
		npcs.append(npc)
		var item: RigidBody3D = ITEMS[i].instantiate()
		item.freeze = true
		add_child(item)
		item.global_position = Vector3(-0.9 + i * 1.8, 0.04, 1.1)
		item.rotation_degrees = Vector3(-90, 0, 0)
		items.append(item)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.5, 3.8), Vector3(0, 0.9, 0))
	camera.make_current()
	await get_tree().physics_frame
	for npc in npcs:
		npc.brain.shut_down()
	await get_tree().create_timer(0.5).timeout
	for item in items:
		(item.get_node("Destructible") as Destructible).damage(Destructible.MAX_DURABILITY)
	for blow in 3:
		await get_tree().create_timer(0.6).timeout
		for npc in npcs:
			var body := npc.body
			var head := body.skeleton.find_bone("Head")
			var frame := body.skeleton.global_transform * body.skeleton.get_bone_global_pose(head)
			var info := DamageInfo.new(ceili(body.mask.durability / 3.0) if body.mask else 10)
			info.position = frame * Vector3(0, 0.12, -0.15)
			info.direction = Vector3(0, 0, -1)
			info.knockback = 3.0
			npc.health.apply_damage(info)
			npc.health.reset()
			print("%s mask left: %d" % [npc.name, body.mask_durability])
