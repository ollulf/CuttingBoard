extends Node3D

## Headless checks that masks break: a mask lying in the world breaks like a crate, both
## when it is struck and when it is thrown down hard; blows to an NPC's head wear its mask
## down, crack it and finally break it off with nothing left to pick up, while blows to
## the body leave it alone; the wear goes with a mask that comes off whole; and the
## player's own mask breaks the same way, emptying the Mask slot. Prints PASS/FAIL per
## check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/mask_break_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const VILLAGER_MASK_ITEM := preload("res://scenes/items/villager_mask.tscn")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")

const MASK := Equipment.Slot.MASK

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	await _mask_item_struck()
	await _mask_item_thrown()
	await _worn_mask_breaks()
	await _wear_goes_with_the_mask()
	await _player_mask_breaks()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## Struck like a crate: a hammer's worth at a time until it gives.
func _mask_item_struck() -> void:
	var item := VILLAGER_MASK_ITEM.instantiate() as RigidBody3D
	add_child(item)
	item.global_position = Vector3(-4, 0.2, 0)
	await _physics_frames(2)
	var destructible := item.get_node_or_null("Destructible") as Destructible
	_check("a mask item is destructible", destructible != null)
	if destructible == null:
		return
	_check("it starts with the record's durability", destructible.durability == VILLAGER_MASK.durability)
	destructible.damage(22)
	await _frames(1)
	_check("one blow does not break it", is_instance_valid(item))
	destructible.damage(22)
	await _frames(2)
	_check("a second blow breaks it", not is_instance_valid(item))
	_check("it breaks with a burst", _bursts().size() > 0)


## Thrown down hard enough, it breaks against the floor.
func _mask_item_thrown() -> void:
	var item := VILLAGER_MASK_ITEM.instantiate() as RigidBody3D
	add_child(item)
	item.global_position = Vector3(-6, 1.0, 0)
	await _physics_frames(2)
	item.linear_velocity = Vector3(0, -16, 0)
	await _physics_frames(20)
	_check("a mask thrown down hard breaks", not is_instance_valid(item))


## Blows to the body leave the mask alone; blows to the head wear it, crack it, and
## break it off.
func _worn_mask_breaks() -> void:
	var villager: Npc = await _spawn_villager(Vector3(0, 0, -3))
	var body: HumanBody = villager.body
	_check("the villager wears a mask", body.mask == VILLAGER_MASK and _face_of(body) != null)
	_check("it starts at full", body.mask_durability == VILLAGER_MASK.durability)

	_hit(villager, villager.global_position + Vector3(0, 1.05, -0.3), 10)
	_check("a body blow is not a head hit", not body.is_head_hit(villager.global_position + Vector3(0, 1.05, -0.3)))
	_check("a body blow leaves the mask alone", body.mask_durability == VILLAGER_MASK.durability)

	var loose_before := _loose_masks().size()
	_hit(villager, _head_point(body), 10)
	_check("a head blow wears the mask", body.mask_durability == VILLAGER_MASK.durability - 10)
	_check("a lightly worn mask shows no crack", _crack_of(body) == 0.0)
	_hit(villager, _head_point(body), 15)
	_check("a mask half gone shows a crack", _crack_of(body) > 0.0)
	# Every hit on a creature sprays splinters; the break adds a burst of its own.
	var bursts_before := _bursts().size()
	_hit(villager, _head_point(body), 15)
	await _frames(2)
	_check("the mask breaks once worn through", body.mask == null)
	_check("the face is bare", _face_of(body) == null)
	_check("the villager is still alive", villager.health.is_alive())
	_check("it breaks with a burst", _bursts().size() == bursts_before + 2)
	_check("nothing is left to pick up", _loose_masks().size() == loose_before)

	# Dying bare-faced drops no mask either.
	villager.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	_check("a bare-faced body drops no mask", _loose_masks().size() == loose_before)
	_check("nor keeps one in its pockets", _entry_of(villager.inventory, VILLAGER_MASK) == null)
	villager.queue_free()


