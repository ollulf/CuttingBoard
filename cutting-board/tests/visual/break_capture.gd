extends Node3D

## A small box, a barrel and a rock side by side on a flat floor, broken together half
## a second in so their break bursts can be recorded.
##
##   godot --path cutting-board --write-movie <dir>/f.png --fixed-fps 30 --quit-after 75
##       res://tests/visual/break_capture.tscn

const ITEMS := [
	preload("res://scenes/items/box_small.tscn"),
	preload("res://scenes/items/barrel.tscn"),
	preload("res://scenes/items/rock.tscn"),
]

var _items: Array[Node3D] = []


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
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	for i in ITEMS.size():
		var item: RigidBody3D = ITEMS[i].instantiate()
		item.freeze = true
		add_child(item)
		item.global_position = Vector3((i - 1) * 1.6, 0.0, 0.0)
		# Sit the item on the floor by its mesh bounds.
		var low := INF
		for mi in item.find_children("*", "MeshInstance3D", true, false):
			low = minf(low, (mi.global_transform * mi.get_aabb()).position.y)
		if low != INF:
			item.global_position.y -= low
		_items.append(item)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 2.0, 3.6), Vector3(0, 0.3, 0))
	camera.make_current()
	await get_tree().create_timer(0.5).timeout
	for item in _items:
		(item.get_node("Destructible") as Destructible).damage(Destructible.MAX_DURABILITY)
