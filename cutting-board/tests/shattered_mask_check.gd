extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const MONGER := preload("res://scenes/characters/mask_monger.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")
const SHATTERED := preload("res://resources/items/shattered_mask.tres")
const BOTTLE := preload("res://resources/items/soul_bottle.tres")
const CHAIR := preload("res://scenes/characters/chair_creature.tscn")
const CHAIR_MASK := preload("res://resources/items/chair_mask.tres")
const CHAIR_MASK_SCENE := "res://scenes/items/chair_mask.tscn"
const SHATTERED_SCENE := "res://scenes/items/shattered_mask.tscn"

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_slab(Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	await _death_roll()
	await _chair_mask()
	await _monger_trades()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _death_roll() -> void:
	var shatter_seed := _seed_where(func(r: float) -> bool: return r < 0.75)
	var keep_seed := _seed_where(func(r: float) -> bool: return r >= 0.75)

	var shattered: Npc = await _spawn_villager(Vector3(-3, 0, -3), shatter_seed)
	shattered.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	var entry := _entry_of(shattered.inventory, SHATTERED)
	_check("a seeded roll shatters the mask", entry != null)
	_check("the whole mask is gone from the body", _entry_of(shattered.inventory, VILLAGER_MASK) == null)

	var kept: Npc = await _spawn_villager(Vector3(3, 0, -3), keep_seed)
	kept.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	var damaged := _entry_of(kept.inventory, VILLAGER_MASK)
	_check("another seed leaves it its own kind", damaged != null and _entry_of(kept.inventory, SHATTERED) == null)
	if damaged:
		_check("damaged: 10-25% of its durability left", damaged.durability >= roundi(VILLAGER_MASK.durability * 0.1)
				and damaged.durability <= roundi(VILLAGER_MASK.durability * 0.25))
		_check("a damaged mask keeps its faction", (damaged.data as MaskData).faction == VILLAGER_MASK.faction)

	var again: Npc = await _spawn_villager(Vector3(0, 0, -6), shatter_seed)
	again.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	_check("the roll repeats with its seed", _entry_of(again.inventory, SHATTERED) != null)

	var record: Resource = SHATTERED
	_check("a Shattered Mask is no mask to wear", not record is MaskData
			and SHATTERED.item_type != ItemData.Type.MASK)
	for npc in [shattered, kept, again]:
		npc.queue_free()
	await _frames(2)


func _chair_mask() -> void:
	var shatter_seed := _seed_where(func(r: float) -> bool: return r < 0.75)
	var keep_seed := _seed_where(func(r: float) -> bool: return r >= 0.75)

	var worn := await _spawn_chair(Vector3(-6, 0, 4), 0)
	var chair: Node3D = worn.get_node("%Chair")
	var full: int = CHAIR_MASK.durability
	_check("a chair's mask starts whole", chair.mask_durability == full)
	var body_hit := DamageInfo.new(5)
	body_hit.position = worn.global_position + Vector3(0, 0.3, 0.4)
	worn.health.apply_damage(body_hit)
	_check("a hit to the chair wears its mask (%d)" % chair.mask_durability,
			chair.mask_durability == full - 5)
	var head_hit := DamageInfo.new(5)
	head_hit.position = (chair.get_node("%Head") as Node3D).global_position
	worn.health.apply_damage(head_hit)
	_check("a hit to the head wears it twice as fast (%d)" % chair.mask_durability,
			chair.mask_durability == full - 15)
	var broke := [false]
	chair.mask_broken.connect(func() -> void: broke[0] = true)
	var heavy := DamageInfo.new(ceili((full - 15) / 2.0))
	heavy.position = head_hit.position
	worn.health.apply_damage(heavy)
	await _physics_frames(10)
	_check("worn through, the mask splits off mid-fight", broke[0] and chair.mask == null
			and worn.health.is_alive())
	_check("and leaves a Shattered Mask", _loose(SHATTERED_SCENE).size() == 1)

	var shattered := await _spawn_chair(Vector3(-2, 0, 4), shatter_seed)
	shattered.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	_check("a seeded roll shatters a dead chair's mask", _loose(SHATTERED_SCENE).size() == 2
			and _loose(CHAIR_MASK_SCENE).is_empty())

	var kept := await _spawn_chair(Vector3(2, 0, 4), keep_seed)
	kept.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	var left := _loose(CHAIR_MASK_SCENE)
	_check("another seed leaves it a Chair Mask", left.size() == 1)
	if left.size() == 1:
		var durability: int = (left[0] as Node).get_node("Destructible").durability
		_check("damaged: 10-25%% of its durability left (%d)" % durability,
				durability >= roundi(full * 0.1) and durability <= roundi(full * 0.25))
	for node in [worn, shattered, kept]:
		node.queue_free()
	for node in get_children():
		if node is RigidBody3D:
			node.queue_free()
	await _frames(2)


func _spawn_chair(at: Vector3, roll_seed: int) -> CharacterBody3D:
	var creature: CharacterBody3D = CHAIR.instantiate()
	add_child(creature)
	creature.global_position = at
	creature.set_process(false)
	await _physics_frames(5)
	(creature.get_node("%Chair")).mask_rng.seed = roll_seed
	return creature


func _loose(scene: String) -> Array:
	return get_children().filter(func(n: Node) -> bool:
		return n is RigidBody3D and n.scene_file_path == scene and not n.is_queued_for_deletion())


func _monger_trades() -> void:
	var monger: Npc = MONGER.instantiate()
	var player := PLAYER.instantiate()
	add_child(monger)
	add_child(player)
	monger.global_position = Vector3(0, 0.05, 10)
	player.global_position = Vector3(0, 0.05, 8.0)
	await _physics_frames(10)
	var ritual := monger.get_node("%Usable") as MaskBurnRitual
	var interactor := player.get_node("%Interactor") as Interactor
	var hand := player.get_node("%HandSlotRight") as HandSlot
	var inventory := player.get_node("%Inventory") as Inventory
	var equipment: Equipment = player.equipment
	_check("a Shattered Mask does not go in the Mask slot",
			not equipment.accepts(Equipment.Slot.MASK, SHATTERED))

	interactor.spawn_into_hand(VILLAGER_MASK, -1, hand)
	_check("a whole mask is offered nothing", ritual.get_prompt(player) == "" and not ritual.use(player))
	hand.release().queue_free()

	interactor.spawn_into_hand(VILLAGER_MASK, 20, hand)
	_check("without a soul, no repair is offered", ritual.get_prompt(player) == "")
	_check("and none is done", not ritual.use(player) and hand.get_durability() == 20)

	inventory.add(BOTTLE)
	inventory.add(BOTTLE)
	_check("with a soul, repair is offered", ritual.get_prompt(player) == "Repair mask (1 soul)")
	_check("the repair goes through", ritual.use(player))
	_check("the mask is back at full", hand.get_durability() == VILLAGER_MASK.durability)
	_check("it still is the villager's mask", hand.get_item_data() == VILLAGER_MASK)
	_check("one soul was paid", _count(inventory, BOTTLE) == 1)
	_check("a mended mask is offered nothing more", ritual.get_prompt(player) == "")
	hand.release().queue_free()

	interactor.spawn_into_hand(SHATTERED, -1, hand)
	_check("a Shattered Mask is offered for burning, not repair",
			ritual.get_prompt(player) == "Give shattered mask")
	var finished := [null]
	ritual.ritual_finished.connect(func(bottle: Node3D) -> void: finished[0] = bottle)
	_check("the Monger takes it", ritual.use(player) and hand.is_free())
	_check("no soul is spent on it", _count(inventory, BOTTLE) == 1)
	for i in 60 * 8:
		if not ritual.is_playing():
			break
		await get_tree().physics_frame
	var bottle := finished[0] as Node3D
	_check("it comes back as a Soul in a Bottle", bottle != null and is_instance_valid(bottle)
			and (bottle.get_node("Carryable") as Carryable).item_data == BOTTLE)
	monger.queue_free()
	player.queue_free()
	await _frames(2)


func _seed_where(test: Callable) -> int:
	var rng := RandomNumberGenerator.new()
	for s in range(1, 1000):
		rng.seed = s
		if test.call(rng.randf()):
			return s
	return 0


func _spawn_villager(at: Vector3, roll_seed: int) -> Npc:
	var villager: Npc = VILLAGER.instantiate()
	add_child(villager)
	villager.global_position = at
	await _physics_frames(5)
	villager.brain.shut_down()
	villager.body.mask_pop_chance = 0.0
	villager.body.mask_rng.seed = roll_seed
	return villager


func _entry_of(inventory: Inventory, data: ItemData) -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data == data:
			return entry
	return null


func _count(inventory: Inventory, data: ItemData) -> int:
	return inventory.get_entries().filter(func(e: InventoryEntry) -> bool: return e.data == data).size()


func _slab(size: Vector3, at: Vector3) -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
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
