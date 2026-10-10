extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const HAMMER := preload("res://resources/items/hammer.tres")
const LAMP := preload("res://resources/items/oil_lamp.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 40.0)
	var npc := _spawn(Vector3(0, 0.05, 0))
	var other := _spawn(Vector3(6, 0.05, 0))
	await TestWorld.physics_frames(self, 5)
	npc.brain.shut_down()
	other.brain.shut_down()
	npc.holster.sheathe_delay = 0.5
	for hand in npc.hands:
		if not hand.is_free():
			hand.release().queue_free()
	for entry in npc.inventory.get_entries():
		npc.inventory.remove(entry)
	npc.equip(HAMMER, npc.hand_right)
	npc.equip(LAMP, npc.hand_left)
	var hammer := npc.hand_right.get_held()
	Destructible.write(hammer, 7)
	var hips := npc.holster.get_slots()

	await TestWorld.physics_frames(self, 50)
	_report(npc.hand_right.is_free() and hips[0].get_held() == hammer,
		"out of combat the hammer moves to the right hip")
	_report(npc.hand_left.get_held() != null and hips[1].is_free(), "the lamp stays in hand")
	_report((hammer as CollisionObject3D).collision_layer == 0, "a holstered hammer has no collision")
	var hip_y := hammer.global_position.y
	_report(hip_y > 0.5 and hip_y < 1.1, "the hammer hangs at hip height (%.2f)" % hip_y)

	npc.hold_grudge(other)
	await TestWorld.physics_frames(self, 30)
	_report(npc.hand_right.get_held() == hammer and npc.holster.is_holstered() == false,
		"combat draws the hammer back into the right hand")
	_report(Destructible.read(hammer) == 7, "the hammer keeps its wear")

	npc.holster.sheathe()
	_report(npc.hand_right.is_free(), "sheathed again for the strike check")
	npc.strike_at(other)
	_report(npc.get_weapon_hand() == npc.hand_right, "a strike draws the hammer before swinging")

	npc.holster.sheathe()
	npc.health.apply_damage(DamageInfo.new(9999))
	await TestWorld.physics_frames(self, 3)
	_report(is_instance_valid(hammer) and hammer.get_parent() == self and hips[0].is_free(),
		"a dead NPC drops its holstered hammer into the world")
	_report((hammer as CollisionObject3D).collision_layer != 0, "the dropped hammer collides again")

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _spawn(at: Vector3) -> Npc:
	var npc: Npc = VILLAGER.instantiate()
	npc.position = at
	add_child(npc)
	return npc


func _report(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
