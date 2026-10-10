class_name MaskOffVision
extends CanvasLayer

const BEACON_ROWS := 180

@export var equipment: Equipment
@export var fade_time := 0.6

@onready var _view: ColorRect = %View
@onready var _beacon: TextureRect = %Beacon
@onready var _beacon_render: SubViewport = %BeaconRender
@onready var _beacon_camera: Camera3D = %BeaconCamera

var amount := 0.0
var _target := 0.0
var grain_time := 0.0


func _ready() -> void:
	process_priority = 1000
	var beacon := _beacon.material as ShaderMaterial
	_beacon.texture = _beacon_render.get_texture()
	beacon.set_shader_parameter("beacon", _beacon.texture)
	beacon.set_shader_parameter("pixel_rows", float(BEACON_ROWS))
	if equipment != null:
		equipment.changed.connect(_on_equipment_changed)
		_on_equipment_changed()
		amount = _target
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED:
		_apply()


func _process(delta: float) -> void:
	grain_time += delta
	amount = move_toward(amount, _target, delta / maxf(fade_time, 0.001))
	_apply()


func _on_equipment_changed() -> void:
	_target = 1.0 if equipment.is_free(Equipment.Slot.MASK) else 0.0
	set_process(amount != _target or _target > 0.0)


func _apply() -> void:
	visible = amount > 0.0
	set_process(amount != _target or _target > 0.0)
	var material := _view.material as ShaderMaterial
	material.set_shader_parameter("fade", amount)
	material.set_shader_parameter("time", grain_time)
	var beacon := _beacon.material as ShaderMaterial
	beacon.set_shader_parameter("fade", amount)
	beacon.set_shader_parameter("time", grain_time)
	_follow_camera()
	if is_inside_tree():
		get_tree().call_group(MaskBeacon.GROUP, &"set_seen", amount)


func _follow_camera() -> void:
	var source := get_viewport().get_camera_3d() if is_inside_tree() else null
	var on := visible and source != null
	_beacon_render.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED)
	if not on:
		return
	var screen := get_viewport().get_visible_rect().size
	_beacon_render.size = Vector2i(maxi(1, roundi(screen.x / screen.y * BEACON_ROWS)), BEACON_ROWS)
	_beacon_camera.global_transform = source.global_transform
	_beacon_camera.projection = source.projection
	_beacon_camera.fov = source.fov
	_beacon_camera.size = source.size
	_beacon_camera.near = source.near
	_beacon_camera.far = source.far
	_beacon_camera.keep_aspect = source.keep_aspect
