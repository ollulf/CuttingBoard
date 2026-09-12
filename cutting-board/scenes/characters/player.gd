extends CharacterBody3D

## Simple first-person controller: WASD to walk, mouse to look, space to jump, C to
## toggle crouch.

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var crouch_speed := 2.2
## How quickly W has to be tapped twice to break into a sprint, in seconds.
@export var double_tap_window := 0.3
@export var jump_velocity := 4.5

## Standing and crouched capsule heights, and how fast the body moves between them.
@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var crouch_transition_speed := 9.0
@export var mouse_sensitivity := 0.0025
## How quickly the character reaches target speed (higher = snappier).
@export var acceleration := 12.0
@export var air_acceleration := 3.0

## Arm sway while walking.
@export var arm_bob_frequency := 10.0
@export var arm_bob_amplitude := 0.05
## How far the arms rise/fall in response to vertical velocity (jumping/falling).
@export var arm_jump_lift := 0.15

@onready var camera_pivot: Node3D = %CameraPivot
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var arm_left: MeshInstance3D = %ArmLeft
@onready var arm_right: MeshInstance3D = %ArmRight
@onready var interactor: Interactor = %Interactor
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var pickup_sound: AudioStreamPlayer = %PickupSound
@onready var hands: Array[HandSlot] = [hand_left, hand_right]

const PITCH_LIMIT := deg_to_rad(89.0)

var _arm_left_base_pos: Vector3
var _arm_right_base_pos: Vector3
var _bob_time := 0.0
## Whether crouch is switched on; the body may still be standing if a ceiling is in
## the way, which is what _crouch_amount (0 standing, 1 fully crouched) tracks.
var _crouching := false
var _crouch_amount := 0.0
## Height of the eyes above the collision capsule's top while standing, kept so the
## camera keeps the same relation to the head at any height.
var _eye_offset := 0.0
var _capsule: CapsuleShape3D
## Sprint started by double-tapping W, which then runs until forward is let go — as
## opposed to holding Ctrl, which sprints only while it is down.
var _sprint_latched := false
var _last_forward_tap := -INF


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_arm_left_base_pos = arm_left.position
	_arm_right_base_pos = arm_right.position
	# The capsule is shared with anything else instancing this scene unless it is made
	# unique here, which would make one player's crouch shrink all of them.
	_capsule = (collision_shape.shape as CapsuleShape3D).duplicate()
	collision_shape.shape = _capsule
	_eye_offset = camera_pivot.position.y - stand_height
	_apply_height()
	# Anything taken into the inventory gets the same confirmation click, whoever
	# triggered it, so the sound hangs off the event rather than the E key.
	interactor.item_stowed.connect(_on_item_stowed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			-PITCH_LIMIT,
			PITCH_LIMIT
		)
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# Releases are handled before the capture guard so letting go while the mouse is
	# free still finishes the throw instead of leaving the hand charging forever.
	if event.is_action_released("grab_left"):
		interactor.release_hand(hand_left)
		return
	if event.is_action_released("grab_right"):
		interactor.release_hand(hand_right)
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Click back into the window to regain mouse look.
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("crouch"):
		_crouching = not _crouching
	elif event.is_action_pressed("interact"):
		interactor.interact(inventory)
	elif event.is_action_pressed("stow_equipment"):
		interactor.sheathe_equipment(hands)
	elif event.is_action_pressed("grab_left"):
		_use_hand(hand_left, event)
	elif event.is_action_pressed("grab_right"):
		_use_hand(hand_right, event)


## An empty hand pointed at something loose picks it up on a plain click, since that is
## the obvious reading of clicking on a barrel; otherwise a plain click readies that
## hand's equipped item. Shift always works the world — grabbing what is under the
## crosshair, or winding up a throw with what is already held.
func _use_hand(hand: HandSlot, event: InputEvent) -> void:
	if _is_grab_modifier(event) or (hand.is_free() and interactor.has_grabbable()):
		interactor.grab_or_charge(hand)
	else:
		interactor.draw_equipped(hand)


