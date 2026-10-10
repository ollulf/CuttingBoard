extends Node3D

const GLUE := preload("res://scenes/items/wood_glue.tscn")
const LEVEL := preload("res://scenes/levels/test_level.tscn")
const CONCEPTS := {
	"a": preload("res://assets/meshes/props/wood_glue_a.res"),
	"b": preload("res://assets/meshes/props/wood_glue_b.res"),
	"c": preload("res://assets/meshes/props/wood_glue_c.res"),
}

var _shots_dir := ""
var _tour := "concepts"
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--tour="):
			_tour = arg.trim_prefix("--tour=")
		elif arg == "--plain":
			PsxScreen.enabled = false
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await _wait(2.0)
	var placed := level.find_child("WoodGlue", true, false) as Node3D
	print("wood glue in the village at ", placed.global_position if placed else "nowhere")
	if not placed:
		get_tree().quit()
		return
	if _tour == "heal":
		await _heal(level, placed)
	else:
		await _concepts(level, placed)
	get_tree().quit()


func _concepts(level: Node, placed: Node3D) -> void:
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var player := level.find_child("Player", false, false) as Node3D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("%Arms").process_mode = Node.PROCESS_MODE_ALWAYS
	var at := placed.global_position
	(placed as RigidBody3D).freeze = true
	_camera.make_current()
	_look(at + Vector3(-1.2, 0.9, 1.4), at)
	await _shot("village_wide")

	var stage := at + Vector3(-2.5, 0.0, 2.0)
	stage.y = _ground_below(stage)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.light_energy = 1.6
	lantern.omni_range = 2.5
	level.add_child(lantern)
	lantern.global_position = stage + Vector3(-0.5, 0.6, 0.4)
	var row: Array[Node3D] = []
	for key in CONCEPTS:
		var glue := GLUE.instantiate() as RigidBody3D
		glue.freeze = true
		level.add_child(glue)
		_set_mesh(glue, CONCEPTS[key])
		row.append(glue)
	var i := 0
	for key in CONCEPTS:
		for other in row:
			other.visible = other == row[i]
		var glue := row[i]
		glue.global_position = stage + Vector3.UP * _lift(CONCEPTS[key])
		_look(stage + Vector3(-0.38, 0.3, 0.48), stage + Vector3(0.0, 0.09, 0.0))
		await _shot("%s_close" % key)
		glue.rotation.y = PI * 0.75
		await _shot("%s_back" % key)
		glue.rotation.y = 0.0
		i += 1
	i = 0
	for key in CONCEPTS:
		row[i].visible = true
		row[i].global_position = stage + Vector3(0.24 * (i - 1), _lift(CONCEPTS[key]), 0.0)
		i += 1
	_look(stage + Vector3(0.0, 0.4, 0.85), stage + Vector3(0.0, 0.1, 0.0))
	await _shot("lineup")
	for each in row:
		each.queue_free()
	lantern.queue_free()

	player.global_position = at + Vector3(-1.5, -0.95, 1.5)
	player.look_at(at + Vector3(0.0, -0.95, 0.0), Vector3.UP)
	(player.get_node("%Camera3D") as Camera3D).make_current()
	var hand := player.get_node("%HandSlotRight") as HandSlot
	(placed.get_node("Carryable") as Carryable).take(player)
	hand.hold(placed)
	for key in CONCEPTS:
		_set_mesh(placed, CONCEPTS[key])
		await _wait(0.3)
		await _shot("%s_held" % key)


func _heal(level: Node, placed: Node3D) -> void:
	var player := level.find_child("Player", false, false)
	var at := placed.global_position
	player.global_position = at + Vector3(-1.4, -0.95, 1.4)
	player.look_at(at + Vector3(0.0, -0.95, 0.0), Vector3.UP)
	(player.get_node("%Camera3D") as Camera3D).make_current()
	await _wait(0.5)
	var health: Health = player.health
	health.apply_damage(DamageInfo.new(health.max_health - 30))
	await _wait(1.2)
	(placed.get_node("Carryable") as Carryable).take(player)
	player.hand_right.hold(placed)
	await _wait(1.2)
	await _shot("heal_before")
	player.use_held(player.hand_right)
	await _wait(0.35)
	await _shot("heal_during")
	await _wait(1.6)
	await _shot("heal_after")
	print("health after the glue: ", health.get_current())


func _lift(mesh: Mesh) -> float:
	return -mesh.get_aabb().position.y


func _ground_below(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5.0, point + Vector3.DOWN * 5.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else point.y


func _set_mesh(glue: Node3D, mesh: Mesh) -> void:
	(glue.get_node("MeshInstance3D") as MeshInstance3D).mesh = mesh


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _shot(shot_name: String) -> void:
	await _wait(0.2)
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
