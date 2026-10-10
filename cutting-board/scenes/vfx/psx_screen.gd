extends CanvasLayer

@export var enabled := true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()
@export var render_height := 360:
	set(value):
		render_height = value
		if is_node_ready():
			_fit_to_window()
@export var snap_scale := 1.0
@export_range(0.0, 1.0) var affine_amount := 0.6
@export_range(0.0, 1.0) var grade_strength := 1.0:
	set(value):
		grade_strength = value
		if is_node_ready():
			_display.material.set_shader_parameter("strength", grade_strength)

@onready var _render: SubViewport = %Render
@onready var _camera: Camera3D = %RenderCamera
@onready var _display: TextureRect = %Display

var _scale := 1


func _ready() -> void:
	process_priority = 1000
	_display.texture = _render.get_texture()
	_display.material.set_shader_parameter("strength", grade_strength)
	get_tree().root.size_changed.connect(_fit_to_window)
	_fit_to_window()
	_apply_enabled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_retro_screen"):
		enabled = not enabled
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not enabled:
		return
	var source := get_tree().root.get_camera_3d()
	if source == null:
		return
	_camera.global_transform = source.global_transform
	_camera.projection = source.projection
	_camera.fov = source.fov
	_camera.size = source.size
	_camera.near = source.near
	_camera.far = source.far
	_camera.keep_aspect = source.keep_aspect
	_camera.cull_mask = source.cull_mask
	_camera.h_offset = source.h_offset
	_camera.v_offset = source.v_offset
	_camera.environment = source.environment
	_camera.attributes = source.attributes


func get_render_size() -> Vector2i:
	return _render.size


func get_display_rect() -> Rect2:
	return Rect2(_display.position, _display.size)


func _fit_to_window() -> void:
	var window := Vector2i(get_tree().root.get_visible_rect().size)
	_scale = maxi(1, roundi(float(window.y) / maxi(render_height, 1)))
	var render := Vector2i(ceili(float(window.x) / _scale), ceili(float(window.y) / _scale))
	_render.size = render
	_display.size = Vector2(render * _scale)
	_display.position = Vector2((window - render * _scale) / 2)
	_display.material.set_shader_parameter("render_size", Vector2(render))
	_apply_shader_globals()


func _apply_enabled() -> void:
	visible = enabled
	_render.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)
	_camera.current = enabled
	get_tree().root.disable_3d = enabled
	_apply_shader_globals()


func _apply_shader_globals() -> void:
	var snap := Vector2(_render.size) * snap_scale if enabled else Vector2.ZERO
	RenderingServer.global_shader_parameter_set(&"psx_snap_res", snap)
	RenderingServer.global_shader_parameter_set(&"psx_affine", affine_amount if enabled else 0.0)
