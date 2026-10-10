extends CharacterBody3D

@export var walk_speed := 3.6
@export var sprint_speed := 5.76
@export var crouch_speed := 1.76
@export var double_tap_window := 0.3
@export var jump_velocity := 4.5

@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var crouch_transition_speed := 9.0
@export var mouse_sensitivity := 0.0025
@export var acceleration := 12.0
@export var air_acceleration := 3.0
@export_range(0.0, 1.0) var attack_slow_factor := 0.4
@export var attack_slow_time := 0.35

@export var arm_bob_frequency := 10.0
@export var arm_bob_amplitude := 0.05
@export var arm_swing_pitch := deg_to_rad(5.0)
@export var arm_swing_roll := deg_to_rad(3.0)
@export var arm_jump_lift := 0.15
@export var arm_jump_tilt := deg_to_rad(6.0)
@export var arm_action_settle_time := 0.08

@export var hit_kick := 0.012
@export var hit_kick_max := deg_to_rad(12.0)
@export var hit_kick_recovery := 8.0
@export var stagger_time := 0.3
@export_range(0.0, 1.0) var stagger_control := 0.05
@export var death_cam_distance := 2.2
@export var death_cam_height := 1.4

@export_group("Stamina")
@export var sprint_cost := 15.0
@export var sprint_recover := 20.0
@export var jump_cost := 15.0
@export var punch_cost := 6.0
@export var swing_cost := 12.0
@export var swing_cost_per_kg := 1.5
@export_group("")

@export_group("Sounds")
@export var step_sound: SoundBank = preload("res://resources/audio/step_walk.tres")
@export var run_step_sound: SoundBank = preload("res://resources/audio/step_run.tres")
@export var crouch_step_sound: SoundBank = preload("res://resources/audio/step_crouch.tres")
@export var jump_sound: SoundBank = preload("res://resources/audio/jump.tres")
@export var land_sound: SoundBank = preload("res://resources/audio/land.tres")
@export var land_speed := 3.0
@export var hurt_sound: SoundBank = preload("res://resources/audio/player_hurt.tres")
@export var death_sound: SoundBank = preload("res://resources/audio/player_death.tres")
@export var body_fall_sound: SoundBank = preload("res://resources/audio/body_fall.tres")
@export var body_fall_delay := 0.55
@export var pickup_sound: SoundBank = preload("res://resources/audio/pickup.tres")
@export var pickup_mask_sound: SoundBank = preload("res://resources/audio/pickup_mask.tres")
@export var pickup_heavy_sound: SoundBank = preload("res://resources/audio/pickup_heavy.tres")
@export var heavy_pickup_weight := 5.0
@export var hotbar_sound: SoundBank = preload("res://resources/audio/ui_hotbar.tres")
@export var wear_sound: SoundBank = preload("res://resources/audio/ui_equip.tres")
@export var mask_on_sound: SoundBank = preload("res://resources/audio/mask_on.tres")
@export var refuse_sound: SoundBank = preload("res://resources/audio/ui_invalid.tres")
@export_group("")

@export_group("Mask health")
@export var bare_health := 20
@export var bare_health_start := -1
@export_group("")

@onready var camera_pivot: Node3D = %CameraPivot
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var arm_left_pivot: Node3D = %ArmLeftPivot
@onready var arm_right_pivot: Node3D = %ArmRightPivot
@onready var arms: ArmAnimator = %Arms
@onready var melee: MeleeAttack = %MeleeAttack
@onready var interactor: Interactor = %Interactor
@onready var kick_leg: Kick = %Kick
@onready var kick_leg_view: KickLeg = %KickLeg
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var hotbar: Hotbar = %Hotbar
@onready var camera: Camera3D = %Camera3D
@onready var health: Health = %Health
@onready var stamina: Stamina = %Stamina
@onready var equipment: Equipment = %Equipment
@onready var body: HumanBody = %Body
@onready var hands: Array[HandSlot] = [hand_left, hand_right]

const PITCH_LIMIT := deg_to_rad(89.0)

var _arm_left_base_pos: Vector3
var _arm_right_base_pos: Vector3
var _arm_left_base_basis: Basis
var _arm_right_base_basis: Basis
var _arm_left_sway := 1.0
var _arm_right_sway := 1.0
var _bob_time := 0.0
var _crouching := false
var _crouch_amount := 0.0
var _eye_offset := 0.0
var _capsule: CapsuleShape3D
var _sprint_latched := false
var _last_forward_tap := -INF
var _winded := false
var _kick := Vector3.ZERO
var _attack_slow := 0.0
var _stagger := 0.0
var _dead := false
var _bare_current := 0
var _death_cam_offset := Vector3.ZERO
var _last_step := 0
var _was_on_floor := true

enum ControlMode { FULL, LOOK_ONLY, NONE }
var control := ControlMode.FULL
var _timed_use: Usable = null
var _timed_use_spent := false


