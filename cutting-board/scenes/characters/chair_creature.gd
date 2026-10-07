extends CharacterBody3D

## The walking chair as a creature in the world: an enemy of the chairs' side, which is the
## side its Chair Mask gives it. Left alone it roams slowly around where it was placed,
## along the navigation mesh, pausing now and then to idle. Once it sees someone its side
## is hostile to, it crawls after them at a scuttle and, close enough, launches itself at
## them: it rocks back on its hind limbs (the tell), leaps, and slams down with both front
## arms. Out of sight for a while, it gives up and wanders back. Killed, it collapses and
## its mask drops off.
##
## Moving the body is Locomotion's job, as for the villagers; the chair model's own gait
## follows whatever distance the body covers. The leap moves the body itself, as a short
## ballistic arc through move_and_slide, so it follows the ground and stops at walls.

## Emitted on the leap's contact frame, when both front arms come down: `hit` is whether
## the target was still within reach and took the blow.
signal slammed(hit: bool)

enum State { ROAM, CHASE, WIND_UP, LEAP, RECOVER }

## Its name over the target bar.
@export var display_name := "Walking Chair"
## How far from where it was placed it roams, metres.
@export var roam_radius := 6.0
## Seconds it idles between strolls.
@export var pause_min := 2.0
@export var pause_max := 6.0
## Seconds out of sight after which it stops chasing.
@export var forget_time := 6.0

@export_group("Launch attack")
## Distance to the target, metres, within which it launches itself.
@export var leap_range := 3.6
## Seconds it crouches back before leaping: the tell.
@export var wind_up_time := 0.5
## Seconds in the air.
@export var flight_time := 0.45
## How far short of the target it aims to land, so the arms come down on them.
@export var land_short := 0.7
## Radius around the point the front arms slam into that the blow reaches, metres.
@export var slam_reach := 0.9
@export var slam_damage := 18
@export var slam_knockback := 6.0
## Seconds it sits after landing, open to a hit.
@export var recover_time := 0.7
## Seconds after recovering before it can leap again.
@export var cooldown := 2.5
@export_group("")

@onready var locomotion: Locomotion = %Locomotion
@onready var health: Health = %Health
@onready var faction: Faction = %Faction
@onready var chair: Node3D = %Chair

var _home := Vector3.ZERO
var _pause := 0.0
var _dead := false
var _state := State.ROAM
var _target: Node3D
## Seconds since the target was last seen.
var _unseen := 0.0
## Seconds into the current attack stage.
var _stage_time := 0.0
## Seconds before the next leap may start.
var _cooldown_left := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO


func _ready() -> void:
	_home = global_position
	_pause = randf_range(0.5, pause_max)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	(%Sight as Sight).spotted.connect(_on_spotted)


## Whom it is going for, or null.
func get_attack_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


## Whether it is going for `actor` right now: chasing or attacking, which keeps the
## player's fight on (CombatTracker).
func is_going_for(actor: Node) -> bool:
	return not _dead and _state != State.ROAM and get_attack_target() == actor


func is_leaping() -> bool:
	return _state == State.LEAP


func get_state() -> State:
	return _state


func get_cooldown_left() -> float:
	return _cooldown_left


func _process(delta: float) -> void:
	if _dead:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	match _state:
		State.ROAM:
			_roam(delta)
		State.CHASE:
			_chase(delta)


func _physics_process(delta: float) -> void:
	if _dead or _state < State.WIND_UP:
		return
	_stage_time += delta
	match _state:
		State.WIND_UP:
			_settle(delta)
			chair.attack_crouch = smoothstep(0.0, 1.0, _stage_time / wind_up_time)
			if _stage_time >= wind_up_time:
				_launch()
		State.LEAP:
			velocity += get_gravity() * delta
			move_and_slide()
			var t := _stage_time / flight_time
			chair.attack_crouch = maxf(0.0, 1.0 - t * 4.0)
			chair.attack_arms = minf(t * 1.6, 1.0)
			# Down again, or stopped by a wall or the target's body: the arms come down.
			if (_stage_time > 0.1 and is_on_floor()) or is_on_wall() or _stage_time > flight_time * 2.0:
				_slam()
		State.RECOVER:
			_settle(delta)
			chair.attack_arms = 2.0 - smoothstep(0.0, 1.0, _stage_time / recover_time) * 2.0
			if _stage_time >= recover_time:
				chair.attack_arms = 0.0
				chair.end_attack()
				_cooldown_left = cooldown
				locomotion.set_physics_process(true)
				_state = State.CHASE


func _roam(delta: float) -> void:
	if locomotion.is_moving():
		return
	_pause -= delta
	if _pause > 0.0:
		return
	_pause = randf_range(pause_min, pause_max)
	var angle := randf() * TAU
	var spot := _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.5, roam_radius)
	locomotion.move_to(_on_mesh(spot))


