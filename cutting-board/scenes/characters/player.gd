extends CharacterBody3D

## Simple first-person controller: WASD to walk, mouse to look, space to jump, C to
## toggle crouch.

@export var walk_speed := 3.6
@export var sprint_speed := 5.76
@export var crouch_speed := 1.76
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
## How far each arm pitches and rolls with a step at walking pace, in radians: the hand,
## and whatever it holds, tips up and turns out as its arm rises, and the other way as
## it comes down.
@export var arm_swing_pitch := deg_to_rad(5.0)
@export var arm_swing_roll := deg_to_rad(3.0)
## How far the arms rise/fall in response to vertical velocity (jumping/falling).
@export var arm_jump_lift := 0.15
## How far the hands tip up on the way up of a jump (and down while falling), in radians.
@export var arm_jump_tilt := deg_to_rad(6.0)
## How long an arm takes to let go of the walk sway and jump lift when it starts an
## action, and to pick them up again after, in seconds.
@export var arm_action_settle_time := 0.08

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

@export_group("Stamina")
## Drained every second the player is actually sprinting.
@export var sprint_cost := 15.0
## Once a sprint has run the pool dry, it can't start again until this much is back, so
## an empty pool doesn't flicker between running and walking.
@export var sprint_recover := 20.0
@export var jump_cost := 15.0
## A blow with an empty hand.
@export var punch_cost := 6.0
## A swing with a weapon: this much, plus swing_cost_per_kg for every kilogram the weapon
## weighs, so a hammer tires faster than a saw. A blow that can't be paid is not thrown.
@export var swing_cost := 12.0
@export var swing_cost_per_kg := 1.5
@export_group("")

@export_group("Sounds")
## Footsteps, one per arm bob: at walking pace, sprinting, and crouched.
@export var step_sound: SoundBank = preload("res://resources/audio/step_walk.tres")
@export var run_step_sound: SoundBank = preload("res://resources/audio/step_run.tres")
@export var crouch_step_sound: SoundBank = preload("res://resources/audio/step_crouch.tres")
@export var jump_sound: SoundBank = preload("res://resources/audio/jump.tres")
## Coming down from a jump or a fall. A drop slower than land_speed only makes a step.
@export var land_sound: SoundBank = preload("res://resources/audio/land.tres")
## Falling speed, in metres per second, from which touching down is a landing.
@export var land_speed := 3.0
@export var hurt_sound: SoundBank = preload("res://resources/audio/player_hurt.tres")
@export var death_sound: SoundBank = preload("res://resources/audio/player_death.tres")
## The body hitting the ground after death, this many seconds after the killing blow.
@export var body_fall_sound: SoundBank = preload("res://resources/audio/body_fall.tres")
@export var body_fall_delay := 0.55
## Something going into the inventory off the ground.
@export var pickup_sound: SoundBank = preload("res://resources/audio/pickup.tres")
## The same for a mask, light hollow wood, and for anything at least heavy_pickup_weight.
@export var pickup_mask_sound: SoundBank = preload("res://resources/audio/pickup_mask.tres")
@export var pickup_heavy_sound: SoundBank = preload("res://resources/audio/pickup_heavy.tres")
@export var heavy_pickup_weight := 5.0
## The tick of a number key that did something.
@export var hotbar_sound: SoundBank = preload("res://resources/audio/ui_hotbar.tres")
## Putting on something held in the hand — a mask taken off a body.
@export var wear_sound: SoundBank = preload("res://resources/audio/ui_equip.tres")
## Putting on a mask: wood clacking onto the wooden face.
@export var mask_on_sound: SoundBank = preload("res://resources/audio/mask_on.tres")
## A click with something used from the hand that refused — glue while unhurt.
@export var refuse_sound: SoundBank = preload("res://resources/audio/ui_invalid.tres")
@export_group("")

@export_group("Mask health")
## The worn mask's durability is the player's health: its full durability is the
## maximum, what it has left is the current, and a blow wears it. When it breaks the
## player goes on bare-faced with this much health at most, and only dies once that is
## gone too.
@export var bare_health := 20
## What the bare face has left at the start; -1 is all of bare_health. It is kept apart
## from any mask, so taking one off does not refill it.
@export var bare_health_start := -1
@export_group("")

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
@onready var kick_leg: Kick = %Kick
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var hotbar: Hotbar = %Hotbar
@onready var camera: Camera3D = %Camera3D
@onready var health: Health = %Health
@onready var stamina: Stamina = %Stamina
@onready var equipment: Equipment = %Equipment
## The player's own body is never drawn while they are alive — the view is first person
## and the arms are separate — and only falls into view on death.
@onready var body: HumanBody = %Body
@onready var hands: Array[HandSlot] = [hand_left, hand_right]

