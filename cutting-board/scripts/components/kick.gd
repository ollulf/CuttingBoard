class_name Kick
extends Node

signal target_changed(target: Node3D)
signal kicked(target: Node3D)
signal kick_started(target: Node3D)

@export var reach := 1.8
@export var strike_reach := 2.2
@export var assist_radius := 0.3
@export var collision_mask := 1
@export var windup := 0.15
@export var impulse := 400.0
@export var max_speed := 16.0
@export var lift_degrees := 22.0
@export var aim_distance := 20.0
@export var damage := 15
@export var head_multiplier := 1.5
@export var cost := 22.5
@export var whiff_cost := 6.0
@export var cooldown := 0.6
@export var whiff_cooldown := 0.4
@export var npc_knockback := 80.0
@export_group("Reactions")
@export var leg_height := 0.85
@export var trip_time := 0.9
@export var trip_grip := 0.0
@export var push_time := 0.6
@export var push_grip := 0.1
@export_group("")
@export var highlight_material: Material
@export var swing_sound: SoundBank = preload("res://resources/audio/swing.tres")
@export var hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
@export var hit_object_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")

@onready var _camera: Camera3D = get_parent()
@onready var _interactor: Interactor = get_parent().get_node_or_null("Interactor")

var _target: Node3D = null
var _cooldown := 0.0
var _windup := -1.0
var _pending: Node3D = null
var _pending_full := true


func _ready() -> void:
	if highlight_material == null:
		var tint := StandardMaterial3D.new()
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.albedo_color = Color(1.0, 0.5, 0.15, 0.3)
		highlight_material = tint
	if _interactor:
		_interactor.hover_changed.connect(func(_t: Node3D) -> void: _paint(_target))


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0:
			_strike()
	if not is_instance_valid(_target):
		_target = null
	var target := pick_target()
	if target == _target:
		return
	_unpaint(_target)
	_target = target
	_paint(_target)
	target_changed.emit(_target)


func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


func is_ready() -> bool:
	return _cooldown <= 0.0 and _windup < 0.0


func press() -> void:
	if not is_ready():
		return
	var target := pick_target()
	var stamina := _stamina()
	_windup = windup
	Sfx.play(swing_sound)
	kick_started.emit(target)
	if target == null:
		if stamina:
			stamina.drain(whiff_cost)
		_cooldown = whiff_cooldown
		_pending = null
		return
	_pending_full = stamina == null or stamina.try_spend(cost)
	if not _pending_full and stamina:
		stamina.drain(cost)
	_cooldown = cooldown
	_pending = target


func pick_target() -> Node3D:
	var space := _camera.get_world_3d().direct_space_state
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * reach, collision_mask)
	query.exclude = _excluded()
	var hit := space.intersect_ray(query)
	var direct := _kickable(hit.get("collider"))
	if direct:
		return direct
	var sphere := SphereShape3D.new()
	sphere.radius = assist_radius
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.collision_mask = collision_mask
	shape_query.exclude = _excluded()
	shape_query.transform = Transform3D(Basis(), origin)
	shape_query.motion = forward * reach
	var best: Node3D = null
	var best_angle := INF
	var best_distance := INF
	var steps := 6
	var seen := {}
	for i in steps + 1:
		shape_query.transform.origin = origin + forward * reach * float(i) / steps
		for result in space.intersect_shape(shape_query, 8):
			var node := _kickable(result.get("collider"))
			if node == null or seen.has(node):
				continue
			seen[node] = true
			var to := node.global_position - origin
			var angle := forward.angle_to(to)
			var distance := to.length()
			if distance > reach + assist_radius:
				continue
			if angle < best_angle - 0.01 or (absf(angle - best_angle) <= 0.01 and distance < best_distance):
				best = node
				best_angle = angle
				best_distance = distance
	return best


