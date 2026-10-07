extends Node3D

## A bandit swinging at a villager, seen side on: two chops with a hammer, then two
## bare-handed jabs. Saves a still at the top of the wind-up and at the contact frame.
##
##   godot --path cutting-board --write-movie <tmp>/out.avi --fixed-fps 30 --quit-after 150 \
##       res://tests/visual/npc_swing_capture.tscn -- --shots=<dir>

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const HAMMER := preload("res://resources/items/hammer.tres")

var _shots := ""
var _camera: Camera3D
var _frame := 0
var _bandit: Npc
var _villager: Npc


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
	_camera.position = Vector3(0, 1.2, 3.2)
	add_child(_camera)
	_camera.look_at(Vector3(0, 1.0, 0))
	_bandit = await _place(BANDIT, Vector3(-0.6, 0.05, 0), Vector3(1, 0, 0))
	_villager = await _place(VILLAGER, Vector3(0.6, 0.05, 0), Vector3(-1, 0, 0))
	_bandit.equip(HAMMER, _bandit.hand_right)


func _place(scene: PackedScene, at: Vector3, facing: Vector3) -> Npc:
	var npc: Npc = scene.instantiate()
	npc.position = at
	npc.weapon_pool = []
	add_child(npc)
	await get_tree().process_frame
	await get_tree().process_frame
	npc.brain.shut_down()
	npc.health.max_health = 100000
	npc.health.reset()
	for hand in npc.hands:
		if not hand.is_free():
			hand.release().queue_free()
	npc.locomotion.face(at + facing)
	return npc


func _process(_delta: float) -> void:
	_frame += 1
	if _bandit == null or _villager == null:
		return
	# A blow every 33 frames: two chops, then the hammer is put away for two jabs.
	if _frame in [20, 53, 95, 128]:
		_bandit.strike_at(_villager)
	if _frame == 80:
		_bandit.stow(_bandit.hand_right)
	if _frame == 27:
		_shoot("chop_windup")
	if _frame == 29:
		_shoot("chop_contact")
	if _frame == 99:
		_shoot("jab_contact")


func _shoot(shot_name: String) -> void:
	if _shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png(_shots.path_join(shot_name + ".png"))
