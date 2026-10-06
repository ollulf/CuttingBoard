class_name Locomotion
extends Node

## Moves an NPC's body: walks it to a point along the navigation mesh, turns it to face
## where it is going or what it is dealing with, and keeps gravity on it. Actions only
## ever say where to go; how the body gets there lives here.
##
## When there is no usable path — the navigation mesh has not finished baking, or the
## target is off it — the body heads straight for the target instead of standing still.

@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var acceleration := 10.0
## How quickly the body turns toward its heading, higher is snappier.
@export var turn_speed := 8.0
## How close to the target, measured flat, counts as having arrived.
@export var arrive_distance := 0.6
## A new target nearer than this to the current one keeps the current path, so chasing
## a moving actor does not ask for a fresh path every frame.
@export var repath_distance := 0.5

@onready var _body: CharacterBody3D = owner
@onready var _agent: NavigationAgent3D = %NavigationAgent3D

var _target := Vector3.ZERO
var _moving := false
var _running := false
var _facing := Vector3.ZERO
var _has_facing := false


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


func is_moving() -> bool:
	return _moving


## Turns toward `position` and keeps facing it, even while moving, until clear_facing().
func face(position: Vector3) -> void:
	_facing = position
	_has_facing = true


func clear_facing() -> void:
	_has_facing = false


func _physics_process(delta: float) -> void:
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta

	var desired := Vector3.ZERO
	if _moving:
		if _flat_distance(_body.global_position, _target) <= arrive_distance:
			_moving = false
		else:
			var direction := _flat(_next_waypoint() - _body.global_position).normalized()
			desired = direction * (run_speed if _running else walk_speed)

	var speed := maxf(desired.length(), walk_speed)
	_body.velocity.x = move_toward(_body.velocity.x, desired.x, acceleration * speed * delta)
	_body.velocity.z = move_toward(_body.velocity.z, desired.z, acceleration * speed * delta)
	_body.move_and_slide()

	_turn(delta)


func _next_waypoint() -> Vector3:
	var next := _agent.get_next_path_position()
	if _agent.get_current_navigation_path().is_empty():
		return _target
	# An agent with no route reports its own position, which would leave the body
	# walking on the spot.
	if _flat_distance(next, _body.global_position) < 0.05:
		return _target
	return next


func _turn(delta: float) -> void:
	var heading := Vector3.ZERO
	if _has_facing:
		heading = _flat(_facing - _body.global_position)
	else:
		heading = _flat(_body.velocity)
	if heading.length_squared() < 0.01:
		return
	var yaw := atan2(-heading.x, -heading.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return _flat(a - b).length()
