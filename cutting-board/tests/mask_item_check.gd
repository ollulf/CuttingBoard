extends Node3D

## Headless checks that masks are real items: the player starts with their own mask on,
## a mask knocked off a dead villager lies in the world as an item that can be taken into
## the inventory and worn from there, a mask in hand goes on with a click, and a mask
## left on a dead face is found in the body's inventory and comes off the face when it is
## taken. Prints PASS/FAIL per check and quits with the number of failures as the exit
## code.
##
##   godot --headless --path cutting-board res://tests/mask_item_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")

const MASK := Equipment.Slot.MASK

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var player = PLAYER.instantiate()
	# The player starts bare-faced since the opening; these checks begin masked.
	player.get_node("%Equipment").starting_items = Array([preload("res://resources/items/player_mask.tres")], TYPE_OBJECT, &"Resource", ItemData)
	add_child(player)
	await _physics_frames(5)
	_starting_mask(player)
	await _knocked_off_mask(player)
	await _wear_from_hand(player)
	await _mask_left_on_body(player)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _starting_mask(player) -> void:
	var equipment: Equipment = player.equipment
	_check("player starts with their own mask on", equipment.get_item(MASK) == PLAYER_MASK)
	_check("the player's body wears it", player.body.mask == PLAYER_MASK)
	_check("the starting mask is a mask record", PLAYER_MASK.item_type == ItemData.Type.MASK)
	_check("the starting mask has an icon", PLAYER_MASK.icon != null)


## A villager whose mask always pops is killed in front of the player. The mask has to
## turn up as a world item, be taken with E like anything else, and go into the Mask slot
## once the player's own is off.
func _knocked_off_mask(player) -> void:
	var villager: Npc = await _spawn_villager(Vector3(0, 0, -1.5), 1.0)
	villager.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(90)

	var found := _loose_masks()
	_check("a mask item lies in the world after the death", found.size() == 1)
	if found.is_empty():
		return
	var carryable: Carryable = found[0]
	var item := carryable.get_parent() as Node3D
	_check("it is the villager's mask", carryable.item_data == VILLAGER_MASK)
	_check("it is a physics body", item is RigidBody3D)
	_check("it has come to rest near the body", item.global_position.y < 1.0)

	# Look straight at it and press E, the way the player would. The corpse goes first:
	# where the mask lands is random, and a limb in the line of sight would be what the
	# ray finds instead.
	villager.queue_free()
	await _physics_frames(2)
	var inventory: Inventory = player.inventory
	player.global_position = Vector3(item.global_position.x, 0.0, item.global_position.z + 1.8)
	player.velocity = Vector3.ZERO
	await _physics_frames(2)
	(player.camera_pivot as Node3D).look_at(item.global_position)
	await _physics_frames(3)
	_check("the mask is under the crosshair", player.interactor.get_hovered() == item)
	player.interactor.interact(inventory)
	await _frames(2)
	_check("taking it removes it from the world", not is_instance_valid(item))
	var entry := _entry_of(inventory, VILLAGER_MASK)
	_check("taking it puts it in the inventory", entry != null)
	if entry == null:
		return

	# The inventory screen's two moves: the worn mask off into the grid, then the new one
	# on from it.
	var equipment: Equipment = player.equipment
	_check("the Mask slot refuses a second mask", not equipment.equip(MASK, VILLAGER_MASK))
	var own := equipment.unequip(MASK)
	inventory.add(own)
	_check("the player's mask comes off into the grid", _entry_of(inventory, PLAYER_MASK) != null)
	_check("the Mask slot takes the villager's mask", equipment.equip(MASK, entry.data, entry.durability))
	inventory.remove(entry)
	_check("the villager's mask is worn", equipment.get_item(MASK) == VILLAGER_MASK)
	_check("the body wears the villager's mask", player.body.mask == VILLAGER_MASK)
	_check("the Mask slot refuses a rock", not equipment.accepts(MASK, load("res://resources/items/rock.tres")))


## The player's own mask, drawn into a hand from the grid, goes on with a click and the
## villager's mask comes off into that hand in its place.
func _wear_from_hand(player) -> void:
	var inventory: Inventory = player.inventory
	var hand: HandSlot = player.hand_right
	var entry := _entry_of(inventory, PLAYER_MASK)
	_check("the player's mask can be drawn into a hand", player.hotbar.hold_entry(entry, hand))
	_check("the hand holds the mask item", hand.get_item_data() == PLAYER_MASK)
	_check("a held mask is put on", player.wear_held(hand))
	await _frames(2)
	_check("the player's mask is back on", player.equipment.get_item(MASK) == PLAYER_MASK)
	_check("the villager's mask is in the hand", hand.get_item_data() == VILLAGER_MASK)
	_check("a held rock is not put on", not player.wear_held(_rock_hand(player)))
	player.hotbar.stow_hands()
	await _frames(2)


## A villager whose mask never pops keeps it on its dead face, listed in its inventory.
## Taking it from there takes it off the face.
func _mask_left_on_body(player) -> void:
	var villager: Npc = await _spawn_villager(Vector3(4, 0, -1.5), 0.0)
	villager.health.apply_damage(DamageInfo.new(9999))
	await _physics_frames(30)
	var before := _loose_masks().size()
	var entry := _entry_of(villager.inventory, VILLAGER_MASK)
	_check("a mask left on a corpse is in its inventory", entry != null)
	var body: HumanBody = villager.body
	_check("the corpse still wears it", _face_of(body) != null)
	if entry == null:
		return
	# The inventory screen moving it from the body's grid into the player's.
	var inventory: Inventory = player.inventory
	inventory.add(entry.data, entry.durability)
	villager.inventory.remove(entry)
	await _frames(2)
	_check("taking it takes it off the face", _face_of(body) == null)
	_check("no extra mask item appeared", _loose_masks().size() == before)


func _spawn_villager(at: Vector3, pop_chance: float) -> Npc:
	var villager: Npc = VILLAGER.instantiate()
	add_child(villager)
	villager.global_position = at
	await _physics_frames(5)
	villager.brain.shut_down()
	villager.body.mask_pop_chance = pop_chance
	return villager


## Every mask lying loose in the level.
func _loose_masks() -> Array[Carryable]:
	var masks: Array[Carryable] = []
	for node in find_children("Carryable", "Carryable", true, false):
		var carryable := node as Carryable
		if carryable.item_data is MaskData and carryable.get_parent().get_parent() == self:
			masks.append(carryable)
	return masks


func _entry_of(inventory: Inventory, data: ItemData) -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data == data:
			return entry
	return null


## The face hung on a body's head, or null.
func _face_of(body: HumanBody) -> Node3D:
	var attachment := body.skeleton.get_node_or_null("HeadAttachment")
	if attachment == null:
		return null
	for child in attachment.get_children():
		if not child.is_queued_for_deletion():
			return child
	return null


func _rock_hand(player) -> HandSlot:
	var hand: HandSlot = player.hand_left
	var rock := load("res://resources/items/rock.tres") as ItemData
	player.interactor.spawn_into_hand(rock, -1, hand)
	return hand


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