func _strike() -> void:
	var target := _pending
	_pending = null
	if not is_instance_valid(target) \
			or target.global_position.distance_to(_camera.global_position) > strike_reach + 0.5:
		kicked.emit(null)
		return
	var strength := 1.0 if _pending_full else 0.5
	var point := _aim_point(target)
	var health := Health.find_in(target)
	if target is Npc:
		_kick_npc(target as Npc, strength)
	elif target is RigidBody3D:
		_kick_prop(target as RigidBody3D, point, strength)
	elif health:
		_kick_health(health, target)
	var kickable := Kickable.find_in(target)
	var destructible := target.get_node_or_null("Destructible") as Destructible
	if destructible and _pending_full and not (target is Npc) \
			and (kickable == null or kickable.kick_wears):
		destructible.damage(_damage())
	Sfx.play_at(hit_sound if health else hit_object_sound, target.global_position)
	kicked.emit(target)


func _damage() -> int:
	return damage if _pending_full else 0


func _kick_prop(body: RigidBody3D, point: Vector3, strength: float) -> void:
	var direction := point - body.global_position
	if direction.length() < 0.2:
		direction = -_camera.global_transform.basis.z
	direction = direction.normalized()
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		var pitch := maxf(asin(clampf(direction.y, -1.0, 1.0)), 0.0) + deg_to_rad(lift_degrees)
		direction = flat.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
	var kickable := Kickable.find_in(body)
	var push := impulse * strength
	if kickable:
		push *= kickable.force_multiplier
	var speed := minf(push / maxf(body.mass, 0.01), max_speed)
	body.apply_central_impulse(direction * speed * body.mass)
	var impact := body.get_node_or_null("ImpactDamage") as ImpactDamage
	if impact:
		impact.arm(owner as Node3D, 2.5, _damage())


func _kick_npc(npc: Npc, strength: float) -> void:
	var forward := -_camera.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var point := _crosshair_point_on(npc)
	var amount := _damage()
	var human := npc.body as HumanBody
	if human and human.is_head_hit(point):
		amount = roundi(amount * head_multiplier)
	var legs := point.y < npc.global_position.y + leg_height
	var info := DamageInfo.new(amount, owner)
	info.position = point
	info.direction = flat
	info.knockback = npc_knockback * strength
	npc.kicked(info, trip_time if legs else push_time, trip_grip if legs else push_grip)


func _kick_health(health: Health, target: Node3D) -> void:
	var amount := _damage()
	if amount <= 0:
		return
	var forward := -_camera.global_transform.basis.z
	var info := DamageInfo.new(amount, owner)
	info.position = _crosshair_point_on(target)
	info.direction = Vector3(forward.x, 0.0, forward.z).normalized()
	info.knockback = amount * 0.8
	health.apply_damage(info)


func _crosshair_point_on(node: Node3D) -> Vector3:
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * strike_reach, collision_mask)
	query.exclude = _excluded()
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if _kickable(hit.get("collider")) == node:
		return hit["position"]
	return node.global_position


func _aim_point(target: Node3D) -> Vector3:
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * aim_distance, collision_mask)
	var excluded := _excluded()
	if target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	query.exclude = excluded
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", origin + forward * aim_distance)


func _kickable(collider: Variant) -> Node3D:
	if not is_instance_valid(collider):
		return null
	var node := HumanBody.actor_of(collider as Node) as Node3D
	if node == null or node == owner:
		return null
	if node is Npc:
		return node if (node as Npc).health.is_alive() else null
	var health := Health.find_in(node)
	if health and not (node is RigidBody3D):
		return node if health.is_alive() else null
	if Kickable.find_in(node) == null:
		return null
	if node is RigidBody3D and (node as RigidBody3D).freeze:
		return null
	return node


func _excluded() -> Array[RID]:
	var excluded: Array[RID] = []
	var own_body := owner as CollisionObject3D
	if own_body:
		excluded.append(own_body.get_rid())
	return excluded


func _stamina() -> Stamina:
	return owner.get_node_or_null("%Stamina") as Stamina if owner else null


func _paint(node: Node3D) -> void:
	if is_instance_valid(node):
		Interactor.set_overlay(node, highlight_material)


func _unpaint(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var hovered := _interactor.get_hovered() if _interactor else null
	Interactor.set_overlay(node, _interactor.highlight_material if hovered == node else null)
