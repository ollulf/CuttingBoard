class_name Kick
extends Node

## The "kick" action: one kick hits exactly one thing, whatever is under the crosshair
## within leg reach — a prop with a Kickable child, an NPC — or swings at the air. Hold
## the key to charge (target taken at the press), let go to kick: a tap is the weakest
## kick, a full charge sends a barrel flying. Sits next to the Interactor under the
## camera; see docs/concepts/kick-shove.md.

## Emitted when what a press would kick changes, null when nothing is in reach; the HUD
## shows its boot mark while there is a target.
signal target_changed(target: Node3D)
## Emitted on the strike frame: the kicked node, or null for a whiff.
signal kicked(target: Node3D)

## Leg reach plus a step, in metres.
@export var reach := 1.8
## How far a target taken at the press may have moved off by the strike frame.
@export var strike_reach := 2.2
## Radius of the sphere cast that picks a target the crosshair ray just missed.
@export var assist_radius := 0.3
@export var collision_mask := 1
## Seconds from the press to the strike frame.
@export var windup := 0.15
## Push of a tap; mass decides how far it goes.
@export var impulse := 25.0
## Fastest a tap sends anything, so a cup does not leave at 25 m/s.
@export var max_speed := 9.0
@export_group("Charge")
## Seconds of holding for a full charge.
@export var charge_time := 0.7
## Push and speed cap of a fully charged kick; a charge in between is a blend.
@export var charged_impulse := 320.0
@export var charged_max_speed := 13.0
## Damage, stamina cost and NPC knockback of a full charge, as multiples of a tap's.
@export var charged_damage_scale := 2.5
@export var charged_cost_scale := 2.0
@export var charged_knockback_scale := 2.0
## Extra upward tilt of a full charge, so a hard kick lifts the prop off the ground.
@export var charged_lift_degrees := 12.0
@export_group("")
## Upward tilt of a prop's push, so a kick on flat ground travels instead of digging in.
@export var lift_degrees := 10.0
## How far down the sight line the crosshair point is looked for.
@export var aim_distance := 20.0
@export var damage := 6
@export var head_multiplier := 1.5
@export var cost := 10.0
@export var whiff_cost := 4.0
@export var cooldown := 0.6
@export var whiff_cooldown := 0.4
## Push given to an NPC, in metres per second, before its own mass is counted.
@export var npc_knockback := 40.0
@export_group("Reactions")
## A kick landing below this height above an NPC's feet is at the legs: about the hips.
@export var leg_height := 0.85
## Legs: a trip, long and with no footing. Body: a push back.
@export var trip_time := 0.9
@export var trip_grip := 0.0
@export var push_time := 0.6
@export var push_grip := 0.1
@export_group("")
## Overlay on the kick target; replaces the Interactor's tint on the same object.
@export var highlight_material: Material
@export var swing_sound: SoundBank = preload("res://resources/audio/swing.tres")
@export var hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")

@onready var _camera: Camera3D = get_parent()
@onready var _interactor: Interactor = get_parent().get_node_or_null("Interactor")

var _target: Node3D = null
## Counts down to the next press that does anything.
var _cooldown := 0.0
## Counts down from the press to the strike frame; below zero when no kick is under way.
var _windup := -1.0
var _pending: Node3D = null
var _pending_full := true
## Charge of the kick under way, 0 (tap) to 1 (full).
var _pending_charge := 0.0
## Seconds the key has been held; below zero while not charging.
var _held := -1.0
var _charge_target: Node3D = null


func _ready() -> void:
	if highlight_material == null:
		var tint := StandardMaterial3D.new()
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.albedo_color = Color(1.0, 0.5, 0.15, 0.3)
		highlight_material = tint
	if _interactor:
		# The Interactor tints what it newly hovers; the orange kick tint wins on the
		# same object, so one object never shows two overlays.
		_interactor.hover_changed.connect(func(_t: Node3D) -> void: _paint(_target))


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _held >= 0.0:
		_held += delta
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0:
			_strike()
	if not is_instance_valid(_target):
		_target = null
	# While charging the target stays the one taken at the press.
	var target := _charge_target if is_charging() and is_instance_valid(_charge_target) \
			else pick_target()
	if target == _target:
		return
	_unpaint(_target)
	_target = target
	_paint(_target)
	target_changed.emit(_target)


func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


func is_ready() -> bool:
	return _cooldown <= 0.0 and _windup < 0.0 and not is_charging()


func is_charging() -> bool:
	return _held >= 0.0