const PITCH_LIMIT := deg_to_rad(89.0)

var _arm_left_base_pos: Vector3
var _arm_right_base_pos: Vector3
var _arm_left_base_basis: Basis
var _arm_right_base_basis: Basis
## How much of the walk sway and jump lift each arm takes, 0..1: none mid-action.
var _arm_left_sway := 1.0
var _arm_right_sway := 1.0
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
## Set when a sprint emptied the stamina pool; sprinting waits until sprint_recover is back.
var _winded := false
## The view's current knock from a hit, as a rotation of the camera, easing to nothing.
var _kick := Vector3.ZERO
var _stagger := 0.0
var _dead := false
## What the bare face has left, of bare_health: health whenever no mask is on.
var _bare_current := 0
## Where the death camera sits relative to the body it watches.
var _death_cam_offset := Vector3.ZERO
## Which foot plant of the arm bob was last heard, so each one makes exactly one step.
var _last_step := 0
var _was_on_floor := true

## How much of the body the player commands: everything, only the view (mouse look), or
## nothing at all. The opening (IntroSequence) holds the player still while they are made.
enum ControlMode { FULL, LOOK_ONLY, NONE }
var control := ControlMode.FULL
## The timed use under way (a glue dab), until it lands or is cancelled; and whether it
## has got past its first dab, after which cancelling still spends it.
var _timed_use: Usable = null
var _timed_use_spent := false


func _ready() -> void:
	MouseGrab.capture()
	_arm_left_base_pos = arm_left_pivot.position
	_arm_right_base_pos = arm_right_pivot.position
	_arm_left_base_basis = arm_left_pivot.basis
	_arm_right_base_basis = arm_right_pivot.basis
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
	arms.beat.connect(_on_arm_beat)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	# The mask is the player's health: whatever health does is written back to the
	# mask's wear, and a mask that runs dry breaks rather than killing.
	_bare_current = bare_health if bare_health_start < 0 else mini(bare_health_start, bare_health)
	health.changed.connect(_on_health_changed)
	health.emptied.connect(_on_health_emptied)
	# The hidden body wears whatever mask is in the Mask slot, so the face it falls with
	# is the one the player had on. Synced once here: the starting mask went on before
	# this script was ready to hear about it.
	equipment.changed.connect(_wear_mask)
	_wear_mask()
	# A mask that splits on the body leaves the Mask slot empty.
	body.mask_broken.connect(func() -> void: equipment.unequip(Equipment.Slot.MASK))


func _unhandled_input(event: InputEvent) -> void:
	if _dead or control == ControlMode.NONE:
		return
	# A timed use holds the view and both hands; moving off is what cancels it, and that
	# is read in _physics_process.
	if is_using():
		return
	if event is InputEventMouseMotion and MouseGrab.is_captured():
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			-PITCH_LIMIT,
			PITCH_LIMIT
		)
		return
	if control != ControlMode.FULL:
		return

	# Releases are handled before the capture guard so letting go while the mouse is
	# free still finishes the throw instead of leaving the hand charging forever.
	if event.is_action_released("grab_left"):
		interactor.release_hand(hand_left)
		return
	if event.is_action_released("grab_right"):
		interactor.release_hand(hand_right)
		return
	if event.is_action_released("kick"):
		kick_leg.release()
		return

	if not MouseGrab.is_captured():
		# Click back into the window to regain mouse look.
		if event is InputEventMouseButton and event.pressed:
			MouseGrab.capture()
		return

	if event.is_action_pressed("crouch"):
		_crouching = not _crouching
	elif event.is_action_pressed("interact"):
		interactor.interact(inventory)
	elif event.is_action_pressed("kick"):
		kick_leg.start_charge()
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
			if hotbar.use(index):
				Sfx.play(hotbar_sound)
			return


## An empty hand pointed at something loose picks it up on a plain click, since that is
## the obvious reading of clicking on a barrel. Shift always works the world — grabbing
## what is under the crosshair, or winding up a throw with what is already held.
##
## A plain click with something wearable in hand puts it on, and with something used from
## the hand — glue — uses it. A click with nothing to grab is a blow. Putting the punch
## last means it costs none of the existing gestures: it happens exactly when the click
## would otherwise have done nothing at all.
func _use_hand(hand: HandSlot, event: InputEvent) -> void:
	if _is_grab_modifier(event) or (hand.is_free() and interactor.has_grabbable()):
		interactor.grab_or_charge(hand)
	elif not wear_held(hand) and not use_held(hand):
		_punch(hand)


