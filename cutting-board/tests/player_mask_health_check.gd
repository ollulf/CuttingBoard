extends Node3D

## Headless checks that the player's worn mask is their health: health mirrors the
## mask's durability both ways, a blow anywhere wears the mask, a mask worn through breaks
## off (a Shattered Mask drops, the slot empties) and the player stands on with the bare
## face's small pool, dying only once that is gone; swapping masks swaps health, and glue
## mends the mask. Prints PASS/FAIL per check and quits with the number of failures as
## the exit code.
##
##   godot --headless --path cutting-board res://tests/player_mask_health_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")
const SHATTERED_MASK := preload("res://resources/items/shattered_mask.tres")
const WOOD_GLUE := preload("res://scenes/items/wood_glue.tscn")

const MASK := Equipment.Slot.MASK

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	await _bare_player()
	await _mask_is_health()
	await _swap_masks()
	await _glue_mends_the_mask()
	await _break_then_bare_death()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## Bare-faced from the start (the intro): the small bare pool.
func _bare_player() -> void:
	var player = PLAYER.instantiate()
	add_child(player)
	await TestWorld.physics_frames(self, 3)
	var health: Health = player.health
	_check("a bare-faced player has the bare pool", health.max_health == player.bare_health
			and health.get_current() == player.bare_health)
	# Putting a mask on makes health the mask.
	player.equipment.equip(MASK, PLAYER_MASK, 70)
	_check("a mask put on becomes health", health.max_health == PLAYER_MASK.durability
			and health.get_current() == 70)
	# Taking it off goes back to the bare face, which was not refilled meanwhile.
	player.equipment.unequip(MASK)
	_check("taking it off goes back to the bare pool", health.get_current() == player.bare_health
			and health.max_health == player.bare_health)
	player.queue_free()
	await _frames(2)


## Health and the Mask slot's durability are one number.
func _mask_is_health() -> void:
	var player = await _masked_player(Vector3(0, 0, 0))
	var health: Health = player.health
	var equipment: Equipment = player.equipment
	_check("full mask, full health", health.max_health == PLAYER_MASK.durability
			and health.get_current() == PLAYER_MASK.durability)
	# A body blow (not just the face) wears the mask now.
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), 25)
	_check("damage lowers the mask's durability", equipment.get_durability(MASK) == PLAYER_MASK.durability - 25)
	_check("health follows", health.get_current() == PLAYER_MASK.durability - 25)
	_check("the hidden body's mask shows the same wear", player.body.mask_durability == PLAYER_MASK.durability - 25)
	# Wear written to the slot from elsewhere is health too.
	equipment.set_durability(MASK, 40)
	_check("the slot's durability sets health", health.get_current() == 40)
	player.queue_free()
	await _frames(2)


## A different mask brings its own durability as health; the old one keeps its wear.
func _swap_masks() -> void:
	var player = await _masked_player(Vector3(3, 0, 0))
	var health: Health = player.health
	var equipment: Equipment = player.equipment
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), 30)
	var entry: InventoryEntry = null
	player.inventory.add(VILLAGER_MASK, 55)
	for e in player.inventory.get_entries():
		if e.data == VILLAGER_MASK:
			entry = e
	_check("swap goes through", entry != null and equipment.swap_from(MASK, player.inventory, entry))
	_check("health is the new mask's", health.max_health == VILLAGER_MASK.durability and health.get_current() == 55)
	var old: InventoryEntry = null
	for e in player.inventory.get_entries():
		if e.data == PLAYER_MASK:
			old = e
	_check("the old mask keeps its wear in the bag", old != null and old.durability == PLAYER_MASK.durability - 30)
	player.queue_free()
	await _frames(2)


## Glue heals, and what it heals is the mask.
func _glue_mends_the_mask() -> void:
	var player = await _masked_player(Vector3(6, 0, 0))
	var equipment: Equipment = player.equipment
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), 50)
	var glue = WOOD_GLUE.instantiate()
	add_child(glue)
	await _frames(1)
	_check("glue can mend a worn mask", glue._can_mend(player))
	glue.mend(player.health, glue.heal_amount, 0.0, 1)
	_check("glue raises the mask's durability",
			equipment.get_durability(MASK) == PLAYER_MASK.durability - 50 + glue.heal_amount)
	glue.queue_free()
	player.queue_free()
	await _frames(2)


## Worn through, the mask breaks and the player lives on bare-faced; then the bare face
## runs out and that is death.
func _break_then_bare_death() -> void:
	var player = await _masked_player(Vector3(-3, 0, 0))
	var health: Health = player.health
	var equipment: Equipment = player.equipment
	var died := [false]
	health.died.connect(func(_i: DamageInfo) -> void: died[0] = true)
	var shattered_before := _loose_shattered()
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), PLAYER_MASK.durability + 40)
	await _frames(3)
	_check("the mask breaks at 0", equipment.is_free(MASK) and player.body.mask == null)
	_check("a Shattered Mask drops", _loose_shattered() == shattered_before + 1)
	_check("the player lives on", health.is_alive() and not died[0])
	_check("with the bare pool", health.max_health == player.bare_health
			and health.get_current() == player.bare_health)
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), player.bare_health - 5)
	_check("the bare face takes wear", health.get_current() == 5 and health.is_alive())
	_hit(player, player.global_position + Vector3(0, 1.0, -0.4), 10)
	_check("bare health running out kills", died[0] and not health.is_alive())
	await _frames(5)
	player.queue_free()
	await _frames(2)


func _masked_player(at: Vector3) -> Node:
	var player = TestWorld.masked_player(PLAYER)
	add_child(player)
	player.global_position = at
	await TestWorld.physics_frames(self, 3)
	return player


func _hit(actor: Node, at: Vector3, amount: int) -> void:
	var info := DamageInfo.new(amount)
	info.position = at
	info.direction = Vector3.BACK
	Health.find_in(actor).apply_damage(info)


func _loose_shattered() -> int:
	return find_children("Carryable", "Carryable", true, false).filter(
		func(c: Node) -> bool: return (c as Carryable).item_data == SHATTERED_MASK \
				and not c.get_parent().is_queued_for_deletion()).size()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1
