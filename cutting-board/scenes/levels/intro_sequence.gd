class_name IntroSequence
extends Node
## The opening (docs/concepts/first-five-minutes.md, round 2): the player is made in the
## dark, is born, sees the bare-face grain, then falls from the sky onto the meadow
## outside the village and is handed control.
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
## Where the player touches down: on the meadow outside the village, looking at the market.
@export var landing_spot := Vector3(-4.0, 0.0, -1.0)
## Facing at the landing, radians around Y (0 looks down -Z, at the village).
@export var landing_yaw := 0.0
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

var running := false
var elapsed := 0.0
var _esc_held := 0.0
var _ground_y := 0.0
var _landed := false
var _black: ColorRect
## The player, untyped so its script's own members can be reached.
var _p: Variant


static func skip_requested() -> bool:
	return "--skip-intro" in OS.get_cmdline_user_args() or "--skip-intro" in OS.get_cmdline_args()


func _ready() -> void:
	set_process(false)
	if not enabled or skip_requested() or player == null:
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
	_p.control = CONTROL_NONE
	player.set_physics_process(false)
	_set_hud(false)
	_ground_y = _find_ground()
	_place(fall_height)
	# The total black over the grain until birth.
	var layer := CanvasLayer.new()
	layer.layer = 100
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	add_child(layer)
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
	if elapsed < BIRTH_END:
		_black.modulate.a = 1.0 if elapsed < BLACK_END else 1.0 - (elapsed - BLACK_END) / (BIRTH_END - BLACK_END)
	else:
		_black.modulate.a = 0.0
	if elapsed >= BIRTH_END:
		_p.control = CONTROL_LOOK_ONLY
	if elapsed >= GRAIN_END:
		# Ease in like a real drop, but slower: the whole fall lasts the beat.
		var t := clampf((elapsed - GRAIN_END) / (FALL_END - GRAIN_END), 0.0, 1.0)
		_place(fall_height * (1.0 - t * t))
	if elapsed >= FALL_END:
		_land()


## Holding Esc: straight to the ground, no fall.
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
	Sfx.play(_p.land_sound)
	player.set_physics_process(true)
	_p.control = CONTROL_FULL
	_set_hud(true)
	finished.emit()


func _place(height: float) -> void:
	player.global_position = Vector3(landing_spot.x, _ground_y + height, landing_spot.z)
	player.rotation = Vector3(0.0, landing_yaw, 0.0)
	_p.camera_pivot.rotation.x = 0.0 if height > 0.0 else _p.camera_pivot.rotation.x


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