## Uses what a hand is holding on the player, if it is something used from the hand.
## Returns false, touching nothing, when it is not; a use the item refuses still counts
## as handled, so a click with glue at full health never turns into a punch.
func use_held(hand: HandSlot) -> bool:
	var usable := Usable.find_in(hand.get_held())
	if usable == null or not usable.is_used_in_hand():
		return false
	if usable.is_timed():
		if not usable.can_be_used_by(self) or not _start_timed_use(usable, hand):
			Sfx.play(refuse_sound)
	elif not usable.use(self):
		Sfx.play(refuse_sound)
	return true


## Whether a timed use from the hand (glue) has the body: both arms, the view and the
## feet are taken until its animation is over.
func is_using() -> bool:
	return arms.is_two_armed()


## Starts a timed use: its two-armed animation plays, mirrored when the item is in the
## left hand so the hand holding it is the one that works. The use itself lands on the
## animation's "mend" beat (_on_arm_beat).
func _start_timed_use(usable: Usable, hand: HandSlot) -> bool:
	if not arms.play_action(usable.use_action, ArmAnimator.Arm.BOTH, hand.get_item_data(), hand == hand_left):
		return false
	_timed_use = usable
	_timed_use_spent = false
	return true


## Cuts a timed use short — a hit, or the player moving off. Before the first dab nothing
## is lost; after it the dab is in the crack and spent all the same.
func cancel_use() -> void:
	if _timed_use == null:
		return
	var usable := _timed_use
	_timed_use = null
	arms.cancel()
	if _timed_use_spent and is_instance_valid(usable):
		usable.waste(self)


func _on_arm_beat(beat_name: StringName) -> void:
	if _timed_use == null or not is_instance_valid(_timed_use):
		_timed_use = null
		return
	_timed_use.use_beat.emit(beat_name, self)
	match beat_name:
		&"dab":
			_timed_use_spent = true
		&"mend":
			# The use lands; the view still comes back up after it, uncancellable.
			var usable := _timed_use
			_timed_use = null
			if not usable.use(self):
				usable.waste(self)


## The kick of something fired from the hand (the Churn Thumper): the view jolts up by
## `kick` radians and settles like a hit does, the body is shoved by `push` (metres per
## second, kept through a short stagger so it carries), and the arm holding `source`
## jerks back with its "fire" animation.
func recoil(kick: float, push: Vector3, source: Node3D = null) -> void:
	_kick.x += kick
	velocity += push
	_stagger = maxf(_stagger, stagger_time * 0.5)
	for hand in hands:
		if source and hand.get_held() == source:
			var arm := ArmAnimator.Arm.LEFT if hand == hand_left else ArmAnimator.Arm.RIGHT
			arms.play_action(&"fire", arm, hand.get_item_data())


## Puts on what a hand is holding, if it is something worn — a mask picked up off a body.
## Whatever that slot had on comes off into the same hand, so a click swaps the two
## faces, and a second click swaps them back. Returns false, touching nothing, when the
## held item is not worn at all.
func wear_held(hand: HandSlot) -> bool:
	var held := hand.get_item_data()
	var slot := Equipment.slot_for(held)
	if slot == Equipment.NO_SLOT:
		return false
	# Both wears are read before either object or record goes.
	var durability := hand.get_durability()
	var worn_durability := equipment.get_durability(slot)
	var worn := equipment.unequip(slot)
	interactor.consume_held(hand)
	equipment.equip(slot, held, durability)
	# A worn item with no world scene cannot be held, so it goes into the bag instead,
	# and only drops at the player's feet when the bag is full.
	if worn and interactor.spawn_into_hand(worn, worn_durability, hand) == null:
		if not inventory.add(worn, worn_durability):
			interactor.drop_item(worn, worn_durability)
	Sfx.play(mask_on_sound if held.item_type == ItemData.Type.MASK else wear_sound)
	return true


## The hidden body keeps the face the player has on, ready for when it falls, and
## health becomes that mask's durability — or the bare face's pool with none on.
func _wear_mask() -> void:
	var mask := equipment.get_item(Equipment.Slot.MASK) as MaskData
	if body.mask != mask:
		body.mask = mask
	body.mask_durability = equipment.get_durability(Equipment.Slot.MASK)
	if _dead:
		return
	if _wears_health_mask():
		health.set_pool(equipment.get_durability(Equipment.Slot.MASK), mask.durability)
	else:
		health.set_pool(_bare_current, bare_health)


