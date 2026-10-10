extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const WOOD_GLUE := preload("res://resources/items/wood_glue.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var player = TestWorld.masked_player(PLAYER)
	add_child(player)
	await _physics_frames(5)
	_record()
	await _unhurt(player)
	await _single_dab(player)
	await _cancelled(player)
	await _spare_dabs(player)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _record() -> void:
	_check("wood glue fits in one square", WOOD_GLUE.grid_size == Vector2i(1, 1))
	_check("wood glue is light", WOOD_GLUE.weight > 0.0 and WOOD_GLUE.weight < 1.0)
	_check("wood glue has an icon", WOOD_GLUE.icon != null)
	_check("wood glue is not a weapon", not WOOD_GLUE.is_weapon())


func _unhurt(player) -> void:
	var hand: HandSlot = player.hand_right
	var glue := _glue_into(player, hand)
	var usable := Usable.find_in(glue)
	_check("the glue is used from the hand", usable != null and usable.is_used_in_hand())
	_click(player, hand)
	await _physics_frames(30)
	_check("unhurt, a click spends nothing", usable.uses_remaining == 1)
	_check("unhurt, the glue stays in the hand", hand.get_held() == glue)
	_check("unhurt, the click is no punch", not player.arms.is_busy(ArmAnimator.Arm.RIGHT))
	_check("health is still full", player.health.get_current() == player.health.max_health)
	glue.queue_free()
	await _frames(2)


func _single_dab(player) -> void:
	var health: Health = player.health
	health.apply_damage(DamageInfo.new(50))
	var hurt := health.get_current()
	_check("the player is hurt", hurt == health.max_health - 50)
	var hand: HandSlot = player.hand_right
	var glue := _glue_into(player, hand)
	var amount: int = glue.heal_amount
	_click(player, hand)
	await _frames(2)
	_check("the click starts the timed use", player.is_using())
	await get_tree().create_timer(1.5).timeout
	_check("mid-use the view is tilted down", player.camera.rotation.x < -0.5)
	_check("mid-use nothing has healed yet", health.get_current() == hurt)
	_check("mid-use the pot is still in hand", hand.get_held() == glue)
	await get_tree().create_timer(1.0).timeout
	_check("the whole dab mends at once at the end (%d -> %d)" % [hurt, health.get_current()],
			health.get_current() == hurt + amount)
	_check("the empty pot is gone", not is_instance_valid(glue))
	_check("the hand is free again", hand.is_free())
	await get_tree().create_timer(0.5).timeout
	_check("the use is over", not player.is_using())
	_check("the view is level again", is_zero_approx(player.arms.view_tilt))


func _cancelled(player) -> void:
	var health: Health = player.health
	var hand: HandSlot = player.hand_right
	var glue := _glue_into(player, hand)
	var usable := Usable.find_in(glue)
	usable.uses_remaining = 3
	var before := health.get_current()
	_click(player, hand)
	await get_tree().create_timer(0.3).timeout
	health.apply_damage(DamageInfo.new(5))
	await _frames(2)
	_check("a hit before the dab cancels the use", not player.is_using())
	_check("cancelled before the dab, the glue is kept", usable.uses_remaining == 3)
	_check("cancelled, the view snaps level", is_zero_approx(player.arms.view_tilt))
	before = health.get_current()
	_click(player, hand)
	await get_tree().create_timer(1.3).timeout
	health.apply_damage(DamageInfo.new(5))
	await get_tree().create_timer(1.8).timeout
	_check("cancelled after the dab, the dab is spent", usable.uses_remaining == 2)
	_check("a cancelled use heals nothing", health.get_current() == before - 5)
	before = health.get_current()
	_click(player, hand)
	await get_tree().create_timer(0.8).timeout
	Input.action_press("move_forward")
	await _physics_frames(3)
	Input.action_release("move_forward")
	_check("walking off cancels the use", not player.is_using())
	_check("walked off after the first dab, it is spent", usable.uses_remaining == 1)
	await get_tree().create_timer(2.2).timeout
	_check("walked off, nothing healed", health.get_current() == before)
	glue.queue_free()
	await _frames(2)


func _spare_dabs(player) -> void:
	var health: Health = player.health
	health.apply_damage(DamageInfo.new(health.get_current() - 20))
	await _physics_frames(2)
	var hand: HandSlot = player.hand_left
	var glue := _glue_into(player, hand)
	var usable := Usable.find_in(glue)
	usable.uses_remaining = 2
	glue.heal_amount = 50
	_check("down to 20 health", health.get_current() == 20)
	_check("a click with glue is handled", player.use_held(hand))
	_check("glue in the left hand plays the mirrored use",
			player.get_node("%LeftPlayer").current_animation.begins_with(ArmAnimator.MIRRORED_LIBRARY))
	await get_tree().create_timer(3.0).timeout
	_check("one dab spent", usable.uses_remaining == 1)
	_check("a pot with a dab left stays in the hand", hand.get_held() == glue)
	_check("first dab mends to 70", health.get_current() == 70)
	player.use_held(hand)
	await get_tree().create_timer(3.0).timeout
	_check("the last dab empties the pot", not is_instance_valid(glue) and hand.is_free())
	_check("mending stops at full", health.get_current() == health.max_health)


func _glue_into(player, hand: HandSlot) -> Node3D:
	return player.interactor.spawn_into_hand(WOOD_GLUE, -1, hand)


func _click(player, hand: HandSlot) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT if hand == player.hand_left else MOUSE_BUTTON_RIGHT
	event.pressed = true
	player._use_hand(hand, event)


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
