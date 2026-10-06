extends RigidBody3D

## A soul in a bottle: the spirit of a mask, caught by the Mask-Monger and handed over in
## trade for it. The little face-wisp inside bobs about and blinks now and then, and now
## and then presses its cheek to the glass.
##
## Which bottle it is (vial, flask or jar) is only the Mesh node's mesh: the concepts are
## assets/meshes/props/soul_bottle_a|b|c.res, built by scripts/import/build_soul_bottle.gd.
## Every bottle leaves its hollow round the origin, where the wisp floats.

## How far the wisp drifts up and down, in metres, and how long one bob takes.
@export var bob_height := 0.012
@export var bob_period := 2.4
## Seconds between blinks, picked anew each time from this range.
@export var blink_gap := Vector2(1.8, 4.0)
@export var blink_time := 0.14

@onready var _wisp: Node3D = %Wisp
@onready var _face: Node3D = %Face

var _time := 0.0
var _next_blink := 0.0


func _ready() -> void:
	_time = randf() * bob_period
	_next_blink = randf_range(blink_gap.x, blink_gap.y)


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / bob_period
	_wisp.position = Vector3(sin(phase * 0.5) * bob_height * 0.4, sin(phase) * bob_height, 0.0)
	# A slow sway, as if it were looking about.
	_wisp.rotation.y = sin(phase * 0.37) * 0.5
	_wisp.rotation.z = sin(phase * 0.5) * 0.12
	_next_blink -= delta
	var shut := 1.0
	if _next_blink < 0.0:
		shut = clampf(absf(_next_blink / blink_time * 2.0 + 1.0), 0.1, 1.0)
		if _next_blink < -blink_time:
			_next_blink = randf_range(blink_gap.x, blink_gap.y)
	_face.scale = Vector3(1.0, shut, 1.0)