## Whether health is the worn mask's durability right now. A mask authored with no
## durability never breaks, so it is no pool of its own: the bare face's counts.
func _wears_health_mask() -> bool:
	var mask := equipment.get_item(Equipment.Slot.MASK)
	return mask != null and mask.durability > 0


## Damage and mending land on health; the mask, or the bare face, keeps the result.
func _on_health_changed(current: int, _maximum: int) -> void:
	if _dead:
		return
	if _wears_health_mask():
		equipment.set_durability(Equipment.Slot.MASK, current)
	else:
		_bare_current = current


## The worn mask ran dry: it splits off the face (the body plays the break and drops the
## Shattered Mask, and its mask_broken empties the slot), and the player stands on with
## the bare face's health. With no mask on, this is the end, and Health goes on to died.
func _on_health_emptied(_info: DamageInfo) -> void:
	if _dead or not _wears_health_mask():
		return
	body.break_mask()
	# A body with no face to break (it never got one) still loses the mask.
	if not equipment.is_free(Equipment.Slot.MASK):
		equipment.unequip(Equipment.Slot.MASK)


## Throws a blow with one arm. What the hand is holding chooses the animation, which is
## how a weapon swings rather than jabbing. A hand carrying something that is not a
## weapon is busy with it instead, since Shift-click is already how that gets thrown.
func _punch(hand: HandSlot) -> void:
	var held := hand.get_item_data()
	if not hand.is_free() and (held == null or not held.is_weapon()):
		return
	var cost := blow_cost(held)
	if not stamina.can_spend(cost):
		return
	var arm := ArmAnimator.Arm.LEFT if hand == hand_left else ArmAnimator.Arm.RIGHT
	if arms.play_action(&"punch", arm, held):
		stamina.try_spend(cost)
		melee.play_swing()


## What a blow with `held` costs in stamina: a fist the least, a weapon more the heavier
## it is.
func blow_cost(held: ItemData) -> float:
	if held == null:
		return punch_cost
	return swing_cost + held.weight * swing_cost_per_kg


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
	var controlling := MouseGrab.is_captured() and control == ControlMode.FULL
	# Rooted while a timed use runs: trying to move or jump cancels it, and the body only
	# answers from the next step on.
	if is_using():
		if controlling and _wants_to_move():
			cancel_use()
		controlling = false

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_crouch(delta)

	# Jumping out of a crouch stands up first, so the toggle never has to be pressed
	# twice to get moving again.
	if controlling and Input.is_action_just_pressed("jump"):
		if _crouching:
			_crouching = false
		elif is_on_floor() and _crouch_amount < 0.01 and stamina.try_spend(jump_cost):
			velocity.y = jump_velocity
			Sfx.play(jump_sound)

	var input_dir := Vector2.ZERO
	if controlling:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	_update_sprint_latch(controlling)
	var speed := walk_speed
	if _crouch_amount > 0.01:
		speed = lerpf(walk_speed, crouch_speed, _crouch_amount)
	elif _update_sprint_stamina(
			(_sprint_latched or Input.is_action_pressed("sprint")) and not direction.is_zero_approx(),
			delta):
		speed = sprint_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	if _stagger > 0.0:
		_stagger -= delta
		accel *= stagger_control

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	# Read before moving: touching down zeroes the fall the landing is judged by.
	var falling := -velocity.y
	move_and_slide()
	_update_landing(falling)

	_update_arms(delta)


func _wants_to_move() -> bool:
	return Input.is_action_just_pressed("jump") \
			or not Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx()


func _process(delta: float) -> void:
	if _dead:
		_follow_body(delta)
		return
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-hit_kick_recovery * delta))
	# The arms' own view tilt, for an action that looks down at the body.
	camera.rotation = _kick + Vector3(arms.view_tilt, 0.0, 0.0)


func _on_item_stowed(data: ItemData) -> void:
	Sfx.play(pickup_sound_for(data))


## Which pickup bank `data` going into the bag plays: masks and heavy things have their own.
func pickup_sound_for(data: ItemData) -> SoundBank:
	if data.item_type == ItemData.Type.MASK:
		return pickup_mask_sound
	if data.weight >= heavy_pickup_weight:
		return pickup_heavy_sound
	return pickup_sound


## A hit that does not kill snaps the view away from the force — head back from a blow
## to the face, sideways from one to the side — and knocks the player back a step. The
## body itself is not drawn while alive, so there is no flinch to show.
func _on_damaged(info: DamageInfo) -> void:
	# The mask has already taken this blow: its durability is health
	# (_on_health_changed), and one that ran dry broke in _on_health_emptied.
	# Any hit breaks off a glue use.
	cancel_use()
	if not health.is_alive():
		return
	Sfx.play(hurt_sound)
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
	Sfx.play(death_sound)
	get_tree().create_timer(body_fall_delay).timeout.connect(
		func() -> void: Sfx.play_at(body_fall_sound, body.get_center())
	)

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


