extends RigidBody3D

@export var damage := 45
@export var full_speed := 30.0
@export var impact_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export var body_hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
@export_range(0.0, 1.0) var shatter_chance := 0.5
@export var shatter_sound: SoundBank = preload("res://resources/audio/break_wood.tres")
@export var shatter_effect: PackedScene = preload("res://scenes/vfx/break_burst.tscn")

var rng := RandomNumberGenerator.new()

var flying := false
var stuck_in: Node = null
var _shooter: Node = null
var _speed := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(launch_velocity: Vector3, shooter: Node = null) -> void:
	_shooter = shooter
	flying = true
	stuck_in = null
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	if shooter is PhysicsBody3D:
		add_collision_exception_with(shooter)
	set_meta(HandSlot.RELEASED_BY_META, shooter)
	set_meta(HandSlot.RELEASED_AT_META, Time.get_ticks_msec() / 1000.0)
	freeze = false
	linear_velocity = launch_velocity
	_face(launch_velocity)


func _physics_process(_delta: float) -> void:
	if not flying:
		return
	_speed = linear_velocity.length()
	_face(linear_velocity)
	angular_velocity = Vector3.ZERO


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD
	global_basis = Basis.looking_at(direction, up)


func _on_body_entered(body: Node) -> void:
	if not flying or body == _shooter:
		return
	flying = false
	var direction := linear_velocity.normalized() if linear_velocity.length() > 0.1 else -global_basis.z
	var speed := maxf(_speed, linear_velocity.length())
	var health := Health.find_in(body)
	var position := global_position
	if health and health.is_alive():
		var info := DamageInfo.new(
			roundi(damage * clampf(speed / full_speed, 0.5, 1.0)), self, DamageInfo.Type.PIERCE
		)
		info.position = position
		info.direction = direction
		info.knockback = mass * speed
		Sfx.play_at(body_hit_sound, position)
		health.apply_damage(info)
	else:
		Sfx.play_at(impact_sound, position)
	if rng.randf() < shatter_chance:
		_shatter()
	else:
		_stick(body, direction)


func _shatter() -> void:
	Sfx.play_at(shatter_sound, global_position)
	if shatter_effect and is_inside_tree():
		var effect := shatter_effect.instantiate() as Node3D
		effect.top_level = true
		if effect is BreakBurst:
			effect.setup(self)
		else:
			effect.position = global_position
		var tree := get_tree()
		(tree.current_scene if tree.current_scene else tree.root).add_child.call_deferred(effect)
	set_deferred(&"contact_monitor", false)
	queue_free()


func _stick(body: Node, direction: Vector3) -> void:
	stuck_in = body
	set_deferred(&"contact_monitor", false)
	continuous_cd = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position += direction * 0.05
	set_deferred(&"freeze", true)
	var actor := HumanBody.actor_of(body)
	var holder := _stick_point_in(actor, body)
	if holder:
		for collider in HumanBody.colliders_of(actor):
			add_collision_exception_with(collider)
		reparent.call_deferred(holder, true)
		return
	if body is PhysicsBody3D:
		add_collision_exception_with(body)
	if body is Node3D and not body is StaticBody3D and not (body is RigidBody3D and body.freeze):
		reparent.call_deferred(body, true)


func _stick_point_in(actor: Node, part: Node) -> Node3D:
	if actor == null or not is_instance_valid(actor):
		return null
	for node in actor.find_children("*", "Node3D", true, false):
		if node.has_method(&"stick_point"):
			var holder: Node3D = node.stick_point(global_position, part)
			if holder:
				return holder
	return null
