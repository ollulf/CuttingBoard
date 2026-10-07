class_name IntroSequence
extends Node
## The opening (docs/concepts/first-five-minutes.md, round 2): the player is made in the
## dark, is born, sees the bare-face grain, then falls from the sky into the village
## square, next to the Mask-Monger, and is handed control.
##
## Beats, in seconds from the start: 0 to 32 total black (the Builder's workshop, heard
## only), 32 to 38 the heart-knock, 38 to 44 the grain with mouse look only, 44 to 52 the
## fall. The player wears no mask, so MaskOffVision shows the grain throughout.
##
## Runs only when its level is the scene being played (tests that instance the level
## don't get it), when `enabled` is on, and when the game was not started with
## `--skip-intro` (after `--` on the command line). Holding Esc skips to the landing.

signal finished

## Off skips the opening in the editor's play button too.
@export var enabled := true
@export var player: CharacterBody3D
## Where the player touches down: in the middle of the village, a couple of metres in
## front of the Mask-Monger, who has the first mask for them.
@export var landing_spot := Vector3(1.5, 0.0, -45.85)
## Facing at the landing, radians around Y (0 looks down -Z): at the Mask-Monger.
@export var landing_yaw := -2.69
## How high above the ground the fall starts.
@export var fall_height := 40.0
## Seconds Esc must be held to skip.
@export var skip_hold := 1.0

const BLACK_END := 32.0
const BIRTH_END := 38.0
const GRAIN_END := 44.0
const FALL_END := 52.0
## Player.ControlMode values (the player script has no class_name).
const CONTROL_FULL := 0
const CONTROL_LOOK_ONLY := 1
const CONTROL_NONE := 2

const SFX := "res://assets/audio/sfx/"
const HEARTBEAT_SHADER := preload("res://scenes/levels/intro_heartbeat.gdshader")
const ROOM_LOOP := preload("res://assets/audio/ambience/intro_room_loop.wav")
## What is heard on the workbench in the dark, then the heart-knock: [seconds, sound,
## where it comes from relative to the camera (x right, y up, z behind; null for inside
## the head), dB]. The Builder works above and around the player, mostly over the chest.
const CUES := [
	[1.5, "intro_hum_1", Vector3(1.2, 1.0, -0.6), -6.0],
	[5.0, "intro_knock_1", Vector3(0.4, 0.3, -1.0), -4.0],
	[7.5, "intro_saw", Vector3(-1.8, 0.4, 0.2), -8.0],
	[10.8, "intro_mutter_1", Vector3(1.0, 1.1, -0.3), -5.0],
	[13.2, "intro_peg_1", Vector3(0.6, 0.2, -0.8), -5.0],
	[15.0, "intro_peg_2", Vector3(-0.6, 0.2, -0.8), -5.0],
	[17.2, "glue_1", Vector3(0.0, 0.3, -0.6), 0.0],
	[19.6, "intro_plane", Vector3(-1.0, 0.5, -0.5), -8.0],
	[22.6, "intro_hum_2", Vector3(-0.9, 1.0, -0.4), -6.0],
	[25.8, "intro_mutter_2", Vector3(0.3, 1.1, -0.5), -5.0],
	[28.4, "intro_peg_last", Vector3(0.0, 0.2, -0.7), -3.0],
	# 30 to 32: silence. Then two knocks on the chest, and one back from inside.
	[32.2, "intro_knock_2", Vector3(0.0, 0.0, -0.5), -2.0],
	[33.3, "intro_knock_1", Vector3(0.0, 0.0, -0.5), -2.0],
	[34.4, "intro_heart", null, 0.0],
	[35.5, "intro_heart", null, -1.0],
	[36.5, "intro_heart", null, -2.0],
	[37.4, "intro_heart", null, -4.0],
	[GRAIN_END, "intro_wind", null, -4.0],
]
## The heartbeats from inside, and how far each pushes the dark back from the centre of
## the screen (screen heights); the last one clears it.
const HEARTBEATS := [34.4, 35.5, 36.5, 37.4]
const HEART_OPEN := [0.18, 0.4, 0.7, 1.6]
## Seconds at the start of the fall over which the view turns back to face the market.
const FALL_TURN := 1.5
## The world's own sound, held silent on the workbench and faded in once born.
const WORLD_BUSES := [&"Ambience", &"Music"]

