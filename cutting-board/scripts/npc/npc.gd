class_name Npc
extends CharacterBody3D

## A non-player character. This script only wires the parts together and answers the
## few questions every action asks; what the NPC is like lives in its components — its
## Faction says whose side it is on, its Brain's actions say what it will do about it.
##
## Friendly and hostile are not two kinds of NPC. A villager and a bandit are this same
## scene with a different faction and differently tuned actions.

## What the NPC starts with in each hand and in its pockets. Built into real objects on
## spawn, the same way the player's hotbar draws an item into a hand.
@export var right_hand_item: ItemData
@export var left_hand_item: ItemData
@export var starting_items: Array[ItemData] = []

@export_group("Sounds")
## Grunts from behind the mask when hit, and the last one when killed.
@export var hurt_sound: SoundBank = preload("res://resources/audio/npc_hurt.tres")
## Seconds between a blow landing and the grunt it gets out of the NPC.
@export var hurt_sound_delay := 0.07
@export var death_sound: SoundBank = preload("res://resources/audio/npc_death.tres")
## The body hitting the ground, this many seconds after the killing blow.
@export var body_fall_sound: SoundBank = preload("res://resources/audio/body_fall.tres")
@export var body_fall_delay := 0.55
@export var throw_sound: SoundBank = preload("res://resources/audio/throw.tres")
@export_group("")

@onready var locomotion: Locomotion = %Locomotion
@onready var memory: Memory = %Memory
@onready var faction: Faction = %Faction
@onready var health: Health = %Health
@onready var brain: Brain = %Brain
@onready var sight: Sight = %Sight
@onready var melee: MeleeAttack = %MeleeAttack
@onready var eyes: Node3D = %Eyes
@onready var visual: Node3D = %Visual
@onready var body: HumanBody = %Body
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var hands: Array[HandSlot] = [hand_right, hand_left]

## Where the NPC was placed, which is what it wanders around.
var home := Vector3.ZERO


func _ready() -> void:
	home = global_position
	sight.spotted.connect(memory.remember)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	brain.setup(self)
	# Deferred so the item scenes are built once the level around the NPC is in place.
	_equip_loadout.call_deferred()


## The closest living enemy this NPC knows of, judged by where each was last seen, or
## null when it knows of none.
func nearest_hostile() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for actor in memory.get_known():
		if not faction.is_hostile_to(actor) or not Health.is_node_alive(actor):
			continue
		var distance := flat_distance_to(memory.last_seen_position(actor))
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest


## Who to fight: the nearest known enemy of the most preferred faction in this NPC's
## priority list, or failing any of those, the nearest known enemy at all.
func get_attack_target() -> Node3D:
	var priorities: Array[StringName] = []
	if faction.data:
		priorities = faction.data.priority_targets
	var best: Node3D = null
	var best_rank := priorities.size()
	var best_distance := INF
	for actor in memory.get_known():
		if not faction.is_hostile_to(actor) or not Health.is_node_alive(actor):
			continue
		var theirs := Faction.find_in(actor)
		var rank := priorities.find(theirs.data.id) if theirs.data else -1
		if rank < 0:
			rank = priorities.size()
		var distance := flat_distance_to(memory.last_seen_position(actor))
		if rank < best_rank or (rank == best_rank and distance < best_distance):
			best = actor
			best_rank = rank
			best_distance = distance
	return best


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Swings at `target` with whatever weapon is in hand, or a bare fist. The eyes are
## turned onto the target first, since MeleeAttack strikes along them — without that a
## crouching target would be swung over.
func strike_at(target: Node3D) -> void:
	var aim_point := target.global_position + Vector3.UP * sight.target_height
	if not eyes.global_position.is_equal_approx(aim_point):
		eyes.look_at(aim_point)
	melee.play_swing()
	melee.strike(get_weapon_hand())


## The hand holding a weapon, or null when neither does. Something held that is not a
## weapon is not swung, the same rule the player's punch follows.
func get_weapon_hand() -> HandSlot:
	for hand in hands:
		var held := hand.get_item_data()
		if held and held.is_weapon():
			return hand
	return null


## Builds an item into a real object and puts it in `hand`. Returns false when it could
## not be — no world scene, or the hand is full — and nothing is left behind.
func equip(data: ItemData, hand: HandSlot) -> bool:
	if data == null or hand == null or not hand.is_free():
		return false
	var item := data.spawn()
	if item == null:
		return false
	# HandSlot.hold reparents, which needs the item to have a parent already.
	add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(self)
	if hand.hold(item):
		return true
	item.queue_free()
	return false


