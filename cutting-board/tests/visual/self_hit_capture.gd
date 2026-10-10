extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

var _camera: Camera3D
var _label: Label
var _bandit: Npc
var _villager: Npc
var _on_target := 0
var _on_self := 0


func _ready() -> void:
	PsxScreen.enabled = false
	_build_stage()

	_villager = VILLAGER.instantiate() as Npc
	_villager.position = Vector3(1.5, 0.02, 0)
	add_child(_villager)
	_villager.look_at(_villager.global_position + Vector3.LEFT, Vector3.UP)
	_villager.brain.shut_down()
	_villager.sight.set_physics_process(false)
	_tough(_villager.health)

	_bandit = BANDIT.instantiate() as Npc
	_bandit.starting_items = []
	_bandit.position = Vector3(-3.5, 0.02, 0)
	add_child(_bandit)
	_bandit.look_at(_bandit.global_position + Vector3.RIGHT, Vector3.UP)
	_tough(_bandit.health)
	_bandit.memory.remember(_villager)

	_villager.health.damaged.connect(
		func(info: DamageInfo) -> void:
			if info.source == _bandit:
				_on_target += 1
	)
	_bandit.health.damaged.connect(
		func(info: DamageInfo) -> void:
			if info.source == _bandit:
				_on_self += 1
	)


func _process(_delta: float) -> void:
	var middle := (_bandit.global_position + _villager.global_position) * 0.5
	middle.y = 0.0
	_camera.global_position = middle + Vector3(0.0, 1.5, 4.2)
	_camera.look_at(middle + Vector3.UP * 1.0, Vector3.UP)
	var gap := _bandit.flat_distance_to(_villager.global_position)
	_label.text = "blows on villager: %d\nblows on itself: %d\ngap: %.2f m" % [
		_on_target, _on_self, gap
	]
	_label.modulate = Color(1, 0.45, 0.4) if _on_self > 0 else Color.WHITE
	_tough(_villager.health)
	_tough(_bandit.health)


func _tough(health: Health) -> void:
	health.max_health = 100000
	if health.get_current() < 50000:
		health.reset()


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

	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 1, Color(0.42, 0.4, 0.36))
	image.set_pixel(1, 0, Color(0.3, 0.29, 0.26))
	image.set_pixel(0, 1, Color(0.3, 0.29, 0.26))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(100, 100, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	ground.add_child(floor_mesh)
	add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
