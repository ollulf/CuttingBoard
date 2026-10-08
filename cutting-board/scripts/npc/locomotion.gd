class_name Locomotion
extends Node

## Moves an NPC's body: walks it to a point along the navigation mesh, turns it to face
## where it is going or what it is dealing with, and keeps gravity on it. Actions only
## ever say where to go; how the body gets there lives here.
##
## When there is no usable path — the navigation mesh has not finished baking, or the
## target is off it — the body heads straight for the target instead of standing still,
## and stops where something solid is in the way.

@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var acceleration := 10.0
## How quickly the body turns toward its heading, higher is snappier.
@export var turn_speed := 8.0
## Standing still, a heading within this many degrees of the way the body faces is left
## alone, so small sways of what it faces do not set it twitching.
@export var hold_angle := 3.0
## How close to the target, measured flat, counts as having arrived.
@export var arrive_distance := 0.6
## A new target nearer than this to the current one keeps the current path, so chasing
## a moving actor does not ask for a fresh path every frame.
@export var repath_distance := 0.5
## Seconds a push leaves the body staggering, its footing weakened so the shove carries
## it back instead of being walked straight out of.
@export var stagger_time := 0.35
## How much grip on its own movement a staggering body keeps, 0..1 of acceleration.
@export_range(0.0, 1.0) var stagger_control := 0.1

@onready var _body: CharacterBody3D = owner
@onready var _agent: NavigationAgent3D = %NavigationAgent3D

var _target := Vector3.ZERO
var _moving := false
var _running := false
var _facing := Vector3.ZERO
var _has_facing := false
var _stagger := 0.0


## Sets off toward `position`, at a run when `run` is true.
func move_to(position: Vector3, run: bool = false) -> void:
	_running = run
	if _moving and _target.distance_to(position) < repath_distance:
		return
	_target = position
	_moving = true
	_agent.target_position = position


func stop() -> void:
	_moving = false


## Where a walk from here toward `position` really ends: the end of the path to it, which
## stops short where a wall or the edge of the navigation mesh is in the way. Without a
## path — no baked mesh yet — `position` itself.
func walkable_point(position: Vector3) -> Vector3:
	var map := _agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_regions(map).is_empty():
		return position
	var path := NavigationServer3D.map_get_path(map, _body.global_position, position, true)
	return path[-1] if not path.is_empty() else position


func is_moving() -> bool:
	return _moving


## Turns toward `position` and keeps facing it, even while moving, until clear_facing().
func face(position: Vector3) -> void:
	_facing = position
	_has_facing = true


func clear_facing() -> void:
	_has_facing = false


## Whether the body is being kept facing something, which is the sign it is dealing with
## it — an enemy, a throw's target — rather than idling.
func has_facing() -> bool:
	return _has_facing


## Shoves the body by `velocity` — a hit knocking it back — and leaves it staggering.
func push(velocity: Vector3) -> void:
	if velocity.is_zero_approx():
		return
	_body.velocity += velocity
	_stagger = stagger_time


func _physics_process(delta: float) -> void:
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta

	var desired := Vector3.ZERO
	if _moving:
		if _flat_distance(_body.global_position, _target) <= arrive_distance or _blocked_short():
			_moving = false
		else:
			var direction := _flat(_next_waypoint() - _body.global_position).normalized()
			desired = direction * (run_speed if _running else walk_speed)

	var speed := maxf(desired.length(), walk_speed)
	var accel := acceleration
	if _stagger > 0.0:
		_stagger -= delta
		accel *= stagger_control
	_body.velocity.x = move_toward(_body.velocity.x, desired.x, accel * speed * delta)
	_body.velocity.z = move_toward(_body.velocity.z, desired.z, accel * speed * delta)
	_body.move_and_slide()

	_turn(delta)


func _next_waypoint() -> Vector3:
	var next := _agent.get_next_path_position()
	# With no path, or once at its end — the target is off the mesh — the rest of the way
	# is walked straight. Steering for the path's end until right on it and only then for
	# the target would flip the body back and forth over that point every few frames.
	if _agent.get_current_navigation_path().is_empty() or _agent.is_navigation_finished():
		return _target
	return next


## Whether the body has walked the whole path and is now pressed against something on
## the straight stretch to a target off the mesh — inside a building, behind a fence.
## That is as close as it gets, so it counts as having arrived.
func _blocked_short() -> bool:
	if not _agent.is_navigation_finished() or not _body.is_on_wall():
		return false
	var ahead := _flat(_target - _body.global_position).normalized()
	return _body.get_wall_normal().dot(ahead) < -0.5


func _turn(delta: float) -> void:
	var heading := Vector3.ZERO
	if _has_facing:
		heading = _flat(_facing - _body.global_position)
	elif _stagger > 0.0:
		# Being shoved is not walking: a body knocked back does not turn to face the way
		# it is sliding.
		return
	else:
		heading = _flat(_body.velocity)
	if heading.length_squared() < 0.01:
		return
	var yaw := atan2(-heading.x, -heading.z)
	# Standing and already about facing it: what it faces swaying a few centimetres — a
	# target rocked by a blow — is not worth twitching the whole body for.
	if not _moving and absf(angle_difference(_body.rotation.y, yaw)) < deg_to_rad(hold_angle):
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return _flat(a - b).length()
