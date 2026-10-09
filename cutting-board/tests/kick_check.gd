extends Node3D

## Headless checks of the player's kick (docs/concepts/kick-shove.md, round 3): one press
## kicks only the thing under the crosshair, a fully charged kick sends a barrel much
## further than a tap, a rigid body without a Kickable is no target, a kicked prop hurts the NPC it rolls into on
## the kicker's behalf, a press at nothing costs a little stamina and moves nothing, and
## an NPC kicked at the legs staggers longer than one kicked at the body. Prints PASS/FAIL
## per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/kick_check.tscn

const BARREL := preload("res://scenes/items/barrel.tscn")
const BOX := preload("res://scenes/items/box_small.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

var _failures := 0
var _rig: CharacterBody3D
var _camera: Camera3D
var _kick: Kick
var _stamina: Stamina
var _last_cost := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	_build_rig()
	var strike_frames := int(0.15 * Engine.physics_ticks_per_second) + 2

	# Two barrels side by side: only the one under the crosshair goes.
	var barrel := _spawn_prop(BARREL, Vector3(0, 0, -1.3))
	var neighbour := _spawn_prop(BARREL, Vector3(0.9, 0, -1.3))
	await _physics_frames(40)
	_aim_at(barrel.global_position + Vector3.UP * 0.3)
	await _physics_frames(2)
	_check("the barrel under the crosshair is the kick target", _kick.get_target() == barrel)
	var neighbour_start := neighbour.global_position
	var stamina_before := _stamina.get_current()
	_kick.press()
	var top := await _top_speed(barrel, 20)
	_check("the kicked barrel moves (%.2f m/s)" % top, top > 0.3)
	_check("its launch stays under the 9 m/s cap", top <= 9.05)
	_check("the neighbour stays put", neighbour.global_position.distance_to(neighbour_start) < 0.02)
	_check("a kick costs 10 stamina", is_equal_approx(stamina_before - _stamina.get_current(), 10.0))
	barrel.queue_free()
	neighbour.queue_free()
	await _physics_frames(40)

	# Tap versus full charge on the same barrel: the charged kick sends it much further.
	var tapped := await _kick_distance(0)
	var charged := await _kick_distance(int((_kick.charge_time + 0.1) * Engine.physics_ticks_per_second))
	_check("a full charge sends it much further (%.2f m vs %.2f m)" % [charged, tapped],
			charged > 2.5 and charged > tapped * 4.0)
	_check("a full charge costs twice the stamina", is_equal_approx(_last_cost, 20.0))

	# A rigid body without a Kickable child is not a target.
	var plain := RigidBody3D.new()
	plain.mass = 10.0
	var plain_shape := CollisionShape3D.new()
	var plain_box := BoxShape3D.new()
	plain_box.size = Vector3(0.6, 0.6, 0.6)
	plain_shape.shape = plain_box
	plain.add_child(plain_shape)
	plain.position = Vector3(0, 0.35, -1.2)
	add_child(plain)
	await _physics_frames(30)
	_aim_at(plain.global_position)
	await _physics_frames(2)
	_check("a rigid body without Kickable is not a kick target", _kick.get_target() == null)
	plain.queue_free()
	await _physics_frames(10)

	# A whiff: nothing in reach.
	_stamina.reset()
	_aim_at(_camera.global_position + Vector3(0, 1, -3))
	await _physics_frames(2)
	_check("nothing to kick at the sky", _kick.get_target() == null)
	stamina_before = _stamina.get_current()
	_kick.press()
	await _physics_frames(20)
	_check("a whiff costs 4 stamina", is_equal_approx(stamina_before - _stamina.get_current(), 4.0))

	# A kicked box slides into a bandit and hurts him, credited to the kicker.
	_stamina.reset()
	var bandit := await _spawn_npc(Vector3(0, 0, -1.8))
	var box := _spawn_prop(BOX, Vector3(0, 0, -1.1))
	await _physics_frames(40)
	var credited: Array[int] = [0]
	var count_credited := func(info: DamageInfo) -> void:
		if info.source == box and info.get_attacker() == _rig:
			credited[0] += info.amount
	bandit.health.damaged.connect(count_credited)
	_aim_at(box.global_position + Vector3.UP * 0.15)
	await _physics_frames(2)
	_check("the box is the kick target", _kick.get_target() == box)
	await _physics_frames(40)
	_kick.press()
	await _physics_frames(90)
	_check("the kicked box hurt the bandit on the kicker's behalf (%d)" % credited[0], credited[0] > 0)
	bandit.health.damaged.disconnect(count_credited)
	box.queue_free()
	await _physics_frames(60)

	# Kicking the bandit: the legs trip him longer than a kick to the body.
	await _place(bandit)
	_aim_at(bandit.global_position + Vector3.UP * 1.2)
	await _physics_frames(2)
	_check("the bandit is the kick target", _kick.get_target() == bandit)
	var hurt: Array[int] = [0]
	bandit.health.damaged.connect(func(_info: DamageInfo) -> void: hurt[0] += 1)
	_stamina.reset()
	_kick.press()
	await _physics_frames(strike_frames)
	var body_stagger := bandit.locomotion.get_stagger()
	_check("a body kick hurts", hurt[0] == 1)
	_check("a body kick staggers (%.2f s)" % body_stagger, body_stagger > 0.4)
	await _physics_frames(90)
	await _place(bandit)
	_aim_at(bandit.global_position + Vector3.UP * 0.35)
	await _physics_frames(2)
	_stamina.reset()
	_kick.press()
	await _physics_frames(strike_frames)
	var leg_stagger := bandit.locomotion.get_stagger()
	_check("a leg kick trips longer (%.2f s)" % leg_stagger, leg_stagger > body_stagger + 0.15)

	# An empty pool still shoves, but hurts nothing.
	await _physics_frames(90)
	await _place(bandit)
	_aim_at(bandit.global_position + Vector3.UP * 1.2)
	await _physics_frames(2)
	_stamina.drain(1000.0)
	hurt[0] = 0
	_kick.press()
	await _physics_frames(strike_frames)
	_check("a kick from an empty pool deals no damage", hurt[0] == 0)
	_check("but still staggers", bandit.locomotion.get_stagger() > 0.3)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _build_rig() -> void:
	_rig = CharacterBody3D.new()
	_rig.name = "Kicker"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	_rig.add_child(shape)
	_stamina = Stamina.new()
	_stamina.name = "Stamina"
	_rig.add_child(_stamina)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.5, 0)
	_rig.add_child(_camera)
	_kick = Kick.new()
	_kick.name = "Kick"
	_camera.add_child(_kick)
	_stamina.owner = _rig
	_stamina.unique_name_in_owner = true
	_camera.owner = _rig
	_kick.owner = _rig
	add_child(_rig)


