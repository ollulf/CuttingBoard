class_name CombatTracker
extends Node

## Says whether its owner — the player — is in a fight, and with whom. The HUD reads it
## to pin the player's own bar on screen and to put the enemy's bar up top, Gothic style.
##
## A fight is any of: the owner hitting something with a Health, something hitting the
## owner, or a hostile NPC going for the owner. It ends `linger` seconds after the last
## of these. The target is whoever was last hit by or hit the owner; without one, the
## nearest NPC coming for the owner.
##
## Like DamageNumbers, nothing has to opt in: every Health and every hand is hooked as it
## enters the tree, so a new enemy is tracked the moment it is placed.

signal combat_changed(in_combat: bool)
## The enemy whose bar to show, or null when there is none.
signal target_changed(target: Node3D)

## Seconds after the last blow, or the last NPC coming for the owner, that a fight ends.
@export var linger := 6.0
## How long a target that just died keeps its (empty) bar before the next one is picked.
@export var dead_target_hold := 1.6
## How often NPCs are checked for whether they are going for the owner.
@export var scan_interval := 0.25
## How long a thrown item's hit still counts as the thrower's.
@export var thrown_memory := 4.0

var _in_combat := false
var _combat_left := 0.0
var _target: Node3D
var _has_target := false
## Time left to show a dead target's empty bar, or below zero while it is alive.
var _dead_left := -1.0
var _scan_left := 0.0
## Item that just left a hand -> [who let go, when], so a thrown rock is credited to
## its thrower rather than to the rock.
var _thrown := {}

@onready var _actor: Node = get_parent()


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_tree.call_deferred(get_tree().root)


func is_in_combat() -> bool:
	return _in_combat


func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


## The first CombatTracker found going up from `node`: the player's, for a HUD
## instanced into the player scene.
static func find_for(node: Node) -> CombatTracker:
	while node:
		for child in node.get_children():
			if child is CombatTracker:
				return child
		node = node.get_parent()
	return null


## What to call `actor` over its bar: its own name if it has one (the heading its body
## is searched under), else its side, else its node name.
static func name_of(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	var inventory := actor.get_node_or_null("Inventory") as Inventory
	if inventory and not inventory.display_name.is_empty():
		return inventory.display_name
	var faction := Faction.find_in(actor)
	if faction and faction.data and not faction.data.display_name.is_empty():
		return faction.data.display_name
	return String(actor.name).capitalize()


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = scan_interval
		_scan()
	if _has_target and (not is_instance_valid(_target) or not Health.is_node_alive(_target)):
		# Counted from the moment it is found dead, so the empty bar always gets its beat.
		if _dead_left < 0.0:
			_dead_left = dead_target_hold
		_dead_left -= delta
		if _dead_left <= 0.0:
			_set_target(_nearest_attacker())
	if _in_combat:
		_combat_left -= delta
		if _combat_left <= 0.0:
			_in_combat = false
			_set_target(null)
			combat_changed.emit(false)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node is Health:
		var handler := _on_health_damaged.bind(node)
		if not (node as Health).damaged.is_connected(handler):
			(node as Health).damaged.connect(handler)
	elif node is HandSlot:
		var handler := _on_item_released.bind(node)
		if not (node as HandSlot).item_released.is_connected(handler):
			(node as HandSlot).item_released.connect(handler)


func _on_item_released(item: Node3D, hand: HandSlot) -> void:
	if hand.owner:
		_thrown[item] = [hand.owner, _now()]


func _on_health_damaged(info: DamageInfo, health: Health) -> void:
	var victim := health.get_parent() as Node3D
	var attacker := _attacker_of(info)
	if victim == null or attacker == victim:
		return
	if victim == _actor and attacker and Health.find_in(attacker):
		_engage(attacker)
	elif attacker == _actor:
		_engage(victim)


## Who is behind a hit: the attacker's body for a blow, the thrower for a thrown item.
func _attacker_of(info: DamageInfo) -> Node3D:
	var source := info.source
	if source == null or not is_instance_valid(source):
		return null
	if _thrown.has(source):
		var entry: Array = _thrown[source]
		if _now() - entry[1] <= thrown_memory and is_instance_valid(entry[0]):
			return entry[0] as Node3D
	return source as Node3D


## A blow traded with `enemy`: the fight goes on, and it is the one to watch.
func _engage(enemy: Node3D) -> void:
	_keep_fighting()
	_set_target(enemy)


func _keep_fighting() -> void:
	_combat_left = linger
	if not _in_combat:
		_in_combat = true
		combat_changed.emit(true)


## Any NPC going for the owner keeps the fight on, and gives the bar someone to show if
## it has nobody.
func _scan() -> void:
	_prune_thrown()
	var attacker := _nearest_attacker()
	if attacker == null:
		return
	_keep_fighting()
	if get_target() == null:
		_set_target(attacker)


## The nearest living NPC that is fighting the owner right now — chasing or throwing,
## not merely remembering it.
func _nearest_attacker() -> Node3D:
	var actor := _actor as Node3D
	if actor == null or not Health.is_node_alive(actor):
		return null
	var nearest: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(Faction.GROUP):
		var npc := node as Npc
		if npc == null or not npc.health.is_alive() or npc.get_attack_target() != actor:
			continue
		var action := npc.brain.get_current_action()
		if not (action is AttackTargetAction or action is ThrowAtTargetAction):
			continue
		var distance := npc.global_position.distance_to(actor.global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	return nearest


func _set_target(target: Node3D) -> void:
	if target == null and not _has_target:
		return
	if is_instance_valid(_target) and target == _target:
		return
	_target = target
	_has_target = target != null
	_dead_left = -1.0
	target_changed.emit(target)


func _prune_thrown() -> void:
	for item in _thrown.keys():
		if not is_instance_valid(item) or _now() - _thrown[item][1] > thrown_memory:
			_thrown.erase(item)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
