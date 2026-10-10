extends Node3D

const HAMMER := preload("res://resources/items/hammer.tres")
const SAW := preload("res://resources/items/saw.tres")
const PLANK := preload("res://resources/items/plank.tres")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	_add_target(Vector3(0, 1, -1))

	var aim := Node3D.new()
	aim.position = Vector3(0, 1, 0)
	add_child(aim)
	var melee := MeleeAttack.new()
	aim.add_child(melee)
	var hand := HandSlot.new()
	add_child(hand)
	await _physics_frames(2)

	for data: ItemData in [HAMMER, SAW, PLANK]:
		var hits := ceili(float(data.durability) / data.wear_per_hit)
		print("%s: %d durability, %d per hit, breaks on hit %d" % [
			data.display_name, data.durability, data.wear_per_hit, hits
		])
		_check("%s lasts 9-18 landed hits (%d)" % [data.display_name, hits], hits >= 9 and hits <= 18)

	var hammer := _hold(HAMMER, hand)
	await _physics_frames(1)
	melee.strike(hand)
	_check("a landed blow costs the hammer %d" % HAMMER.wear_per_hit,
		hand.get_durability() == HAMMER.durability - HAMMER.wear_per_hit)
	aim.rotation_degrees.y = 180
	melee.strike(hand)
	_check("a whiff costs nothing", hand.get_durability() == HAMMER.durability - HAMMER.wear_per_hit)
	aim.rotation_degrees.y = 0

	var hotbar := Hotbar.new()
	add_child(hotbar)
	var inventory := Inventory.new()
	add_child(inventory)
	var hands: Array[HandSlot] = [hand]
	hotbar.setup(inventory, hands, null)
	_check("the hammer is linked to a hotbar square", hotbar.assign_held(0, hand))

	Destructible.write(hammer, HAMMER.durability)
	var expected := ceili(float(HAMMER.durability) / HAMMER.wear_per_hit)
	var landed := 0
	while hand.get_durability() > 0 and landed < 500:
		melee.strike(hand)
		landed += 1
	_check("the hammer broke on landed hit %d (%d)" % [expected, landed], landed == expected)
	await _physics_frames(2)
	_check("the broken hammer is gone", not is_instance_valid(hammer))
	_check("the hand is empty", hand.is_free())
	_check("its hotbar square let go of it", hotbar.get_slot(0).is_empty())
	melee.strike(hand)
	_check("a bare fist swings after the break", hand.is_free())

	var glue_data := load("res://resources/items/wood_glue.tres") as ItemData
	_hold(glue_data, hand)
	await _physics_frames(1)
	var glue_before := hand.get_durability()
	melee.strike(hand)
	_check("a non-weapon item is not worn by a blow", hand.get_durability() == glue_before)
	hand.release().queue_free()

	var bandit := await _spawn(BANDIT, Vector3(10, 0, 0))
	var villager := await _spawn(VILLAGER, Vector3(10, 0, -1.1))
	for npc_hand in bandit.hands:
		if not npc_hand.is_free():
			bandit.stow(npc_hand)
	bandit.equip(PLANK, bandit.hand_right)
	bandit.locomotion.face(villager.global_position)
	await _physics_frames(10)
	var before := bandit.hand_right.get_durability()
	bandit.strike_at(villager)
	await _physics_frames(roundi(bandit.swing_contact_time() * Engine.physics_ticks_per_second) + 10)
	_check("an NPC's landed blow wears its plank (%d -> %d)" % [before, bandit.hand_right.get_durability()],
		bandit.hand_right.get_durability() == before - PLANK.wear_per_hit)
	Destructible.write(bandit.hand_right.get_held(), PLANK.wear_per_hit)
	await _physics_frames(30)
	bandit.strike_at(villager)
	await _physics_frames(roundi(bandit.swing_contact_time() * Engine.physics_ticks_per_second) + 10)
	_check("the NPC's plank broke out of its hand", bandit.hand_right.is_free())
	await _physics_frames(30)
	_check("the NPC swings again bare-handed", bandit.strike_at(villager))
	await _physics_frames(40)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _hold(data: ItemData, hand: HandSlot) -> Node3D:
	var item := data.spawn()
	add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(self)
	hand.hold(item)
	return item


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc: Npc = scene.instantiate()
	npc.position = at
	add_child(npc)
	await _physics_frames(5)
	npc.brain.shut_down()
	npc.health.max_health = 100000
	npc.health.reset()
	return npc


func _add_target(at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.5)
	shape.shape = box
	body.add_child(shape)
	var destructible := Destructible.new()
	destructible.indestructible = true
	body.add_child(destructible)
	body.position = at
	add_child(body)


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
