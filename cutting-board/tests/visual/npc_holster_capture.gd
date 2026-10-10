extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const HAMMER := preload("res://resources/items/hammer.tres")
const SAW := preload("res://resources/items/saw.tres")

var _shots := ""
var _camera: Camera3D
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	TestWorld.add_floor(self, 20.0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.55, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	_camera = Camera3D.new()
	add_child(_camera)
	_place(Vector3(-0.7, 0.05, 0), HAMMER, true)
	_place(Vector3(0.7, 0.05, 0), SAW, false)


func _place(at: Vector3, weapon: ItemData, right: bool) -> void:
	var npc: Npc = VILLAGER.instantiate()
	npc.position = at
	npc.rotation.y = PI
	npc.weapon_pool = []
	add_child(npc)
	await get_tree().process_frame
	await get_tree().process_frame
	npc.brain.shut_down()
	npc.holster.sheathe_delay = 0.3
	for hand in npc.hands:
		if not hand.is_free():
			hand.release().queue_free()
	npc.equip(weapon, npc.hand_right if right else npc.hand_left)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 1:
		_camera.position = Vector3(0, 1.1, 3.0)
		_camera.look_at(Vector3(0, 0.9, 0))
	if _frame == 45:
		_shoot("front")
		_camera.position = Vector3(3.0, 1.1, 0.3)
		_camera.look_at(Vector3(0, 0.9, 0))
	if _frame == 60:
		_shoot("side")


func _shoot(shot_name: String) -> void:
	if _shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png(_shots.path_join(shot_name + ".png"))
