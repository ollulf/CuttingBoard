extends Node3D

## A recording of the Music autoload switching cues: Outside plays, the player hits a
## villager, the villager goes for the player and Combat fades in; the villager is killed
## and, after Music.combat_grace, Outside fades back. A label shows the cue and the mix.
## Meant for Movie Maker, which records the music with the picture:
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <out>.avi
##       --fixed-fps 30 --resolution 960x540 --quit-after 690 res://tests/visual/music_capture.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")

var _player: Node3D
var _label: Label


func _ready() -> void:
	PsxScreen.enabled = false
	_run.call_deferred()


func _run() -> void:
	var region := _build_floor()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.55)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	region.bake_navigation_mesh(false)
	_player = PLAYER.instantiate()
	add_child(_player)
	var health: Health = _player.get_node("%Health")
	health.max_health = 100000
	health.reset()
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(5.5, 2.4, -1.0)
	camera.look_at(Vector3(0, 0.9, -2.0), Vector3.UP)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)

	var villager := VILLAGER.instantiate() as Npc
	villager.position = Vector3(0, 0.05, -4)
	add_child(villager)
	await _wait(4.0)
	villager.health.apply_damage(DamageInfo.new(5, _player))
	await _wait(8.0)
	villager.health.apply_damage(DamageInfo.new(99999, _player))


func _process(_delta: float) -> void:
	if _player:
		_player.global_position = Vector3(0, _player.global_position.y, 0)
	if _label:
		var music := get_node("/root/Music")
		_label.text = "Music: %s   (combat mix %d%%)" % [
			"COMBAT" if music.get_cue() == 1 else "Outside", roundi(music.get_mix() * 100.0)
		]


func _build_floor() -> NavigationRegion3D:
	var floor_body := StaticBody3D.new()
	floor_body.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	mesh.mesh = plane
	floor_body.add_child(mesh)
	add_child(floor_body)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)
	return region


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
