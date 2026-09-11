extends CharacterBody3D

## Simple first-person controller: WASD to walk, mouse to look, space to jump.

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
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
@onready var arm_left: MeshInstance3D = %ArmLeft
@onready var arm_right: MeshInstance3D = %ArmRight
@onready var interactor: Interactor = %Interactor
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight

const PITCH_LIMIT := deg_to_rad(89.0)

var _arm_left_base_pos: Vector3
var _arm_right_base_pos: Vector3
var _bob_time := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_arm_left_base_pos = arm_left.position
	_arm_right_base_pos = arm_right.position


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

	if event.is_action_pressed("interact"):
		interactor.interact()
	elif event.is_action_pressed("grab_left"):
		interactor.grab_or_charge(hand_left)
	elif event.is_action_pressed("grab_right"):
		interactor.grab_or_charge(hand_right)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := acceleration if is_on_floor() else air_acceleration

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	move_and_slide()

	_update_arms(delta)


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
