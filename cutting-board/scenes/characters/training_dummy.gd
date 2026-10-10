extends StaticBody3D

@export var display_name := "Training Dummy"
@export var flash_time := 0.2
@export var reset_delay := 3.0
@export var hit_color := Color(1.0, 0.25, 0.2, 0.55)
@export var dead_color := Color(0.1, 0.1, 0.1, 0.6)

@onready var _health: Health = %Health
@onready var _visual: Node3D = %Visual

var _tint: StandardMaterial3D
var _flash_until := 0.0


func _ready() -> void:
	add_to_group(CombatTracker.NAMEPLATE_GROUP)
	add_to_group(CombatTracker.REVIVES_GROUP)
	_tint = StandardMaterial3D.new()
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _process(_delta: float) -> void:
	if _flash_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _flash_until:
		_flash_until = 0.0
		_set_overlay(null)


func _on_damaged(_info: DamageInfo) -> void:
	_flash(hit_color, flash_time)


func _on_died(_info: DamageInfo) -> void:
	_flash(dead_color, reset_delay)
	await get_tree().create_timer(reset_delay).timeout
	_health.reset()


func _flash(color: Color, duration: float) -> void:
	_tint.albedo_color = color
	_set_overlay(_tint)
	_flash_until = Time.get_ticks_msec() / 1000.0 + duration


func _set_overlay(material: Material) -> void:
	for mesh in _visual.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material
	if _visual is MeshInstance3D:
		(_visual as MeshInstance3D).material_overlay = material