func _chase(delta: float) -> void:
	_unseen += delta
	var target := get_attack_target()
	if target == null or not Health.is_node_alive(target) or _unseen > forget_time:
		_give_up()
		return
	locomotion.face(target.global_position)
	var distance := _flat(target.global_position - global_position).length()
	if distance <= leap_range and _cooldown_left <= 0.0 and _unseen < 0.5 and _facing(target):
		_wind_up()
		return
	if distance > land_short + 0.3:
		locomotion.move_to(_on_mesh(target.global_position), true)
	else:
		locomotion.stop()


func _on_spotted(actor: Node3D) -> void:
	if _dead or not faction.is_hostile_to(actor):
		return
	var current := get_attack_target()
	if current == null or _prefers(actor, current):
		_target = actor
	if actor == _target:
		_unseen = 0.0
	if _state == State.ROAM:
		_state = State.CHASE


## Whether `actor` is a better target than `current`: of a priority faction when
## `current` is not, or else nearer.
func _prefers(actor: Node3D, current: Node3D) -> bool:
	if actor == current:
		return false
	var priorities: Array[StringName] = []
	if faction.data:
		priorities = faction.data.priority_targets
	var a := Faction.find_in(actor)
	var c := Faction.find_in(current)
	var a_first := a != null and a.data != null and a.data.id in priorities
	var c_first := c != null and c.data != null and c.data.id in priorities
	if a_first != c_first:
		return a_first
	return global_position.distance_to(actor.global_position) \
		< global_position.distance_to(current.global_position) - 1.0


func _give_up() -> void:
	_target = null
	_state = State.ROAM
	locomotion.clear_facing()
	locomotion.move_to(_on_mesh(_home))
	_pause = pause_max


## Faces the target within a few degrees, so the leap goes where it looks.
func _facing(target: Node3D) -> bool:
	var to := _flat(target.global_position - global_position)
	var forward := _flat(-global_basis.z)
	return to.length_squared() < 0.01 or rad_to_deg(forward.angle_to(to)) < 20.0


func _wind_up() -> void:
	_state = State.WIND_UP
	_stage_time = 0.0
	locomotion.stop()
	locomotion.set_physics_process(false)
	velocity = Vector3.ZERO
	chair.begin_attack()


## The arc is aimed at where the target stands the moment it leaps, not followed: a target
## that steps aside meanwhile is missed.
func _launch() -> void:
	_state = State.LEAP
	_stage_time = 0.0
	_leap_from = global_position
	var to := Vector3.ZERO
	var target := get_attack_target()
	if target:
		to = _flat(target.global_position - global_position)
	if to.length_squared() < 0.01:
		to = _flat(-global_basis.z)
	var run := clampf(to.length() - land_short, 0.5, leap_range)
	var direction := to.normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	_leap_to = global_position + direction * run
	var g := get_gravity().length()
	velocity = direction * (run / flight_time) + Vector3.UP * g * flight_time * 0.5


## The contact frame: both front arms hit the ground in front of it, and whoever is the
## target and still within reach of that spot takes the blow.
func _slam() -> void:
	_state = State.RECOVER
	_stage_time = 0.0
	velocity = Vector3.ZERO
	chair.attack_arms = 2.0
	chair.attack_crouch = 0.0
	var spot := slam_point()
	var target := get_attack_target()
	var hit := false
	if target and Health.is_node_alive(target):
		var off := target.global_position - spot
		if _flat(off).length() <= slam_reach and absf(off.y) < 1.5:
			var info := DamageInfo.new(slam_damage, self)
			info.position = target.global_position + Vector3.UP
			info.direction = _flat(-global_basis.z).normalized()
			info.knockback = slam_knockback
			Health.find_in(target).apply_damage(info)
			hit = true
	slammed.emit(hit)


## Where the front arms come down: a little ahead of the chair, on the ground.
func slam_point() -> Vector3:
	return global_position + _flat(-global_basis.z).normalized() * land_short


## Stands its ground while crouching or recovering: gravity, and it slides to a stop.
func _settle(delta: float) -> void:
	velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	move_and_slide()


## A hit sets it on whoever dealt it, if it was not after anyone. A hit never cancels a
## leap being wound up.
func _on_damaged(info: DamageInfo) -> void:
	if _dead or not health.is_alive() or info == null:
		return
	var attacker := info.get_attacker()
	if attacker and attacker != self and get_attack_target() == null \
			and Faction.find_in(attacker):
		_target = attacker
		_unseen = 0.0
		if _state == State.ROAM:
			_state = State.CHASE


func _on_died(_info: DamageInfo) -> void:
	_dead = true
	_target = null
	locomotion.stop()
	locomotion.set_physics_process(false)
	velocity = Vector3.ZERO
	%CollisionShape3D.set_deferred("disabled", true)
	chair.collapse(get_parent())


func _on_mesh(spot: Vector3) -> Vector3:
	var map := (%NavigationAgent3D as NavigationAgent3D).get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return spot
	return NavigationServer3D.map_get_closest_point(map, spot)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