## How far the kick being held is charged, 0 to 1; 0 while not charging.
func get_charge() -> float:
	return clampf(_held / maxf(charge_time, 0.01), 0.0, 1.0) if is_charging() else 0.0


## A tap: kicks at once, at the weakest strength.
func press() -> void:
	start_charge()
	release()


## The key goes down: takes the target now and starts charging. A press at nothing
## swings the leg at once and costs a little; there is nothing to charge against.
func start_charge() -> void:
	if not is_ready():
		return
	var target := pick_target()
	if target == null:
		var stamina := _stamina()
		if stamina:
			stamina.drain(whiff_cost)
		_cooldown = whiff_cooldown
		_pending = null
		_windup = windup
		Sfx.play(swing_sound)
		return
	_charge_target = target
	_held = 0.0


## The key comes up: the kick lands on the strike frame `windup` later, as strong as the
## charge reached.
func release() -> void:
	if not is_charging():
		return
	var charge := get_charge()
	_held = -1.0
	var stamina := _stamina()
	var price := cost * lerpf(1.0, charged_cost_scale, charge)
	# An empty pool still kicks, at half strength and without hurting.
	_pending_full = stamina == null or stamina.try_spend(price)
	if not _pending_full and stamina:
		stamina.drain(price)
	_cooldown = cooldown
	_pending = _charge_target
	_pending_charge = charge
	_charge_target = null
	_windup = windup
	# A charged kick whooshes louder and deeper.
	Sfx.play(swing_sound, linear_to_db(lerpf(0.8, 1.0, charge)), lerpf(1.0, 0.8, charge))


## The one kickable thing under the crosshair within reach: the ray's direct hit wins;
## else among the sphere-cast candidates the one closest to the crosshair line, then the
## nearer one.
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
	# The cast sweeps the whole reach, so every body it touches along the way is a
	# candidate; intersect_shape at the far end alone would miss the near ones.
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
	if target is RigidBody3D:
		_kick_prop(target as RigidBody3D, point, strength)
	elif target is Npc:
		_kick_npc(target as Npc, strength)
	var destructible := target.get_node_or_null("Destructible") as Destructible
	if destructible and _pending_full and not (target is Npc):
		destructible.damage(_damage())
	Sfx.play_at(hit_sound, target.global_position, linear_to_db(lerpf(0.5, 1.0, _pending_charge)))
	kicked.emit(target)


## Damage of the kick under way: grows with its charge, none from an empty pool.
func _damage() -> int:
	return roundi(damage * lerpf(1.0, charged_damage_scale, _pending_charge)) if _pending_full else 0


func _kick_prop(body: RigidBody3D, point: Vector3, strength: float) -> void:
	var charge := _pending_charge
	var direction := point - body.global_position
	if direction.length() < 0.2:
		direction = -_camera.global_transform.basis.z
	direction = direction.normalized()
	# Tilt up by the lift, measured from the horizontal so flat kicks travel.
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		var lift := lift_degrees + charged_lift_degrees * charge
		var pitch := maxf(asin(clampf(direction.y, -1.0, 1.0)), 0.0) + deg_to_rad(lift)
		direction = flat.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
	var kickable := Kickable.find_in(body)
	var push := lerpf(impulse, charged_impulse, charge) * strength
	if kickable:
		push *= kickable.force_multiplier
	var cap := lerpf(max_speed, charged_max_speed, charge)
	var speed := minf(push / maxf(body.mass, 0.01), cap)
	body.apply_central_impulse(direction * speed * body.mass)
	var impact := body.get_node_or_null("ImpactDamage") as ImpactDamage
	if impact:
		impact.arm(owner as Node3D, lerpf(1.5, 2.5, charge), _damage())


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
	info.knockback = npc_knockback * strength * lerpf(1.0, charged_knockback_scale, _pending_charge)
	npc.kicked(info, trip_time if legs else push_time, trip_grip if legs else push_grip)


## Where the crosshair line meets `node`, or its centre when the line passes beside it.
func _crosshair_point_on(node: Node3D) -> Vector3:
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * strike_reach, collision_mask)
	query.exclude = _excluded()
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if _kickable(hit.get("collider")) == node:
		return hit["position"]
	return node.global_position


## The point under the crosshair beyond `target`, which a kicked prop heads for.
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
	# Props only when marked Kickable; a frozen body (held, shelved) stays put.
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


## Gives the object back the Interactor's tint when it is still the hovered one.
func _unpaint(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var hovered := _interactor.get_hovered() if _interactor else null
	Interactor.set_overlay(node, _interactor.highlight_material if hovered == node else null)
