extends Node3D

const BANDIT := preload("res://scenes/characters/bandit.tscn")


func _ready() -> void:
	TestWorld.add_floor(self, 30)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.14, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.5, 0.46)
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.look_at_from_position(Vector3(1.6, 1.5, 2.2), Vector3(0.0, 0.2, -0.4))
	camera.current = true
	_play.call_deferred()


func _play() -> void:
	var npc := BANDIT.instantiate() as Npc
	add_child(npc)
	npc.global_position = Vector3(0, 0.05, 0)
	npc.rotation_degrees.y = 60.0
	await get_tree().create_timer(0.8).timeout
	npc.brain.shut_down()
	var info := DamageInfo.new(100000, null)
	info.position = npc.body.get_center()
	npc.health.apply_damage(info)
	for entry in npc.inventory.get_entries().duplicate():
		npc.inventory.remove(entry)
	var camera := get_viewport().get_camera_3d()
	var follow := get_tree().create_tween()
	follow.tween_method(
		func(weight: float) -> void:
			if is_instance_valid(npc):
				var center := npc.body.get_center()
				center.y = 0.1
				var target := camera.global_position.lerp(center + Vector3(-1.3, 1.2, 0.9), weight)
				camera.look_at_from_position(target, center),
		0.0, 0.2, 1.2
	)
