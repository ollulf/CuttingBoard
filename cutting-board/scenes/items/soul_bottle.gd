extends RigidBody3D

const AMBER := Color(1.0, 0.72, 0.16)
const EMBER := Color(0.95, 0.24, 0.08)

@export var soul_colour := AMBER
@export var bob_height := 0.006
@export var bob_period := 3.0

@onready var _wisp: Node3D = %Wisp
@onready var _swirl: MeshInstance3D = %Swirl
@onready var _glow: OmniLight3D = %Glow

var _time := 0.0


func _ready() -> void:
	_time = randf() * bob_period
	_glow.light_color = soul_colour
	var material := _swirl.mesh.surface_get_material(0).duplicate() as ShaderMaterial
	material.set_shader_parameter("soul_colour", soul_colour)
	material.set_shader_parameter("seed", randf() * 100.0)
	_swirl.material_override = material


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / bob_period
	_wisp.position = Vector3(0.0, sin(phase) * bob_height, 0.0)
