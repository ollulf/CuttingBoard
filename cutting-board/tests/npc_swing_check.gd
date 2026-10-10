extends Node3D

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const HAMMER := preload("res://resources/items/hammer.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var bandit := await _spawn(BANDIT, Vector3.ZERO)
	var villager := await _spawn(VILLAGER, Vector3(0, 0, -1.1))
	for hand in bandit.hands:
		if not hand.is_free():
			bandit.stow(hand)
	bandit.equip(HAMMER, bandit.hand_right)
	bandit.locomotion.face(villager.global_position)
	await _physics_frames(10)
	var hits := _count_hits(villager.health, bandit)

	var contact := bandit.swing_contact_time()
	_check("an armed swing lands about 0.3 s in (%.2f)" % contact, contact > 0.2 and contact < 0.4)
	var frames := roundi(contact * Engine.physics_ticks_per_second)
	var hand_rest := bandit.hand_right.position
	bandit.strike_at(villager)
	_check("a second strike while winding up is refused", not bandit.strike_at(villager))
	await _physics_frames(frames - 4)
	_check("no damage during the wind-up", hits[0] == 0)
	_check("the weapon hand has moved off its rest", bandit.hand_right.position.distance_to(hand_rest) > 0.2)
	await _physics_frames(8)
	_check("the blow lands on the contact frame", hits[0] == 1)
	await _physics_frames(40)
	_check("the hand is back at rest after the swing", bandit.hand_right.position.is_equal_approx(hand_rest))

	bandit.strike_at(villager)
	await _physics_frames(5)
	bandit.health.apply_damage(DamageInfo.new(1, villager))
	await _physics_frames(frames + 10)
	_check("a swing staggered by a blow deals nothing", hits[0] == 1)

	await _physics_frames(40)
	bandit.strike_at(villager)
	villager.global_position = Vector3(0, 0, -4)
	await _physics_frames(frames + 10)
	_check("a target that steps out of reach is missed", hits[0] == 1)
	villager.global_position = Vector3(0, 0, -1.1)
	await _physics_frames(10)

	bandit.stow(bandit.hand_right)
	var jab := bandit.swing_contact_time()
	_check("a bare-handed jab is quicker than a chop (%.2f)" % jab, jab < contact)
	bandit.strike_at(villager)
	await _physics_frames(roundi(jab * Engine.physics_ticks_per_second) - 3)
	_check("no damage during the jab's wind-up", hits[0] == 1)
	await _physics_frames(8)
	_check("the jab lands on its contact frame", hits[0] == 2)

	await _physics_frames(30)
	bandit.equip(HAMMER, bandit.hand_right)
	await _physics_frames(5)
	bandit.strike_at(villager)
	await _physics_frames(5)
	bandit.health.apply_damage(DamageInfo.new(bandit.health.max_health * 2))
	await _physics_frames(frames + 10)
	_check("the bandit is dead", not bandit.health.is_alive())
	_check("a swing cut short by death deals nothing", hits[0] == 2)
	_check("a dead NPC does not start a swing", not bandit.strike_at(villager))

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc: Npc = scene.instantiate()
	npc.position = at
	add_child(npc)
	await _physics_frames(5)
	npc.brain.shut_down()
	npc.health.max_health = 100000
	npc.health.reset()
	return npc


func _count_hits(health: Health, source: Node) -> Array[int]:
	var count: Array[int] = [0]
	health.damaged.connect(
		func(info: DamageInfo) -> void:
			if info.source == source:
				count[0] += 1
	)
	return count


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