var running := false
var elapsed := 0.0
var _esc_held := 0.0
var _ground_y := 0.0
var _landed := false
var _black: ColorRect
## The "Hold Esc to skip" corner hint and its fill bar.
var hint: Control
var _hint_fill: ColorRect
var _next_cue := 0
var _room: AudioStreamPlayer
## Every sound the opening started, stopped together at the landing.
var _voices: Array[Node] = []
## The view the player looked to during the grain, which the fall turns back from.
var _look_yaw := 0.0
var _look_pitch := 0.0
## WORLD_BUSES' own levels, put back at the landing.
var _bus_levels := {}
## The player, untyped so its script's own members can be reached.
var _p: Variant


static func skip_requested() -> bool:
	return "--skip-intro" in OS.get_cmdline_user_args() or "--skip-intro" in OS.get_cmdline_args()


func _ready() -> void:
	set_process(false)
	if not enabled or player == null:
		return
	if skip_requested():
		# No opening, but the same landing spot, standing.
		await get_tree().process_frame
		if get_tree().current_scene == owner:
			place_at_landing()
		return
	# Only the level being played gets an opening, never one a test instanced.
	await get_tree().process_frame
	if get_tree().current_scene == owner:
		start()


func start() -> void:
	_p = player
	running = true
	elapsed = 0.0
	_esc_held = 0.0
	_landed = false
	_next_cue = 0
	_look_yaw = landing_yaw
	_look_pitch = 0.0
	_p.control = CONTROL_NONE
	player.set_physics_process(false)
	_set_hud(false)
	_ground_y = _find_ground()
	_place(fall_height)
	# The total black over the grain until birth, opened from the centre by the heart.
	var layer := CanvasLayer.new()
	layer.layer = 100
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HEARTBEAT_SHADER
	_black.material = material
	layer.add_child(_black)
	layer.add_child(_make_hint())
	add_child(layer)
	_room = AudioStreamPlayer.new()
	_room.stream = ROOM_LOOP
	_room.bus = &"SFX"
	_room.volume_db = -14.0
	add_child(_room)
	_room.play()
	_voices.append(_room)
	for bus in WORLD_BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0 and not _bus_levels.has(index):
			_bus_levels[index] = AudioServer.get_bus_volume_db(index)
	_world_sound(0.0)
	set_process(true)


