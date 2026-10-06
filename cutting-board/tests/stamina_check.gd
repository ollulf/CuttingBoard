extends Node3D

## Headless checks for Stamina and the player's use of it: spending and the regen delay,
## a sprint draining it and dropping to a walk when empty (and staying there until some
## is back), and jumps and blows refused without enough. Prints PASS/FAIL per check and
## quits with the number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/stamina_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const HAMMER := preload("res://resources/items/hammer.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _spend_and_regen()
	_add_floor()
	var player := PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector3.ZERO
	await _physics_frames(30)
	await _sprint(player)
	await _jump(player)
	await _blows(player)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _spend_and_regen() -> void:
	var stamina := Stamina.new()
	add_child(stamina)
	_check("starts full", stamina.is_full())
	_check("a spend it can pay goes through", stamina.try_spend(30.0))
	_check("and takes that much", is_equal_approx(stamina.get_current(), 70.0))
	_check("a spend it can't pay is refused", not stamina.try_spend(80.0))
	_check("and takes nothing", is_equal_approx(stamina.get_current(), 70.0))
	await _seconds(stamina.regen_delay - 0.2)
	_check("no regen before the delay", is_equal_approx(stamina.get_current(), 70.0))
	await _seconds(0.2 + 0.4)
	var expected := 70.0 + stamina.regen_rate * 0.4
	_check("regen at the set rate after the delay (%.1f, ~%.1f)" % [stamina.get_current(), expected],
			absf(stamina.get_current() - expected) < 2.0)
	stamina.try_spend(10.0)
	var after := stamina.get_current()
	await _seconds(stamina.regen_delay - 0.2)
	_check("another spend restarts the delay", is_equal_approx(stamina.get_current(), after))
	await _seconds(3.0)
	_check("fills back up to the maximum", stamina.is_full())
	stamina.queue_free()


func _sprint(player: Node) -> void:
	var stamina: Stamina = player.get_node("%Stamina")
	Input.action_press("move_forward")
	await _seconds(1.0)
	_check("walking costs nothing", stamina.is_full())
	Input.action_press("sprint")
	await _seconds(1.0)
	var spent := stamina.max_stamina - stamina.get_current()
	_check("sprinting drains ~%.0f/s (%.1f)" % [player.sprint_cost, spent],
			absf(spent - player.sprint_cost) < 1.5)
	_check("and runs at sprint speed", _speed(player) > player.walk_speed + 1.0)
	stamina.drain(stamina.get_current() - 1.0)
	await _seconds(0.5)
	_check("an empty pool drops the sprint to a walk (%.2f)" % _speed(player),
			_speed(player) <= player.walk_speed + 0.05)
	await _seconds(stamina.regen_delay)
	_check("regen while walking with sprint held", stamina.get_current() > 1.0)
	_check("still walking until %.0f is back (%.1f, %.2f m/s)" % [
				player.sprint_recover, stamina.get_current(), _speed(player)],
			stamina.get_current() < player.sprint_recover and _speed(player) <= player.walk_speed + 0.05)
	await _seconds(0.8)
	_check("sprints again once %.0f is back" % player.sprint_recover,
			_speed(player) > player.walk_speed + 0.5)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _seconds(1.0)
	player.velocity = Vector3.ZERO
	stamina.reset()


func _jump(player: Node) -> void:
	var stamina: Stamina = player.get_node("%Stamina")
	stamina.try_spend(stamina.max_stamina - player.jump_cost + 1.0)
	await _press_jump()
	_check("no jump without enough stamina", player.is_on_floor() and player.velocity.y <= 0.0)
	stamina.reset()
	await _press_jump()
	_check("a jump with enough stamina", player.velocity.y > 0.0)
	_check("costs %.0f" % player.jump_cost,
			absf(stamina.max_stamina - stamina.get_current() - player.jump_cost) < 0.01)
	await _seconds(2.0)
	stamina.reset()


func _blows(player: Node) -> void:
	var stamina: Stamina = player.get_node("%Stamina")
	var hand: HandSlot = player.hand_right
	_check("a hammer swing costs more than a fist (%.1f vs %.1f)" % [
				player.blow_cost(HAMMER), player.blow_cost(null)],
			player.blow_cost(HAMMER) > player.blow_cost(null))
	stamina.try_spend(stamina.max_stamina - player.punch_cost + 1.0)
	var low := stamina.get_current()
	player._punch(hand)
	_check("no punch without enough stamina", stamina.get_current() == low
			and not player.arms.is_busy(ArmAnimator.Arm.RIGHT))
	stamina.reset()
	player._punch(hand)
	_check("a punch costs %.0f" % player.punch_cost,
			absf(stamina.max_stamina - stamina.get_current() - player.punch_cost) < 0.01)
	_check("and is thrown", player.arms.is_busy(ArmAnimator.Arm.RIGHT))


func _press_jump() -> void:
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	await _physics_frames(1)


func _speed(player: Node) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _seconds(seconds: float) -> void:
	await _physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