## Pays for a sprint the player is asking for and returns whether it goes on. Running
## the pool dry leaves the player winded: back to a walk until sprint_recover is back.
func _update_sprint_stamina(wanted: bool, delta: float) -> bool:
	if _winded and stamina.get_current() >= sprint_recover:
		_winded = false
	if not wanted or _winded:
		return false
	if not stamina.drain(sprint_cost * delta):
		_winded = true
	return true


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


## A footstep each time the arm bob reaches the bottom of a swing, which is where a foot
## comes down, so the steps keep time with the arms at any speed. Crouched steps are the
## quietest and a sprint the loudest.
func _update_steps(horizontal_speed: float) -> void:
	var plant := floori((_bob_time - PI * 0.5) / PI)
	if plant == _last_step:
		return
	_last_step = plant
	if _crouch_amount > 0.5:
		Sfx.play(crouch_step_sound)
	elif horizontal_speed > walk_speed + 0.5:
		Sfx.play(run_step_sound)
	else:
		Sfx.play(step_sound)


## Touching down after being in the air: a real drop lands with both feet, louder the
## harder it was; stepping off a kerb just makes a step.
func _update_landing(falling: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		if falling >= land_speed:
			var hardness := clampf(falling / (land_speed * 2.5), 0.3, 1.0)
			Sfx.play(land_sound, linear_to_db(hardness))
		elif falling > 1.0:
			Sfx.play(step_sound)
	_was_on_floor = on_floor


func _update_arms(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	# Swing the arms while actually walking on the ground; settle otherwise.
	if is_on_floor() and horizontal_speed > 0.1:
		_bob_time += delta * arm_bob_frequency * (horizontal_speed / walk_speed)
		_update_steps(horizontal_speed)
	var stride := clampf(horizontal_speed / walk_speed, 0.0, 1.5) if is_on_floor() else 0.0
	# +stride at the top of the left arm's swing, -stride at the top of the right's.
	var swing := sin(_bob_time) * stride
	# Raise the arms when jumping, let them drop a bit while falling.
	var jump := clampf(velocity.y / jump_velocity, -1.0, 1.0)
	# An arm mid-action (a punch reaching across the view) lets go of the sway, or the
	# lift and turn on top of the swing would bring its cut end into view.
	var settle := delta / arm_action_settle_time
	_arm_left_sway = move_toward(_arm_left_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.LEFT) else 1.0, settle)
	_arm_right_sway = move_toward(_arm_right_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.RIGHT) else 1.0, settle)
	pose_arms(swing, jump, _arm_left_sway, _arm_right_sway)


## Places both arm pivots for a point in the walk and the jump: `swing` is +stride at
## the top of the left arm's swing and -stride at the top of the right's (stride up to
## 1.5 when running), `jump` -1..1 from falling to rising, and each arm's `sway` 0..1
## how much of both it takes. Public so checks can sweep the whole range.
func pose_arms(swing: float, jump: float, left_sway := 1.0, right_sway := 1.0) -> void:
	var left_swing := swing * left_sway
	var left_jump := jump * left_sway
	var right_swing := -swing * right_sway
	var right_jump := jump * right_sway
	arm_left_pivot.position = _arm_left_base_pos \
			+ Vector3(0.0, left_swing * arm_bob_amplitude + left_jump * arm_jump_lift, 0.0)
	arm_right_pivot.position = _arm_right_base_pos \
			+ Vector3(0.0, right_swing * arm_bob_amplitude + right_jump * arm_jump_lift, 0.0)
	# The arms turn as well as rise and fall, opposite to each other; the bones and the
	# HandSlot riding them inherit it, which is what makes a held item sway with the walk.
	arm_left_pivot.basis = _arm_left_base_basis * _swing_basis(left_swing, left_jump, 1.0)
	arm_right_pivot.basis = _arm_right_base_basis * _swing_basis(right_swing, right_jump, -1.0)


## The extra turn on one arm's pivot for its share of the swing and of the jump (both
## -1..1, the swing scaled by stride); `side` is 1 for the left arm and -1 for the right,
## which mirrors the roll so both hands turn out as they rise.
func _swing_basis(swing: float, jump: float, side: float) -> Basis:
	var pitch := swing * arm_swing_pitch + jump * arm_jump_tilt
	var roll := swing * arm_swing_roll * side
	return Basis.from_euler(Vector3(pitch, 0.0, roll))