func _input(event: InputEvent) -> void:
	# Esc belongs to the skip while the opening runs, never to the pause menu.
	if running and event.is_action("pause"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if Input.is_action_pressed("pause"):
		_esc_held += delta
		if _esc_held >= skip_hold:
			skip()
			return
	else:
		_esc_held = 0.0
	_hint_fill.scale.x = clampf(_esc_held / skip_hold, 0.0, 1.0)
	# Faint until Esc is touched, so it doesn't fight the black opening.
	hint.modulate.a = 1.0 if _esc_held > 0.0 else clampf(elapsed / 1.5, 0.0, 0.55)
	_play_cues()
	(_black.material as ShaderMaterial).set_shader_parameter("hole", _hole(elapsed))
	# The room tone drains away under the last peg, leaving two seconds of silence.
	_room.volume_db = -14.0 + linear_to_db(clampf((BLACK_END - 2.0 - elapsed) / 1.5, 0.001, 1.0))
	_world_sound(clampf((elapsed - BIRTH_END) / (GRAIN_END - BIRTH_END), 0.0, 1.0))
	if elapsed >= BIRTH_END and _p.control == CONTROL_NONE:
		_p.control = CONTROL_LOOK_ONLY
	if elapsed >= GRAIN_END and _p.control == CONTROL_LOOK_ONLY:
		_p.control = CONTROL_NONE
		_look_yaw = player.rotation.y
		_look_pitch = _p.camera_pivot.rotation.x
	if elapsed >= GRAIN_END:
		# Ease in like a real drop, but slower: the whole fall lasts the beat.
		var t := clampf((elapsed - GRAIN_END) / (FALL_END - GRAIN_END), 0.0, 1.0)
		_place(fall_height * (1.0 - t * t), clampf((elapsed - GRAIN_END) / FALL_TURN, 0.0, 1.0))
	if elapsed >= FALL_END:
		_land()


## Starts every cue whose time has come, placed around the camera as it is now.
func _play_cues() -> void:
	while _next_cue < CUES.size() and elapsed >= CUES[_next_cue][0]:
		var cue: Array = CUES[_next_cue]
		_next_cue += 1
		# A cue long past (the test jumping ahead) is not played late.
		if elapsed - cue[0] > 0.5:
			continue
		var stream: AudioStream = load(SFX + cue[1] + ".wav")
		var voice: Node
		if cue[2] == null:
			var flat := AudioStreamPlayer.new()
			flat.volume_db = cue[3]
			voice = flat
		else:
			var spatial := AudioStreamPlayer3D.new()
			spatial.volume_db = cue[3]
			spatial.max_db = cue[3]
			spatial.unit_size = 1.5
			spatial.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			voice = spatial
		voice.stream = stream
		voice.bus = &"SFX"
		add_child(voice)
		if voice is AudioStreamPlayer3D:
			var camera := get_viewport().get_camera_3d()
			voice.global_position = camera.global_transform * (cue[2] as Vector3) if camera else player.global_position
		voice.play()
		voice.finished.connect(_drop_voice.bind(voice))
		_voices.append(voice)


## Sets the world's buses to `level` (0..1) of their own volume.
func _world_sound(level: float) -> void:
	for index in _bus_levels:
		AudioServer.set_bus_volume_db(index, _bus_levels[index] + linear_to_db(maxf(level, 0.0001)))


func _exit_tree() -> void:
	# Leaving mid-opening (a test, a scene change) must not leave the world muted.
	_world_sound(1.0)


func _drop_voice(voice: Node) -> void:
	_voices.erase(voice)
	voice.queue_free()


## How far the dark has been pushed back from the centre at `t`: each heartbeat throws it
## out past its new edge, and it settles back a little until the next.
func _hole(t: float) -> float:
	if t >= BIRTH_END:
		return 3.0
	var r := 0.0
	for i in HEARTBEATS.size():
		var beat: float = HEARTBEATS[i]
		if t < beat:
			break
		var u := clampf((t - beat) / 0.45, 0.0, 1.0)
		r = lerpf(r, HEART_OPEN[i], 1.0 - pow(1.0 - u, 3.0)) + 0.12 * sin(PI * u)
	return r


## The corner hint: a small label over a thin bar that fills while Esc is held.
func _make_hint() -> Control:
	hint = VBoxContainer.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = -170.0
	hint.offset_top = -52.0
	hint.offset_right = -24.0
	hint.offset_bottom = -24.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate.a = 0.0
	var label := Label.new()
	label.text = "Hold Esc to skip"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	hint.add_child(label)
	var track := ColorRect.new()
	track.color = Color(0.0, 0.0, 0.0, 0.6)
	track.custom_minimum_size = Vector2(0.0, 4.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(track)
	_hint_fill = ColorRect.new()
	_hint_fill.color = Color(0.92, 0.88, 0.8)
	_hint_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_fill.scale.x = 0.0
	_hint_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_hint_fill)
	return hint


## Holding Esc: straight to the ground, no fall.
## Stands the player on the landing spot, facing the landing way, with no fall.
func place_at_landing() -> void:
	_p = player
	_ground_y = _find_ground()
	_look_yaw = landing_yaw
	_place(0.0)


func skip() -> void:
	_land()


func _land() -> void:
	if _landed:
		return
	_landed = true
	running = false
	set_process(false)
	_place(0.0)
	player.velocity = Vector3.ZERO
	if _black != null:
		_black.get_parent().queue_free()
		_black = null
		hint = null
		_hint_fill = null
	for voice in _voices:
		voice.queue_free()
	_voices.clear()
	_room = null
	_world_sound(1.0)
	Sfx.play(_p.land_sound)
	player.set_physics_process(true)
	_p.control = CONTROL_FULL
	_set_hud(true)
	finished.emit()


## Puts the player `height` above the landing spot. `turn` (0..1) turns the view from
## where the player looked during the grain back to the landing facing.
func _place(height: float, turn := 1.0) -> void:
	player.global_position = Vector3(landing_spot.x, _ground_y + height, landing_spot.z)
	var blend := smoothstep(0.0, 1.0, turn)
	player.rotation = Vector3(0.0, lerp_angle(_look_yaw, landing_yaw, blend), 0.0)
	if height > 0.0:
		_p.camera_pivot.rotation.x = lerpf(_look_pitch, 0.0, blend)


func _set_hud(on: bool) -> void:
	var hud := player.get_node_or_null("%InteractionPrompts") as CanvasLayer
	if hud != null:
		hud.visible = on


## The terrain under the landing spot, so the feet touch down on it.
func _find_ground() -> float:
	var space := player.get_world_3d().direct_space_state
	var from := Vector3(landing_spot.x, 200.0, landing_spot.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	return hit.position.y + 0.05 if hit else landing_spot.y