## Grabbing, throwing and dropping all hang off Shift, which leaves a plain left or
## right click free. The modifier is tested here rather than written into the input
## action on purpose: an action bound to Shift+click stops matching the moment Shift is
## let go, so releasing the modifier before the button would never finish the throw and
## the hand would charge forever.
func _is_grab_modifier(event: InputEvent) -> bool:
	var modified := event as InputEventWithModifiers
	return modified.shift_pressed if modified else Input.is_key_pressed(KEY_SHIFT)


func _physics_process(delta: float) -> void:
	# A free cursor means something is in front of the player — the inventory, or an
	# unfocused window — so the body stops taking movement input until look is captured.
	var controlling := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_crouch(delta)

	# Jumping out of a crouch stands up first, so the toggle never has to be pressed
	# twice to get moving again.
	if controlling and Input.is_action_just_pressed("jump"):
		if _crouching:
			_crouching = false
		elif is_on_floor() and _crouch_amount < 0.01:
			velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if controlling:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	_update_sprint_latch(controlling)
	var speed := walk_speed
	if _crouch_amount > 0.01:
		speed = lerpf(walk_speed, crouch_speed, _crouch_amount)
	elif _sprint_latched or Input.is_action_pressed("sprint"):
		speed = sprint_speed
	var accel := acceleration if is_on_floor() else air_acceleration

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	move_and_slide()

	_update_arms(delta)


func _on_item_stowed(_data: ItemData) -> void:
	pickup_sound.play()


## Tapping W twice in quick succession latches a sprint that lasts as long as forward
## is held. Letting go of W ends it, so the next stretch of walking starts at walking
## pace rather than inheriting the last sprint.
func _update_sprint_latch(controlling: bool) -> void:
	if not controlling or not Input.is_action_pressed("move_forward"):
		_sprint_latched = false
		return
	if not Input.is_action_just_pressed("move_forward"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_forward_tap <= double_tap_window:
		_sprint_latched = true
	_last_forward_tap = now


## Moves the body toward its target height. Standing up is refused while something is
## directly overhead, so releasing the crouch under a low ceiling simply waits until
## the player walks out from under it instead of pushing them through the geometry.
func _update_crouch(delta: float) -> void:
	var target := 1.0 if _crouching else 0.0
	if target < _crouch_amount and not _has_headroom():
		return
	if is_equal_approx(_crouch_amount, target):
		return
	_crouch_amount = move_toward(_crouch_amount, target, crouch_transition_speed * delta)
	_apply_height()


## Whether the body could grow back to full height where it stands: test_move sweeps
## the current capsule up by the height it is about to regain, which collides exactly
## when the taller capsule would not fit.
func _has_headroom() -> bool:
	var regain := (stand_height - crouch_height) * _crouch_amount
	if regain <= 0.0:
		return true
	return not test_move(global_transform, Vector3.UP * regain)


func _apply_height() -> void:
	var height := lerpf(stand_height, crouch_height, _crouch_amount)
	_capsule.height = height
	# The capsule is centred on the body, whose origin sits at the feet.
	collision_shape.position.y = height * 0.5
	camera_pivot.position.y = height + _eye_offset


func _update_arms(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	# Swing the arms while actually walking on the ground; settle otherwise.
	if is_on_floor() and horizontal_speed > 0.1:
		_bob_time += delta * arm_bob_frequency * (horizontal_speed / walk_speed)
	var bob_amount := arm_bob_amplitude * clampf(horizontal_speed / walk_speed, 0.0, 1.5) if is_on_floor() else 0.0
	var bob_offset := sin(_bob_time) * bob_amount

	# Raise the arms when jumping, let them drop a bit while falling.
	var jump_offset := clampf(velocity.y / jump_velocity, -1.0, 1.0) * arm_jump_lift

	arm_left.position = _arm_left_base_pos + Vector3(0.0, bob_offset + jump_offset, 0.0)
	arm_right.position = _arm_right_base_pos + Vector3(0.0, -bob_offset + jump_offset, 0.0)
