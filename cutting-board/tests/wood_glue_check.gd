extends Node3D

## Headless checks for wood glue: a click with it in hand mends the hurt player over a
## moment and spends one dab, the pot is gone with its last dab, a pot with dabs to spare
## stays in the hand, and a click at full health spends nothing and throws no punch.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/wood_glue_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const WOOD_GLUE := preload("res://resources/items/wood_glue.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var player = PLAYER.instantiate()
	add_child(player)
	await _physics_frames(5)
	_record()
	await _unhurt(player)
	await _single_dab(player)
	await _spare_dabs(player)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _record() -> void:
	_check("wood glue fits in one square", WOOD_GLUE.grid_size == Vector2i(1, 1))
	_check("wood glue is light", WOOD_GLUE.weight > 0.0 and WOOD_GLUE.weight < 1.0)
	_check("wood glue has an icon", WOOD_GLUE.icon != null)
	_check("wood glue is not a weapon", not WOOD_GLUE.is_weapon())


## At full health the click is refused: nothing spent, still in hand, and no punch.
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


## Hurt, one click mends heal_amount over heal_time and the one-dab pot is gone.
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
	_check("the empty pot is gone", not is_instance_valid(glue))
	_check("the hand is free again", hand.is_free())
	_check("the heal has begun", health.get_current() > hurt)
	await get_tree().create_timer(1.0).timeout
	_check("the whole dab has mended (%d -> %d)" % [hurt, health.get_current()],
			health.get_current() == hurt + amount)


## A pot with two dabs: the first leaves it in the hand with one fewer, the second
## empties it. Healing never goes past full.
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
	await get_tree().create_timer(1.0).timeout
	_check("one dab spent", usable.uses_remaining == 1)
	_check("a pot with a dab left stays in the hand", hand.get_held() == glue)
	_check("first dab mends to 70", health.get_current() == 70)
	player.use_held(hand)
	await get_tree().create_timer(1.0).timeout
	_check("the last dab empties the pot", not is_instance_valid(glue) and hand.is_free())
	_check("mending stops at full", health.get_current() == health.max_health)


func _glue_into(player, hand: HandSlot) -> Node3D:
	return player.interactor.spawn_into_hand(WOOD_GLUE, -1, hand)


## A plain click of the hand's own button, through the same path the input takes.
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
