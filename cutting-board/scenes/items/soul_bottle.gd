extends RigidBody3D

## A soul in a bottle: the spirit of a mask, caught by the Mask-Monger and handed over in
## trade for it. Inside, a smoky swirl turns round and round, and a scared face (wide eyes,
## an "O" mouth) now and then surfaces in it and is dragged off again
## (assets/shaders/soul_swirl.gdshader). The swirl drifts gently up and down.
##
## The bottle is a corked glass vial (assets/meshes/props/soul_bottle.res, built by
## scripts/import/build_soul_bottle.gd); its hollow sits round the origin, where the swirl
## floats.

## Soul colours. Amber-yellow lands on the retro palette's flame/amber and stays yellow;
## ember red has no red to land on there and comes out a burnt orange.
const AMBER := Color(1.0, 0.72, 0.16)
const EMBER := Color(0.95, 0.24, 0.08)

## The soul's colour, for the swirl and its light. Swap to EMBER for a red soul.
@export var soul_colour := AMBER
## How far the swirl drifts up and down, in metres, and how long one bob takes.
@export var bob_height := 0.006
@export var bob_period := 3.0

@onready var _wisp: Node3D = %Wisp
@onready var _swirl: MeshInstance3D = %Swirl
@onready var _glow: OmniLight3D = %Glow

var _time := 0.0


func _ready() -> void:
	_time = randf() * bob_period
	_glow.light_color = soul_colour
	# Each bottle gets its own copy of the swirl, started at its own point in time, so
	# bottles side by side don't swirl and show their faces in step.
	var material := _swirl.mesh.surface_get_material(0).duplicate() as ShaderMaterial
	material.set_shader_parameter("soul_colour", soul_colour)
	material.set_shader_parameter("seed", randf() * 100.0)
	_swirl.material_override = material


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / bob_period
	_wisp.position = Vector3(0.0, sin(phase) * bob_height, 0.0)