## A battered mask knocked off a dead face is just as battered on the ground.
func _wear_goes_with_the_mask() -> void:
	var villager: Npc = await _spawn_villager(Vector3(4, 0, -3))
	villager.body.mask_pop_chance = 1.0
	_hit(villager, _head_point(villager.body), 12)
	var left: int = villager.body.mask_durability
	var before := _loose_masks()
	villager.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	var found: Carryable = null
	for carryable in _loose_masks():
		if not carryable in before:
			found = carryable
	_check("a worn mask still comes off a body whole", found != null)
	if found:
		_check("it keeps its wear", Destructible.read(found.get_parent()) == left)
	villager.queue_free()


func _player_mask_breaks() -> void:
	var player = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0, 4)
	await _physics_frames(5)
	var equipment: Equipment = player.equipment
	var body: HumanBody = player.body
	_check("the player's body wears their mask", body.mask == PLAYER_MASK)
	_check("at the slot's wear", body.mask_durability == equipment.get_durability(MASK))
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), 10)
	_check("a body blow leaves the player's mask alone", equipment.get_durability(MASK) == PLAYER_MASK.durability)
	_hit(player, _head_point(body), 10)
	_check("a head blow wears the mask in the Mask slot", equipment.get_durability(MASK) == PLAYER_MASK.durability - 10)
	for i in 4:
		_hit(player, _head_point(body), 10)
	await _frames(2)
	_check("the player's mask breaks", body.mask == null)
	_check("the Mask slot is empty", equipment.is_free(MASK))
	_check("the player is still alive", player.health.is_alive())
	_check("nothing of it is left in the inventory", _entry_of(player.inventory, PLAYER_MASK) == null)

	# A fresh mask put back on starts whole: the broken one's wear does not linger.
	equipment.equip(MASK, PLAYER_MASK)
	_check("a new mask goes on whole", body.mask == PLAYER_MASK and body.mask_durability == PLAYER_MASK.durability)
	player.queue_free()
	await _frames(2)


func _spawn_villager(at: Vector3) -> Npc:
	var villager: Npc = VILLAGER.instantiate()
	add_child(villager)
	villager.global_position = at
	await _physics_frames(5)
	villager.brain.shut_down()
	return villager


## Hits `actor` for `amount` at `at`, from the front.
func _hit(actor: Node, at: Vector3, amount: int) -> void:
	var info := DamageInfo.new(amount)
	info.position = at
	info.direction = Vector3.BACK
	Health.find_in(actor).apply_damage(info)


## A point on the face: in front of the head, a little above the base of the skull.
func _head_point(body: HumanBody) -> Vector3:
	var head := body.skeleton.find_bone("Head")
	var frame := body.skeleton.global_transform * body.skeleton.get_bone_global_pose(head)
	return frame * Vector3(0, 0.12, -0.15)


func _crack_of(body: HumanBody) -> float:
	var face := _face_of(body)
	if face == null:
		return -1.0
	for mi in face.find_children("*", "MeshInstance3D", true, false):
		var material := (mi as MeshInstance3D).material_override as ShaderMaterial
		if material:
			return material.get_shader_parameter(&"crack")
	return 0.0


## The face hung on a body's head, or null.
func _face_of(body: HumanBody) -> Node3D:
	var attachment := body.skeleton.get_node_or_null("HeadAttachment")
	if attachment == null:
		return null
	for child in attachment.get_children():
		if not child.is_queued_for_deletion():
			return child
	return null


## Break bursts and hit splinters alike: both are BreakBursts.
func _bursts() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return child is BreakBurst)


## Every mask lying loose in the level.
func _loose_masks() -> Array[Carryable]:
	var masks: Array[Carryable] = []
	for node in find_children("Carryable", "Carryable", true, false):
		var carryable := node as Carryable
		if carryable.item_data is MaskData and carryable.get_parent().get_parent() == self \
				and not carryable.get_parent().is_queued_for_deletion():
			masks.append(carryable)
	return masks


func _entry_of(inventory: Inventory, data: ItemData) -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data == data:
			return entry
	return null


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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
