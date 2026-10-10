class_name Locomotion
extends Node

@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var acceleration := 10.0
@export var turn_speed := 8.0
@export var hold_angle := 3.0
@export var arrive_distance := 0.6
@export var repath_distance := 0.5
@export var stagger_time := 0.35
@export_range(0.0, 1.0) var stagger_control := 0.1

@onready var _body: CharacterBody3D = owner
@onready var _agent: NavigationAgent3D = %NavigationAgent3D

var _target := Vector3.ZERO
var _moving := false
var _running := false
var _facing := Vector3.ZERO
var _has_facing := false
var _stagger := 0.0
var _stagger_grip := 0.1
var _path := PackedVector3Array()
var _path_index := 0


func move_to(position: Vector3, run: bool = false) -> void:
	_running = run
	if _moving and _target.distance_to(position) < repath_distance:
		return
	_target = position
	_moving = true
	_agent.target_position = position


func stop() -> void:
	_moving = false


func walkable_point(position: Vector3) -> Vector3:
	var map := _agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_regions(map).is_empty():
		return position
	var path := NavigationServer3D.map_get_path(map, _body.global_position, position, true)
	return path[-1] if not path.is_empty() else position


func is_moving() -> bool:
	return _moving


func face(position: Vector3) -> void:
	_facing = position
	_has_facing = true


func clear_facing() -> void:
	_has_facing = false


func has_facing() -> bool:
	return _has_facing


func push(velocity: Vector3) -> void:
	if velocity.is_zero_approx():
		return
	_body.velocity += velocity
	_stagger = stagger_time
	_stagger_grip = stagger_control


func stagger_for(seconds: float, grip := stagger_control) -> void:
	_stagger = maxf(_stagger, seconds)
	_stagger_grip = grip


func get_stagger() -> float:
	return maxf(_stagger, 0.0)


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
		accel *= _stagger_grip
	_body.velocity.x = move_toward(_body.velocity.x, desired.x, accel * speed * delta)
	_body.velocity.z = move_toward(_body.velocity.z, desired.z, accel * speed * delta)
	_body.move_and_slide()

	_turn(delta)


func _next_waypoint() -> Vector3:
	_agent.get_next_path_position()
	var path := _agent.get_current_navigation_path()
	if path != _path:
		_path = path
		_path_index = 0
	if _path_walked():
		return _target
	_path_index = maxi(_path_index, _agent.get_current_navigation_path_index())
	while _path_index < _path.size() \
			and _flat_distance(_body.global_position, _path[_path_index]) < _agent.path_desired_distance:
		_path_index += 1
	if _path_walked():
		return _target
	return _path[_path_index]


func _path_walked() -> bool:
	return _path.is_empty() or _path_index >= _path.size() or _agent.is_navigation_finished()


func _blocked_short() -> bool:
	if not _path_walked() or not _body.is_on_wall():
		return false
	var ahead := _flat(_target - _body.global_position).normalized()
	return _body.get_wall_normal().dot(ahead) < -0.5


func _turn(delta: float) -> void:
	var heading := Vector3.ZERO
	if _has_facing:
		heading = _flat(_facing - _body.global_position)
	elif _stagger > 0.0:
		return
	else:
		heading = _flat(_body.velocity)
	if heading.length_squared() < 0.01:
		return
	var yaw := atan2(-heading.x, -heading.z)
	if not _moving and absf(angle_difference(_body.rotation.y, yaw)) < deg_to_rad(hold_angle):
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return _flat(a - b).length()