func _ready() -> void:
	MouseGrab.capture()
	_arm_left_base_pos = arm_left_pivot.position
	_arm_right_base_pos = arm_right_pivot.position
	_arm_left_base_basis = arm_left_pivot.basis
	_arm_right_base_basis = arm_right_pivot.basis
	_capsule = (collision_shape.shape as CapsuleShape3D).duplicate()
	collision_shape.shape = _capsule
	_eye_offset = camera_pivot.position.y - stand_height
	_apply_height()
	interactor.item_stowed.connect(_on_item_stowed)
	hotbar.setup(inventory, hands, interactor)
	arms.hit.connect(_on_arm_hit)
	kick_leg.kick_started.connect(func(_target: Node3D) -> void: kick_leg_view.play_kick(kick_leg.windup))
	kick_leg.kicked.connect(func(_target: Node3D) -> void: _start_attack_slow())
	arms.beat.connect(_on_arm_beat)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_bare_current = bare_health if bare_health_start < 0 else mini(bare_health_start, bare_health)
	health.changed.connect(_on_health_changed)
	health.emptied.connect(_on_health_emptied)
	equipment.changed.connect(_wear_mask)
	_wear_mask()
	body.mask_broken.connect(func() -> void: equipment.unequip(Equipment.Slot.MASK))


func _unhandled_input(event: InputEvent) -> void:
	if _dead or control == ControlMode.NONE:
		return
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

	if event.is_action_released("grab_left"):
		interactor.release_hand(hand_left)
		return
	if event.is_action_released("grab_right"):
		interactor.release_hand(hand_right)
		return

	if not MouseGrab.is_captured():
		if event is InputEventMouseButton and event.pressed:
			MouseGrab.capture()
		return

	if event.is_action_pressed("crouch"):
		_crouching = not _crouching
	elif event.is_action_pressed("interact"):
		interactor.interact(inventory)
	elif event.is_action_pressed("kick"):
		kick_leg.press()
	elif event.is_action_pressed("stow_equipment"):
		hotbar.stow_hands()
	elif event.is_action_pressed("grab_left"):
		_use_hand(hand_left, event)
	elif event.is_action_pressed("grab_right"):
		_use_hand(hand_right, event)
	else:
		_use_hotbar(event)


func _use_hotbar(event: InputEvent) -> void:
	for index in hotbar.slot_count():
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			if hotbar.use(index):
				Sfx.play(hotbar_sound)
			return


func _use_hand(hand: HandSlot, event: InputEvent) -> void:
	if _is_grab_modifier(event) or (hand.is_free() and interactor.has_grabbable()):
		interactor.grab_or_charge(hand)
	elif not wear_held(hand) and not use_held(hand):
		_punch(hand)


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


func is_using() -> bool:
	return arms.is_two_armed()


func _start_timed_use(usable: Usable, hand: HandSlot) -> bool:
	if not arms.play_action(usable.use_action, ArmAnimator.Arm.BOTH, hand.get_item_data(), hand == hand_left):
		return false
	_timed_use = usable
	_timed_use_spent = false
	return true


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
			var usable := _timed_use
			_timed_use = null
			if not usable.use(self):
				usable.waste(self)


func recoil(kick: float, push: Vector3, source: Node3D = null) -> void:
	_kick.x += kick
	velocity += push
	_stagger = maxf(_stagger, stagger_time * 0.5)
	for hand in hands:
		if source and hand.get_held() == source:
			var arm := ArmAnimator.Arm.LEFT if hand == hand_left else ArmAnimator.Arm.RIGHT
			arms.play_action(&"fire", arm, hand.get_item_data())


func wear_held(hand: HandSlot) -> bool:
	var held := hand.get_item_data()
	var slot := Equipment.slot_for(held)
	if slot == Equipment.NO_SLOT:
		return false
	var durability := hand.get_durability()
	var worn_durability := equipment.get_durability(slot)
	var worn := equipment.unequip(slot)
	interactor.consume_held(hand)
	equipment.equip(slot, held, durability)
	if worn and interactor.spawn_into_hand(worn, worn_durability, hand) == null:
		if not inventory.add(worn, worn_durability):
			interactor.drop_item(worn, worn_durability)
	Sfx.play(mask_on_sound if held.item_type == ItemData.Type.MASK else wear_sound)
	return true


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


func _wears_health_mask() -> bool:
	var mask := equipment.get_item(Equipment.Slot.MASK)
	return mask != null and mask.durability > 0


func _on_health_changed(current: int, _maximum: int) -> void:
	if _dead:
		return
	if _wears_health_mask():
		equipment.set_durability(Equipment.Slot.MASK, current)
	else:
		_bare_current = current


func _on_health_emptied(_info: DamageInfo) -> void:
	if _dead or not _wears_health_mask():
		return
	body.break_mask()
	if not equipment.is_free(Equipment.Slot.MASK):
		equipment.unequip(Equipment.Slot.MASK)


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


func blow_cost(held: ItemData) -> float:
	if held == null:
		return punch_cost
	return swing_cost + held.weight * swing_cost_per_kg