## An empty hand, or null when both are full.
func get_free_hand() -> HandSlot:
	for hand in hands:
		if hand.is_free():
			return hand
	return null


## The first item in the inventory meant for throwing, or null when there is none.
func find_throwable() -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data and entry.data.throwable:
			return entry
	return null


## Takes an item out of the inventory and into `hand`, keeping the wear it had. The
## record is only removed once the object is really in the hand, so a failed draw loses
## nothing.
func draw(entry: InventoryEntry, hand: HandSlot) -> bool:
	if entry == null or not equip(entry.data, hand):
		return false
	Destructible.write(hand.get_held(), entry.durability)
	inventory.remove(entry)
	return true


## The reverse of draw: banks what `hand` holds back into the inventory. Returns false,
## leaving the item in the hand, when there is no room for it.
func stow(hand: HandSlot) -> bool:
	var data := hand.get_item_data()
	if data == null or not inventory.add(data, hand.get_durability()):
		return false
	hand.release().queue_free()
	return true


## Lets go of what `hand` holds, sending it off at `launch` — metres per second, world
## space. Released like the player's throw, so the item arms itself and hurts what it
## lands on.
func throw_from(hand: HandSlot, launch: Vector3) -> void:
	var item := hand.release()
	if item == null:
		return
	item.reparent(get_parent(), true)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.return_to_world()
	var body := item as RigidBody3D
	if body == null:
		return
	# The hand sits right at the body's side, so the item is kept from colliding with
	# its own thrower until it has had a moment to clear it.
	HumanBody.keep_clear_of(body, self)
	body.linear_velocity = launch
	Sfx.play_at(throw_sound, body.global_position)


## Lets go of whatever each hand holds, leaving it in the world at rest.
func drop_held() -> void:
	for hand in hands:
		var item := hand.release()
		if item == null:
			continue
		item.reparent(get_parent(), true)
		var carryable := item.get_node_or_null("Carryable") as Carryable
		if carryable:
			carryable.return_to_world()


func _equip_loadout() -> void:
	equip(right_hand_item, hand_right)
	equip(left_hand_item, hand_left)
	for data in starting_items:
		inventory.add(data)


## Being hit by someone is as good as seeing them: an NPC struck from behind turns to
## deal with whoever did it. A thrown item is not an actor, so it goes unattributed.
##
## A hit that does not kill also lands physically: the body flinches from the force at
## the part that was struck, and the whole NPC is shoved back a little. The killing hit
## is left to _on_died, which drops the body instead.
func _on_damaged(info: DamageInfo) -> void:
	var attacker := info.source as Node3D
	if attacker and attacker != self and Faction.find_in(attacker):
		memory.remember(attacker)
	if health.is_alive():
		# A beat after the blow rather than on top of it: the grunt is a reaction, and
		# it keeps the two from stacking into one loud thump.
		get_tree().create_timer(hurt_sound_delay).timeout.connect(
			func() -> void:
				if is_instance_valid(eyes) and health.is_alive():
					Sfx.play_at(hurt_sound, eyes.global_position)
		)
		body.flinch(info)
		locomotion.push(body.get_knockback(info))


## Dead is for good: the NPC stops thinking, seeing and moving, lets go of what it held
## and goes limp, falling the way the killing blow and its own momentum send it. The
## body stays, with its inventory, for the player to search — the interaction ray finds
## it by its limbs, so the standing capsule is switched off rather than left upright
## where the NPC used to be.
func _on_died(info: DamageInfo) -> void:
	brain.shut_down()
	locomotion.stop()
	locomotion.set_physics_process(false)
	sight.set_physics_process(false)
	# Out of the actor group, so nobody keeps fighting or fleeing a corpse.
	remove_from_group(Faction.GROUP)
	drop_held()
	collision_shape.set_deferred("disabled", true)
	body.go_limp(info, velocity)
	velocity = Vector3.ZERO
	Sfx.play_at(death_sound, eyes.global_position)
	get_tree().create_timer(body_fall_delay).timeout.connect(
		func() -> void:
			if is_instance_valid(body):
				Sfx.play_at(body_fall_sound, body.get_center())
	)
