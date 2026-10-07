extends CharacterBody3D

## The walking chair as a creature in the world: it roams slowly around where it was
## placed, along the navigation mesh, pausing now and then to idle. It has no faction yet,
## so it is neutral: it never attacks and pays the player no mind, but a hit sends it
## scuttling a few steps away. Killed, it collapses and its mask drops off.
##
## Moving the body is Locomotion's job, as for the villagers; the chair model's own gait
## follows whatever distance the body covers.

## How far from where it was placed it roams, metres.
@export var roam_radius := 6.0
## Seconds it idles between strolls.
@export var pause_min := 2.0
@export var pause_max := 6.0
## How far a hit sends it scuttling, metres.
@export var flee_distance := 3.0

@onready var locomotion: Locomotion = %Locomotion
@onready var health: Health = %Health
@onready var chair: Node3D = %Chair

var _home := Vector3.ZERO
var _pause := 0.0
var _dead := false


func _ready() -> void:
	_home = global_position
	_pause = randf_range(0.5, pause_max)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _process(delta: float) -> void:
	if _dead or locomotion.is_moving():
		return
	_pause -= delta
	if _pause > 0.0:
		return
	_pause = randf_range(pause_min, pause_max)
	var angle := randf() * TAU
	var spot := _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.5, roam_radius)
	locomotion.move_to(_on_mesh(spot))


func _on_damaged(info: DamageInfo) -> void:
	if _dead or not health.is_alive():
		return
	var away := global_position - (info.position if info else global_position)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = global_basis.z
	locomotion.move_to(_on_mesh(global_position + away.normalized() * flee_distance), true)
	_pause = pause_max


func _on_died(_info: DamageInfo) -> void:
	_dead = true
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
