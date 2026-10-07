extends RigidBody3D

## A railroad spike: the Churn Thumper's ammunition, and an ordinary item the rest of the
## time. Fired (launch), it flies point first under gravity, and the first thing it hits
## takes a piercing blow and keeps the spike: it stops dead and stays stuck there, in a
## fence post, the ground or a bandit, until someone pulls it out again with E or a grab,
## which is all picking it up is. Stuck in something that moves, it rides along with it.
##
## The mesh is assets/meshes/props/nail_ammo_railroad_spike.res, built by
## tools/import/build_nail_guns.gd, its point toward -Z.

## Damage of a hit at full muzzle speed; slower hits (the end of a long arc) do less, down
## to half of it.
@export var damage := 45
## The speed it counts as full speed, in metres per second.
@export var full_speed := 30.0
## The thunk of it going in.
@export var impact_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export var body_hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")

## Whether it is in the air from a shot and will stick into what it meets.
var flying := false
## What it is stuck in, if it hit something; null in flight, lying loose or in a hand.
var stuck_in: Node = null
var _shooter: Node = null
var _speed := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Sends it off from where it is at `velocity`, point first. `shooter` is never hit by
## its own shot, and gets the credit for whatever the spike does hit.
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
	# Point first all the way down the arc, rather than tumbling.
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
	_stick(body, direction)


## Stops dead a little way into `body` and stays there. Stuck in a moving thing it is
## carried along as its child; it no longer collides with that thing, so a bandit is not
## shoved about by the spike in his own side, but anything else still finds it to pull out.
func _stick(body: Node, direction: Vector3) -> void:
	stuck_in = body
	# Not switched off in the middle of the contact callback that got us here.
	set_deferred(&"contact_monitor", false)
	continuous_cd = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position += direction * 0.05
	set_deferred(&"freeze", true)
	if body is PhysicsBody3D:
		add_collision_exception_with(body)
	if body is Node3D and not body is StaticBody3D and not (body is RigidBody3D and body.freeze):
		reparent.call_deferred(body, true)