func _on_arm_hit(arm: int) -> void:
	_start_attack_slow()
	melee.strike(hand_left if arm == ArmAnimator.Arm.LEFT else hand_right)


func _start_attack_slow() -> void:
	_attack_slow = attack_slow_time


func get_attack_slow_multiplier() -> float:
	if _attack_slow <= 0.0 or attack_slow_time <= 0.0:
		return 1.0
	var t := clampf(_attack_slow / (attack_slow_time * 0.5), 0.0, 1.0)
	return lerpf(1.0, attack_slow_factor, smoothstep(0.0, 1.0, t))


func _is_grab_modifier(event: InputEvent) -> bool:
	var modified := event as InputEventWithModifiers
	return modified.shift_pressed if modified else Input.is_key_pressed(KEY_SHIFT)


func _physics_process(delta: float) -> void:
	var controlling := MouseGrab.is_captured() and control == ControlMode.FULL
	if is_using():
		if controlling and _wants_to_move():
			cancel_use()
		controlling = false

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_crouch(delta)

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
	speed *= get_attack_slow_multiplier()
	_attack_slow = maxf(_attack_slow - delta, 0.0)
	var accel := acceleration if is_on_floor() else air_acceleration
	if _stagger > 0.0:
		_stagger -= delta
		accel *= stagger_control

	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

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
	camera.rotation = _kick + Vector3(arms.view_tilt, 0.0, kick_leg_view.view_roll)


func _on_item_stowed(data: ItemData) -> void:
	Sfx.play(pickup_sound_for(data))


func pickup_sound_for(data: ItemData) -> SoundBank:
	if data.item_type == ItemData.Type.MASK:
		return pickup_mask_sound
	if data.weight >= heavy_pickup_weight:
		return pickup_heavy_sound
	return pickup_sound


func _on_damaged(info: DamageInfo) -> void:
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
	if look.length_squared() < 0.0001 or absf(look.normalized().dot(Vector3.UP)) > 0.99:
		return
	var aim := Basis.looking_at(look)
	camera.global_basis = camera.global_basis.orthonormalized().slerp(aim, weight)


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


func _update_sprint_stamina(wanted: bool, delta: float) -> bool:
	if _winded and stamina.get_current() >= sprint_recover:
		_winded = false
	if not wanted or _winded:
		return false
	if not stamina.drain(sprint_cost * delta):
		_winded = true
	return true


func _update_crouch(delta: float) -> void:
	var target := 1.0 if _crouching else 0.0
	if target < _crouch_amount and not _has_headroom():
		return
	if is_equal_approx(_crouch_amount, target):
		return
	_crouch_amount = move_toward(_crouch_amount, target, crouch_transition_speed * delta)
	_apply_height()


func _has_headroom() -> bool:
	var regain := (stand_height - crouch_height) * _crouch_amount
	if regain <= 0.0:
		return true
	return not test_move(global_transform, Vector3.UP * regain)


func _apply_height() -> void:
	var height := lerpf(stand_height, crouch_height, _crouch_amount)
	_capsule.height = height
	collision_shape.position.y = height * 0.5
	camera_pivot.position.y = height + _eye_offset


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

	if is_on_floor() and horizontal_speed > 0.1:
		_bob_time += delta * arm_bob_frequency * (horizontal_speed / walk_speed)
		_update_steps(horizontal_speed)
	var stride := clampf(horizontal_speed / walk_speed, 0.0, 1.5) if is_on_floor() else 0.0
	var swing := sin(_bob_time) * stride
	var jump := clampf(velocity.y / jump_velocity, -1.0, 1.0)
	var settle := delta / arm_action_settle_time
	_arm_left_sway = move_toward(_arm_left_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.LEFT) else 1.0, settle)
	_arm_right_sway = move_toward(_arm_right_sway, 0.0 if arms.is_busy(ArmAnimator.Arm.RIGHT) else 1.0, settle)
	pose_arms(swing, jump, _arm_left_sway, _arm_right_sway)


func pose_arms(swing: float, jump: float, left_sway := 1.0, right_sway := 1.0) -> void:
	var left_swing := swing * left_sway
	var left_jump := jump * left_sway
	var right_swing := -swing * right_sway
	var right_jump := jump * right_sway
	arm_left_pivot.position = _arm_left_base_pos \
			+ Vector3(0.0, left_swing * arm_bob_amplitude + left_jump * arm_jump_lift, 0.0)
	arm_right_pivot.position = _arm_right_base_pos \
			+ Vector3(0.0, right_swing * arm_bob_amplitude + right_jump * arm_jump_lift, 0.0)
	arm_left_pivot.basis = _arm_left_base_basis * _swing_basis(left_swing, left_jump, 1.0)
	arm_right_pivot.basis = _arm_right_base_basis * _swing_basis(right_swing, right_jump, -1.0)


func _swing_basis(swing: float, jump: float, side: float) -> Basis:
	var pitch := swing * arm_swing_pitch + jump * arm_jump_tilt
	var roll := swing * arm_swing_roll * side
	return Basis.from_euler(Vector3(pitch, 0.0, roll))
