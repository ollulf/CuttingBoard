extends Node3D

const BARREL := preload("res://scenes/items/barrel.tscn")
const BOX := preload("res://scenes/items/box_small.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")

var _failures := 0
var _rig: CharacterBody3D
var _camera: Camera3D
var _kick: Kick
var _stamina: Stamina


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	_build_rig()
	var strike_frames := int(0.15 * Engine.physics_ticks_per_second) + 2

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
	_check("its launch stays under the 16 m/s cap", top <= 16.05)
	_check("the neighbour stays put", neighbour.global_position.distance_to(neighbour_start) < 0.02)
	_check("a kick costs 22.5 stamina", is_equal_approx(stamina_before - _stamina.get_current(), 22.5))
	barrel.queue_free()
	neighbour.queue_free()
	await _physics_frames(40)

	var leg := KickLeg.new()
	_camera.add_child(leg)
	var started: Array = []
	var struck: Array = []
	var landed: Array = []
	var on_started := func(t: Node3D) -> void:
		started.append(t)
		leg.play_kick(_kick.windup)
	var on_landed := func(t: Node3D) -> void: landed.append(t)
	_kick.kick_started.connect(on_started)
	_kick.kicked.connect(on_landed)
	leg.struck.connect(func() -> void: struck.append(Time.get_ticks_msec()))
	var rolled := _spawn_prop(BARREL, Vector3(0, 0, -1.3))
	await _physics_frames(40)
	_aim_at(rolled.global_position + Vector3.UP * 0.3)
	await _physics_frames(2)
	var forward_before := -_camera.global_transform.basis.z
	_kick.press()
	_check("kick_started fires with the target", started == [rolled])
	_check("the leg shows while it kicks", leg.visible and leg.is_playing())
	var max_roll := 0.0
	var max_drift := 0.0
	for i in strike_frames:
		await get_tree().process_frame
		_camera.rotation.z = leg.view_roll
		max_roll = maxf(max_roll, absf(leg.view_roll))
		max_drift = maxf(max_drift, (-_camera.global_transform.basis.z).angle_to(forward_before))
	_check("the view rolls (%.1f deg)" % rad_to_deg(max_roll), max_roll > deg_to_rad(3.0))
	_check("the roll leaves the aim direction alone", max_drift < 0.001)
	_check("the leg strikes with the kick", struck.size() == 1 and landed == [rolled])
	await _physics_frames(60)
	_check("the leg animation finishes and hides", not leg.is_playing() and not leg.visible)
	_check("the view roll eases back to level", absf(leg.view_roll) < 0.001)
	_camera.rotation.z = 0.0
	_kick.kick_started.disconnect(on_started)
	_kick.kicked.disconnect(on_landed)
	leg.queue_free()
	rolled.queue_free()
	await _physics_frames(40)

	var distance := await _kick_distance()
	_check("a single kick sends a barrel several metres (%.2f m)" % distance, distance > 2.5)

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

	_stamina.reset()
	_aim_at(_camera.global_position + Vector3(0, 1, -3))
	await _physics_frames(2)
	_check("nothing to kick at the sky", _kick.get_target() == null)
	stamina_before = _stamina.get_current()
	_kick.press()
	await _physics_frames(20)
	_check("a whiff costs 6 stamina", is_equal_approx(stamina_before - _stamina.get_current(), 6.0))

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

	var tracker := CombatTracker.new()
	_rig.add_child(tracker)
	bandit.global_position = Vector3(12, 0, 0)
	var keg := _spawn_prop(BARREL, Vector3(0, 0, -1.3))
	await _physics_frames(40)
	var full := Destructible.read(keg)
	_aim_at(keg.global_position + Vector3(0, 0.3, -1.0))
	await _physics_frames(2)
	_stamina.reset()
	_kick.press()
	await _physics_frames(strike_frames + 1)
	_check("the boot costs a barrel no durability", Destructible.read(keg) == full)
	await _physics_frames(180)
	_check("nor does its landing and roll (%d of %d)" % [Destructible.read(keg), full], Destructible.read(keg) == full)
	keg.queue_free()
	await _physics_frames(20)
	await _place(bandit)
	bandit.global_position = Vector3(0, 0, -2.7)
	await _physics_frames(20)
	var barrel_hits: Array[int] = [0]
	var count_barrel := func(info: DamageInfo) -> void:
		if info.source is RigidBody3D and info.get_attacker() == _rig:
			barrel_hits[0] += 1
	bandit.health.damaged.connect(count_barrel)
	var survived: Array[bool] = []
	for round_index in 3:
		if round_index > 0 and not is_instance_valid(keg):
			break
		if round_index == 0:
			keg = _spawn_prop(BARREL, Vector3(0, 0, -1.3))
		else:
			keg.global_transform = Transform3D(Basis(), Vector3(0, 0.5, -1.3))
			keg.linear_velocity = Vector3.ZERO
			keg.angular_velocity = Vector3.ZERO
		bandit.global_position = Vector3(0, 0, -2.7)
		bandit.velocity = Vector3.ZERO
		await _physics_frames(40)
		_aim_at(keg.global_position + Vector3.UP * 0.3)
		await _physics_frames(2)
		_stamina.reset()
		await _physics_frames(40)
		_kick.press()
		await _physics_frames(90)
		survived.append(is_instance_valid(keg))
		if round_index == 0:
			_check("a barrel hit counts as the kicker's attack (combat tracker engaged)",
				tracker.is_in_combat() and tracker.get_target() == bandit)
	bandit.health.damaged.disconnect(count_barrel)
	_check("the barrel hit the bandit three times (%d)" % barrel_hits[0], barrel_hits[0] == 3)
	_check("the barrel survives two enemy hits and breaks on the third (%s)" % [survived],
		survived == [true, true, false])
	if is_instance_valid(keg):
		keg.queue_free()
	tracker.queue_free()
	await _physics_frames(30)

	tracker = CombatTracker.new()
	_rig.add_child(tracker)
	await _physics_frames(2)
	await _place(bandit)
	_aim_at(bandit.global_position + Vector3.UP * 1.2)
	await _physics_frames(2)
	var kicker: Array = [null]
	var note_kicker := func(info: DamageInfo) -> void: kicker[0] = info.get_attacker()
	bandit.health.damaged.connect(note_kicker)
	_stamina.reset()
	_kick.press()
	await _physics_frames(strike_frames)
	bandit.health.damaged.disconnect(note_kicker)
	_check("a kick on an NPC is credited to the kicker", kicker[0] == _rig)
	_check("and engages the combat tracker like a punch",
		tracker.is_in_combat() and tracker.get_target() == bandit)
	tracker.queue_free()
	await _physics_frames(90)

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


func _kick_distance() -> float:
	_stamina.reset()
	var barrel := _spawn_prop(BARREL, Vector3(0, 0, -1.3))
	await _physics_frames(40)
	_aim_at(barrel.global_position + Vector3.UP * 0.3)
	await _physics_frames(2)
	var start := barrel.global_position
	_kick.press()
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
