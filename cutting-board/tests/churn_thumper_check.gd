extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const DUMMY := preload("res://scenes/characters/training_dummy.tscn")
const THUMPER := preload("res://resources/items/churn_thumper.tres")
const SPIKE := preload("res://resources/items/railroad_spike.tres")
const SPIKE_SCENE := preload("res://scenes/items/railroad_spike.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60.0)
	var player = PLAYER.instantiate()
	add_child(player)
	var dummy: Node3D = DUMMY.instantiate()
	add_child(dummy)
	dummy.position = Vector3(0, 0, -7)
	await TestWorld.physics_frames(self, 10)
	_record()

	var hand: HandSlot = player.hand_right
	var thumper: Node3D = player.interactor.spawn_into_hand(THUMPER, -1, hand)
	_check("the Thumper is used from the hand", Usable.find_in(thumper).is_used_in_hand())
	_check("it comes unarmed", not thumper.armed)

	_click(player, hand)
	await TestWorld.physics_frames(self, 2)
	_check("an unarmed click starts the rearm", player.is_using())
	await get_tree().create_timer(0.5).timeout
	_check("mid-rearm it is not armed yet", not thumper.armed)
	await get_tree().create_timer(1.2).timeout
	_check("the rearm arms it", thumper.armed)
	_check("the rearm is over", not player.is_using())

	var dry := [0]
	thumper.dry_fired.connect(func() -> void: dry[0] += 1)
	_click(player, hand)
	await TestWorld.physics_frames(self, 2)
	_check("no spike: a dry click", dry[0] == 1)
	_check("no spike: still armed", thumper.armed)
	_check("no spike: nothing in flight", _spikes_in_world().is_empty())

	for i in 3:
		player.inventory.add(SPIKE)
	var wear_before := Destructible.read(thumper)
	var health := Health.find_in(dummy)
	var health_before := health.get_current()
	_click(player, hand)
	await TestWorld.physics_frames(self, 1)
	_check("the shot takes one spike (%d left)" % _spike_count(player), _spike_count(player) == 2)
	_check("the shot leaves it unarmed", not thumper.armed)
	_check("the shot wears it", Destructible.read(thumper) < wear_before)
	_check("the recoil pushes the player back", player.velocity.z > 0.5)
	var flying := _spikes_in_world()
	_check("one spike is in flight", flying.size() == 1)
	if not flying.is_empty():
		flying[0].shatter_chance = 0.0

	await get_tree().create_timer(0.5).timeout
	_click(player, hand)
	await TestWorld.physics_frames(self, 2)
	_check("after a shot the click rearms, not fires", player.is_using() and _spike_count(player) == 2)

	await get_tree().create_timer(1.5).timeout
	_check("the spike hurts the dummy (%d -> %d)" % [health_before, health.get_current()],
			health.get_current() < health_before)
	var spike: RigidBody3D = flying[0] if not flying.is_empty() else null
	_check("the spike sticks in the dummy", spike != null and spike.stuck_in == dummy and spike.freeze)
	_check("it is armed again after the rearm", thumper.armed)

	if spike:
		await player.get_tree().physics_frame
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(spike.global_position.x, 0.0, spike.global_position.z + 1.6)
		await TestWorld.physics_frames(self, 3)
		_aim(player, spike.global_position + spike.global_basis.z * 0.05)
		await TestWorld.physics_frames(self, 3)
		_check("the stuck spike is under the crosshair", player.interactor.get_hovered() == spike)
		player.interactor.interact(player.inventory)
		await TestWorld.physics_frames(self, 2)
		_check("E pulls the spike back into the bag", _spike_count(player) == 3 and not is_instance_valid(spike))

	await _check_shatter()
	await _check_ragdoll()

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check_shatter() -> void:
	var rolls := RandomNumberGenerator.new()
	rolls.seed = 7
	var broke := 0
	for i in 400:
		if rolls.randf() < 0.5:
			broke += 1
	_check("about half of the hits shatter (%d / 400)" % broke, broke > 160 and broke < 240)
	for shatters in [true, false]:
		var spike: RigidBody3D = SPIKE_SCENE.instantiate()
		spike.shatter_chance = 1.0 if shatters else 0.0
		spike.rng.seed = 3
		add_child(spike)
		spike.global_position = Vector3(5, 1.0, 0)
		spike.launch(Vector3(0, -20, 0))
		await TestWorld.physics_frames(self, 20)
		if shatters:
			_check("a shattering hit leaves no spike", not is_instance_valid(spike))
		else:
			_check("a sticking hit leaves the spike stuck",
					is_instance_valid(spike) and spike.stuck_in != null and spike.freeze)


func _check_ragdoll() -> void:
	var villager: Node3D = VILLAGER.instantiate()
	add_child(villager)
	villager.global_position = Vector3(-10, 0, 0)
	await TestWorld.physics_frames(self, 10)
	var spike := await _shoot_at(villager.body.get_center() + Vector3(0, 0.15, 0), 1)
	var holder := spike.get_parent() as BoneAttachment3D
	_check("a spike in a villager hangs from a bone (%s)" % spike.get_parent().name,
			holder != null and holder.get_parent() == villager.body.skeleton)
	var bone: PhysicalBone3D = _physical_bone(villager, holder.bone_name if holder else "")
	var before := bone.global_transform.affine_inverse() * spike.global_position if bone else Vector3.ZERO
	var height := spike.global_position.y
	Health.find_in(villager).apply_damage(DamageInfo.new(9999, self, DamageInfo.Type.PIERCE))
	await TestWorld.physics_frames(self, 150)
	var after := bone.global_transform.affine_inverse() * spike.global_position if bone else Vector3.ZERO
	_check("killed, the villager falls with the spike (%.2f -> %.2f)" % [height, spike.global_position.y],
			villager.body.is_limp() and spike.global_position.y < height - 0.3)
	_check("the spike stays on its limb as he falls (%.2f m off)" % before.distance_to(after),
			bone != null and before.distance_to(after) < 0.15)

	var victim: Node3D = VILLAGER.instantiate()
	add_child(victim)
	victim.global_position = Vector3(-14, 0, 0)
	await TestWorld.physics_frames(self, 10)
	var killer := await _shoot_at(victim.body.get_center() + Vector3(0, 0.15, 0), 9999)
	var killer_holder := killer.get_parent() as BoneAttachment3D
	var killer_bone: PhysicalBone3D = _physical_bone(victim, killer_holder.bone_name if killer_holder else "")
	var killer_before := killer_bone.global_transform.affine_inverse() * killer.global_position \
			if killer_bone else Vector3.ZERO
	await TestWorld.physics_frames(self, 150)
	_check("a killing spike hangs from a bone of the fallen body",
			victim.body.is_limp() and killer_bone != null and killer.get_parent() == killer_holder)
	_check("it stays on that limb as he falls",
			killer_bone != null and killer_before.distance_to(
				killer_bone.global_transform.affine_inverse() * killer.global_position) < 0.15)

	var corpse := await _shoot_at(_physical_bone(villager, "Chest").global_position, 10, Vector3.UP)
	var struck := corpse.stuck_in as PhysicalBone3D
	var corpse_holder := corpse.get_parent() as BoneAttachment3D
	_check("a spike in a corpse sticks in the bone it struck (%s)" % [corpse.stuck_in],
			struck != null and corpse_holder != null and corpse_holder.bone_name == struck.bone_name)
	_check("a spike in a corpse is still there to pull out", corpse.freeze and corpse.stuck_in != null)


func _shoot_at(target: Vector3, hit_damage: int, from := Vector3.BACK) -> RigidBody3D:
	var spike: RigidBody3D = SPIKE_SCENE.instantiate()
	spike.shatter_chance = 0.0
	spike.damage = hit_damage
	add_child(spike)
	spike.global_position = target + from * 1.5
	spike.launch(-from * 25.0)
	await TestWorld.physics_frames(self, 10)
	return spike


func _physical_bone(actor: Node, bone_name: String) -> PhysicalBone3D:
	for bone in actor.find_children("*", "PhysicalBone3D", true, false):
		if bone.bone_name == bone_name:
			return bone
	return null


func _record() -> void:
	_check("the Thumper is a weapon", THUMPER.is_weapon())
	_check("the Thumper has durability and wear", THUMPER.durability > 0 and THUMPER.wear_per_hit > 0)
	_check("the Thumper has an icon", THUMPER.icon != null)
	_check("a spike has an icon", SPIKE.icon != null)
	var bag := Inventory.new()
	var fitted := 0
	while bag.add(SPIKE) and fitted < 100:
		fitted += 1
	_check("a dozen or more spikes fit in a bag (%d)" % fitted, fitted >= 12)
	bag.free()


func _spike_count(player) -> int:
	var count := 0
	for entry in (player.inventory as Inventory).get_entries():
		if entry.data == SPIKE:
			count += 1
	return count


func _spikes_in_world() -> Array:
	var found := []
	for node in get_tree().root.find_children("*", "RigidBody3D", true, false):
		var carryable := node.get_node_or_null("Carryable") as Carryable
		if carryable and carryable.item_data == SPIKE:
			found.append(node)
	return found


func _aim(player, target: Vector3) -> void:
	var eye: Vector3 = player.camera.global_position
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	player.camera_pivot.rotation.x = atan2(target.y - eye.y, flat.length())


func _click(player, hand: HandSlot) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT if hand == player.hand_left else MOUSE_BUTTON_RIGHT
	event.pressed = true
	player._use_hand(hand, event)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1
