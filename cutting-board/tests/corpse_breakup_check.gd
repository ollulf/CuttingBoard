extends Node3D

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const LOOT := preload("res://resources/items/shattered_mask.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	await TestWorld.bake(TestWorld.add_nav_region(self))

	var empty := _spawn(Vector3(0, 0.05, 0))
	var full := _spawn(Vector3(6, 0.05, 0))
	await _physics_frames(5)
	empty.brain.shut_down()
	full.brain.shut_down()

	_kill(empty)
	_clear(empty.inventory)
	_kill(full)
	full.inventory.add(LOOT)
	var empty_body := empty.body as HumanBody
	var full_body := full.body as HumanBody
	await _wait(0.5)
	_check("an empty corpse lies still while it settles", not empty_body.is_falling_apart())
	await _wait(1.5)
	_check("an empty corpse falls apart after settling", empty_body.is_falling_apart())
	var joints_off := true
	for bone in _bones_of(empty_body):
		joints_off = joints_off and bone.joint_type == PhysicalBone3D.JOINT_TYPE_NONE
	_check("its limbs come loose", joints_off)
	_check("a corpse with loot stays whole", not full_body.is_falling_apart())
	await _wait(1.6)
	var no_collision := true
	for bone in _bones_of(empty_body):
		no_collision = no_collision and bone.collision_layer == 0 and bone.collision_mask == 0
	_check("the pieces lose collision", no_collision)
	await _wait(1.5)
	var lowest := INF
	var highest := -INF
	for bone in _bones_of(empty_body):
		lowest = minf(lowest, bone.global_position.y)
		highest = maxf(highest, bone.global_position.y)
	_check("the pieces sink into the ground", highest < 0.15 and lowest < 0.0)
	await _wait(2.0)
	_check("the empty corpse is freed", not is_instance_valid(empty))
	_check("the looted corpse is still there", is_instance_valid(full) and not full_body.is_falling_apart())

	full.inventory.add_viewer()
	_clear(full.inventory)
	await _wait(0.5)
	_check("it waits while the loot window is open", not full_body.is_falling_apart())
	full.inventory.remove_viewer()
	await _physics_frames(2)
	_check("it falls apart once the window closes", full_body.is_falling_apart())
	await _wait(5.0)
	_check("the emptied corpse is freed", not is_instance_valid(full))

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _spawn(at: Vector3) -> Npc:
	var npc := BANDIT.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _kill(npc: Npc) -> void:
	npc.health.apply_damage(DamageInfo.new(100000, null))


func _clear(inventory: Inventory) -> void:
	for entry in inventory.get_entries().duplicate():
		inventory.remove(entry)


func _bones_of(body: HumanBody) -> Array[PhysicalBone3D]:
	var bones: Array[PhysicalBone3D] = []
	for child in body.physical_bones.get_children():
		if child is PhysicalBone3D:
			bones.append(child)
	return bones


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
