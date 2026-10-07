extends Node3D

## Headless checks for the target bar naming the NPC the player stands close to and
## looks at. Prints PASS/FAIL per check and quits with the number of failures.
##
##   godot --headless --path cutting-board res://tests/npc_nameplate_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const MASK_MONGER := preload("res://scenes/characters/mask_monger.tscn")
const DUMMY := preload("res://scenes/characters/training_dummy.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var player := PLAYER.instantiate()
	add_child(player)
	var villager := VILLAGER.instantiate()
	add_child(villager)
	villager.position = Vector3(0, 0, -30)
	var monger := MASK_MONGER.instantiate()
	add_child(monger)
	monger.position = Vector3(30, 0, 0)
	var dummy := DUMMY.instantiate()
	add_child(dummy)
	dummy.position = Vector3(-30, 0, 0)
	await _frames(3)
	# Keep them where they are put.
	for npc: Npc in [villager, monger]:
		npc.brain.process_mode = Node.PROCESS_MODE_DISABLED
		npc.set_physics_process(false)

	var tracker: CombatTracker = player.get_node("%CombatTracker")
	var bar: TargetBar = player.find_child("TargetBar", true, false)
	bar.fade_time = 0.01
	await _wait(0.2)
	_check("nothing nearby at the start", tracker.get_nearby() == null and bar.modulate.a < 0.01)

	var forward: Vector3 = -player.get_node("%Camera3D").global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	villager.global_position = player.global_position + forward * 2.5
	await _wait(0.3)
	_check("looked-at villager close by is picked", tracker.get_nearby() == villager)
	_check("bar shows", bar.modulate.a > 0.99)
	_check("bar shows the villager's own name",
		bar.get_target_name() == CombatTracker.name_of(villager)
		and villager.name_pool.has(bar.get_target_name()))
	_check("villager bar is friendly", bar.is_friendly())

	villager.hold_grudge(player)
	tracker.nearby_changed.emit(villager)
	_check("a grudge tints it hostile", not bar.is_friendly())

	villager.global_position = player.global_position + forward * 7.0
	await _wait(0.3)
	_check("far villager is not picked", tracker.get_nearby() == null)
	_check("bar fades out", bar.modulate.a < 0.01)

	villager.global_position = player.global_position - forward * 2.0
	await _wait(0.3)
	_check("villager behind is not picked", tracker.get_nearby() == null)

	villager.global_position = player.global_position + forward.cross(Vector3.UP) * 30.0
	monger.global_position = player.global_position + forward * 3.0
	await _wait(0.3)
	_check("Mask-Monger named", bar.get_target_name() == "Mask-Monger" and bar.modulate.a > 0.99)

	# The training dummy is no NPC, but looking at it names it, neutral gray.
	monger.global_position = player.global_position + forward.cross(Vector3.UP) * -30.0
	dummy.global_position = player.global_position + forward * 2.5
	await _wait(0.3)
	_check("looked-at dummy is picked", tracker.get_nearby() == dummy)
	_check("dummy named, neutral tint", bar.get_target_name() == "Training Dummy"
		and bar.is_friendly() and bar.modulate.a > 0.99)
	dummy.global_position = player.global_position + forward * 30.0
	monger.global_position = player.global_position + forward * 3.0
	await _wait(0.3)

	# A blow on the dummy makes it the combat target; the Mask-Monger in view gives way.
	Health.find_in(dummy).apply_damage(DamageInfo.new(10, player))
	await _wait(0.3)
	_check("combat target wins over the nearby NPC",
		tracker.get_target() == dummy and bar.get_target_name() == "Training Dummy"
		and not bar.is_friendly())

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