## Kicks a fresh barrel after holding the key `hold_frames`, and returns how far it went
## along the ground; the stamina it cost lands in _last_cost.
func _kick_distance(hold_frames: int) -> float:
	_stamina.reset()
	var barrel := _spawn_prop(BARREL, Vector3(0, 0, -1.3))
	await _physics_frames(40)
	_aim_at(barrel.global_position + Vector3.UP * 0.3)
	await _physics_frames(2)
	var start := barrel.global_position
	var before := _stamina.get_current()
	_kick.start_charge()
	await _physics_frames(hold_frames)
	_kick.release()
	_last_cost = before - _stamina.get_current()
	await _physics_frames(180)
	var moved := barrel.global_position - start
	barrel.queue_free()
	await _physics_frames(40)
	return Vector2(moved.x, moved.z).length()


func _place(npc: Npc) -> void:
	npc.global_position = Vector3(0, 0, -1.2)
	npc.velocity = Vector3.ZERO
	await _physics_frames(30)


func _aim_at(point: Vector3) -> void:
	_camera.look_at(point)


func _spawn_prop(scene: PackedScene, at: Vector3) -> RigidBody3D:
	var prop: RigidBody3D = scene.instantiate()
	prop.position = at + Vector3.UP * 0.05
	add_child(prop)
	return prop


func _spawn_npc(at: Vector3) -> Npc:
	var npc: Npc = BANDIT.instantiate()
	npc.position = at
	add_child(npc)
	await _physics_frames(5)
	npc.brain.shut_down()
	npc.health.max_health = 100000
	npc.health.reset()
	return npc


func _top_speed(body: RigidBody3D, frames: int) -> float:
	var top := 0.0
	for i in frames:
		await get_tree().physics_frame
		top = maxf(top, body.linear_velocity.length())
	return top


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
