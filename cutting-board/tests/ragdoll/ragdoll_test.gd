extends Node3D

const LIGHT_HIT := 12
const KILLING_HIT := 999

@export var hit_knockback := 10.0

@onready var _camera: Camera3D = %Camera
@onready var _villager: Npc = %Villager
@onready var _bandit: Npc = %Bandit

var _shots_dir := ""


func _ready() -> void:
	_camera.look_at_from_position(_camera.position, Vector3(-0.2, 0.6, -0.4))
	for npc in [_villager, _bandit]:
		npc.brain.shut_down()
	var args := OS.get_cmdline_user_args()
	var auto := args.find("--auto")
	if auto >= 0 and auto + 1 < args.size():
		_shots_dir = args[auto + 1]
		_run_sequence.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed:
		var from := _camera.project_ray_origin(click.position)
		var to := from + _camera.project_ray_normal(click.position) * 50.0
		if click.button_index == MOUSE_BUTTON_LEFT:
			_strike(from, to, LIGHT_HIT)
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			_strike(from, to, KILLING_HIT)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _strike(from: Vector3, to: Vector3, damage: int, knockback := hit_knockback) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var health := Health.find_in(hit["collider"])
	if health == null:
		return
	var info := DamageInfo.new(damage)
	info.position = hit["position"]
	info.direction = (to - from).normalized()
	info.knockback = knockback
	health.apply_damage(info)


func _strike_npc(npc: Npc, height: float, side: Vector3, damage: int, knockback: float) -> void:
	var target := npc.global_position + Vector3.UP * height
	var from := npc.global_basis * side
	_strike(target + from * 3.0, target - from, damage, knockback)


func _run_sequence() -> void:
	await _wait(1.0)
	await _shot("00_standing")
	_strike_npc(_villager, 1.55, Vector3.FORWARD, LIGHT_HIT, hit_knockback)
	_strike_npc(_bandit, 1.35, Vector3.LEFT, LIGHT_HIT, hit_knockback)
	await _wait(0.12)
	await _shot("01_flinch")
	await _wait(1.0)
	await _shot("02_recovered")
	_report("after flinch")
	_strike_npc(_villager, 1.2, Vector3.FORWARD, KILLING_HIT, 25.0)
	_strike_npc(_bandit, 1.55, Vector3.LEFT, KILLING_HIT, 25.0)
	await _wait(0.35)
	await _shot("03_falling")
	await _wait(3.0)
	await _shot("04_ragdolled")
	_report("after death")
	get_tree().quit()


func _report(label: String) -> void:
	for npc in [_villager, _bandit]:
		var head := npc.body.physical_bones.get_node("Head") as Node3D
		var hips := npc.body.physical_bones.get_node("Hips") as Node3D
		print("%s: %s alive=%s limp=%s feet at %s hips %s head %s capsule disabled=%s" % [
			label, npc.name, npc.health.is_alive(), npc.body.is_limp(),
			npc.global_position.snappedf(0.01), hips.global_position.snappedf(0.01),
			head.global_position.snappedf(0.01), npc.collision_shape.disabled,
		])


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("ragdoll_%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
