extends Node3D

## Close-up of a lantern post at night so the lamp's swing can be watched.
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <out>.avi --fixed-fps 30 \
##       --resolution 960x540 --quit-after 90 res://tests/visual/lamp_swing_capture.tscn

const LANTERN_POST := preload("res://scenes/environment/decoration/lantern_post.tscn")


func _ready() -> void:
	add_child(LANTERN_POST.instantiate())
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	add_child(ground)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.04, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.15, 0.17, 0.25)
	add_child(env)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.look_at_from_position(Vector3(2.2, 2.6, 1.8), Vector3(0, 2.7, -0.1))
