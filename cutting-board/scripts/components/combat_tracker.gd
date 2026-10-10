class_name CombatTracker
extends Node

signal combat_changed(in_combat: bool)
signal target_changed(target: Node3D)
signal targeted_changed(targeted: bool)
signal nearby_changed(npc: Node3D)

const NAMEPLATE_GROUP := &"nameplate"
const REVIVES_GROUP := &"revives"

@export var linger := 6.0
@export var dead_target_hold := 1.6
@export var scan_interval := 0.25
@export var thrown_memory := 4.0

@export_group("Nearby")
@export var nearby_range := 4.0
@export var nearby_angle := 35.0
@export var nearby_interval := 0.1
@export_group("")

var _in_combat := false
var _combat_left := 0.0
var _target: Node3D
var _has_target := false
var _dead_left := -1.0
var _scan_left := 0.0
var _targeted := false
var _thrown := {}
var _nearby: Node3D
var _nearby_left := 0.0

@onready var _actor: Node = get_parent()


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_tree.call_deferred(get_tree().root)


func is_in_combat() -> bool:
	return _in_combat


func is_targeted() -> bool:
	return _targeted


func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


func get_nearby() -> Node3D:
	return _nearby if is_instance_valid(_nearby) else null


static func find_for(node: Node) -> CombatTracker:
	while node:
		for child in node.get_children():
			if child is CombatTracker:
				return child
		node = node.get_parent()
	return null


static func name_of(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	var own_name = actor.get("display_name")
	if own_name is String and not own_name.is_empty():
		return own_name
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
	_nearby_left -= delta
	if _nearby_left <= 0.0:
		_nearby_left = nearby_interval
		_set_nearby(_find_nearby())
	if _has_target and (not is_instance_valid(_target) or not Health.is_node_alive(_target)) \
			and not (is_instance_valid(_target) and _target.is_in_group(REVIVES_GROUP)):
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


func _attacker_of(info: DamageInfo) -> Node3D:
	var source := info.source
	if source == null or not is_instance_valid(source):
		return null
	if _thrown.has(source):
		var entry: Array = _thrown[source]
		if _now() - entry[1] <= thrown_memory and is_instance_valid(entry[0]):
			return entry[0] as Node3D
	return info.get_attacker(thrown_memory)


func _engage(enemy: Node3D) -> void:
	_keep_fighting()
	_set_target(enemy)


func _keep_fighting() -> void:
	_combat_left = linger
	if not _in_combat:
		_in_combat = true
		combat_changed.emit(true)


func _scan() -> void:
	_prune_thrown()
	var attacker := _nearest_attacker()
	if _targeted != (attacker != null):
		_targeted = attacker != null
		targeted_changed.emit(_targeted)
	if attacker == null:
		return
	_keep_fighting()
	if get_target() == null:
		_set_target(attacker)


func _nearest_attacker() -> Node3D:
	var actor := _actor as Node3D
	if actor == null or not Health.is_node_alive(actor):
		return null
	var nearest: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(Faction.GROUP):
		var body := node as Node3D
		if body == null or not Health.is_node_alive(body):
			continue
		var npc := node as Npc
		if npc:
			if npc.get_attack_target() != actor:
				continue
			var action := npc.brain.get_current_action()
			if not (action is AttackTargetAction or action is ThrowAtTargetAction):
				continue
		elif not (body.has_method("is_going_for") and body.is_going_for(actor)):
			continue
		var distance := body.global_position.distance_to(actor.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


func _find_nearby() -> Node3D:
	var actor := _actor as Node3D
	if nearby_range <= 0.0 or actor == null or not Health.is_node_alive(actor):
		return null
	var view := _view_of(actor)
	var min_dot := cos(deg_to_rad(nearby_angle))
	var best: Node3D = null
	var best_point := Vector3.ZERO
	var best_distance := INF
	var candidates := get_tree().get_nodes_in_group(Faction.GROUP)
	candidates.append_array(get_tree().get_nodes_in_group(NAMEPLATE_GROUP))
	for node in candidates:
		var body := node as Node3D
		if body == null or not (body is Npc or body.is_in_group(NAMEPLATE_GROUP)):
			continue
		if not Health.is_node_alive(body):
			continue
		var point := _aim_point(body)
		var to_body := point - view.origin
		var distance := to_body.length()
		if distance > nearby_range or distance >= best_distance or distance < 0.01:
			continue
		if (to_body / distance).dot(-view.basis.z) < min_dot:
			continue
		best = body
		best_point = point
		best_distance = distance
	if best == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(view.origin, best_point)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != best:
		return null
	return best


func _aim_point(body: Node3D) -> Vector3:
	if body is Npc:
		return (body as Npc).eyes.global_position
	var eyes := body.get_node_or_null("%Eyes") as Node3D
	return eyes.global_position if eyes else body.global_position


func _view_of(actor: Node3D) -> Transform3D:
	var camera := actor.get_node_or_null("%Camera3D") as Camera3D
	return camera.global_transform if camera else actor.global_transform


func _set_nearby(npc: Node3D) -> void:
	if npc == get_nearby():
		return
	_nearby = npc
	nearby_changed.emit(npc)


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
