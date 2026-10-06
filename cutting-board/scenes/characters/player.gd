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

## How far a hit snaps the view away from its force, in radians per newton-second of the
## impulse the body takes, up to the cap; and how quickly the view settles back.
@export var hit_kick := 0.012
@export var hit_kick_max := deg_to_rad(12.0)
@export var hit_kick_recovery := 8.0
## Seconds a hit leaves the player staggering, and how much grip on their own movement
## they keep meanwhile, so the knockback carries rather than being walked straight out of.
@export var stagger_time := 0.3
@export_range(0.0, 1.0) var stagger_control := 0.05
## Where the camera settles after death, relative to the fallen body: this far back
## from it and this far above.
@export var death_cam_distance := 2.2
@export var death_cam_height := 1.4

@onready var camera_pivot: Node3D = %CameraPivot
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
## The bob and jump lift are written to the pivots, never to the arms themselves: the
## arms are what ArmAnimator's animations move, and driving both from here every frame
## would simply overwrite whatever a swing was doing.
@onready var arm_left_pivot: Node3D = %ArmLeftPivot
@onready var arm_right_pivot: Node3D = %ArmRightPivot
@onready var arms: ArmAnimator = %Arms
@onready var melee: MeleeAttack = %MeleeAttack
@onready var interactor: Interactor = %Interactor
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var hotbar: Hotbar = %Hotbar
@onready var pickup_sound: AudioStreamPlayer = %PickupSound
@onready var camera: Camera3D = %Camera3D
@onready var health: Health = %Health
## The player's own body is never drawn while they are alive — the view is first person
## and the arms are separate — and only falls into view on death.
@onready var body: HumanBody = %Body
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
## The view's current knock from a hit, as a rotation of the camera, easing to nothing.
var _kick := Vector3.ZERO
var _stagger := 0.0
var _dead := false
## Where the death camera sits relative to the body it watches.
var _death_cam_offset := Vector3.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_arm_left_base_pos = arm_left_pivot.position
	_arm_right_base_pos = arm_right_pivot.position
	# The capsule is shared with anything else instancing this scene unless it is made
	# unique here, which would make one player's crouch shrink all of them.
	_capsule = (collision_shape.shape as CapsuleShape3D).duplicate()
	collision_shape.shape = _capsule
	_eye_offset = camera_pivot.position.y - stand_height
	_apply_height()
	# Anything taken into the inventory gets the same confirmation click, whoever
	# triggered it, so the sound hangs off the event rather than the E key.
	interactor.item_stowed.connect(_on_item_stowed)
	# The bar needs all three of these at once — the bag its slots link into, the hands
	# they draw into, and the interactor that turns a record into a real object — and
	# the player is the only thing that can see all three.
	hotbar.setup(inventory, hands, interactor)
	# The blow lands when the animation says it does, not when the button was pressed.
	arms.hit.connect(_on_arm_hit)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
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
		hotbar.stow_hands()
	elif event.is_action_pressed("grab_left"):
		_use_hand(hand_left, event)
	elif event.is_action_pressed("grab_right"):
		_use_hand(hand_right, event)
	else:
		_use_hotbar(event)


## The number keys, 1 to 6: the first three reach with the left hand, the last three
## with the right. A key both draws and puts away, so one tap brings the hammer out and
## the next puts it back in the squares it came from.
func _use_hotbar(event: InputEvent) -> void:
	for index in hotbar.slot_count():
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			hotbar.use(index)
			return


## An empty hand pointed at something loose picks it up on a plain click, since that is
## the obvious reading of clicking on a barrel. Shift always works the world — grabbing
## what is under the crosshair, or winding up a throw with what is already held.
##
## A click with nothing to grab is a blow. Putting the punch last means it costs none of
## the existing gestures: it happens exactly when the click would otherwise have done
## nothing at all.
func _use_hand(hand: HandSlot, event: InputEvent) -> void:
	if _is_grab_modifier(event) or (hand.is_free() and interactor.has_grabbable()):
		interactor.grab_or_charge(hand)
	else:
		_punch(hand)


## Throws a blow with one arm. What the hand is holding chooses the animation, which is
## how a weapon swings rather than jabbing. A hand carrying something that is not a
## weapon is busy with it instead, since Shift-click is already how that gets thrown.
func _punch(hand: HandSlot) -> void:
	var held := hand.get_item_data()
	if not hand.is_free() and (held == null or not held.is_weapon()):
		return
	var arm := ArmAnimator.Arm.LEFT if hand == hand_left else ArmAnimator.Arm.RIGHT
	arms.play_action(&"punch", arm, held)


func _on_arm_hit(arm: int) -> void:
	melee.strike(hand_left if arm == ArmAnimator.Arm.LEFT else hand_right)


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
	if _stagger > 0.0:
		_stagger -= delta
		accel *= stagger_control

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	move_and_slide()

	_update_arms(delta)


func _process(delta: float) -> void:
	if _dead:
		_follow_body(delta)
		return
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-hit_kick_recovery * delta))
	camera.rotation = _kick


func _on_item_stowed(_data: ItemData) -> void:
	pickup_sound.play()


## A hit that does not kill snaps the view away from the force — head back from a blow
## to the face, sideways from one to the side — and knocks the player back a step. The
## body itself is not drawn while alive, so there is no flinch to show.
func _on_damaged(info: DamageInfo) -> void:
	if not health.is_alive():
		return
	var impulse := body.get_impulse(info)
	if not impulse.is_zero_approx():
		var local := global_basis.inverse() * impulse.normalized()
		var strength := minf(impulse.length() * hit_kick, hit_kick_max)
		_kick += Vector3(local.z, 0.0, -local.x) * strength
	velocity += body.get_knockback(info)
	_stagger = stagger_time


## Death drops the player where they stand: control stops, whatever was in hand falls,
## and the body that was hidden all along goes limp under the killing blow while the
## camera pulls back to watch it. There is no respawn yet; this is where it would start.
func _on_died(info: DamageInfo) -> void:
	_dead = true
	set_physics_process(false)
	interactor.set_physics_process(false)
	for hand in hands:
		interactor.drop_hand(hand)
	arms.visible = false
	collision_shape.set_deferred("disabled", true)
	body.visible = true
	body.go_limp(info, velocity)
	velocity = Vector3.ZERO

	# The camera leaves the head it was riding on and settles behind the body, on the
	# side the player was looking from.
	var back := camera.global_basis.z
	back.y = 0.0
	back = back.normalized() if not back.is_zero_approx() else global_basis.z
	_death_cam_offset = back * death_cam_distance + Vector3.UP * death_cam_height
	camera.top_level = true


func _follow_body(delta: float) -> void:
	var weight := 1.0 - exp(-2.5 * delta)
	var focus := body.get_center()
	camera.global_position = camera.global_position.lerp(focus + _death_cam_offset, weight)
	var look := focus - camera.global_position
	# Straight down the camera has no sensible up; it only passes through that on its
	# first frames, while it is still above the body.
	if look.length_squared() < 0.0001 or absf(look.normalized().dot(Vector3.UP)) > 0.99:
		return
	var aim := Basis.looking_at(look)
	camera.global_basis = camera.global_basis.orthonormalized().slerp(aim, weight)


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

	arm_left_pivot.position = _arm_left_base_pos + Vector3(0.0, bob_offset + jump_offset, 0.0)
	arm_right_pivot.position = _arm_right_base_pos + Vector3(0.0, -bob_offset + jump_offset, 0.0)
