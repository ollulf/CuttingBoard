extends Node3D

## Headless checks of the strike slow: a punch or kick leaves movement speed alone until
## the strike frame, drops it to attack_slow_factor right then, and it is back to full
## after attack_slow_time. Prints PASS/FAIL per check and quits with the failure count.
##
##   godot --headless --path cutting-board res://tests/attack_slow_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")

var _failures := 0
var _player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	_player = PLAYER.instantiate()
	add_child(_player)
	await TestWorld.physics_frames(self, 5)
	await _punch()
	await TestWorld.physics_frames(self, 40)
	await _kick()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _punch() -> void:
	var hit := [false]
	_player.arms.hit.connect(func(_arm: int) -> void: hit[0] = true, CONNECT_ONE_SHOT)
	_check("a punch starts", _player.arms.play_action(&"punch", ArmAnimator.Arm.RIGHT))
	var frames := 0
	var unchanged := true
	while not hit[0] and frames < 120:
		if not is_equal_approx(_player.get_attack_slow_multiplier(), 1.0):
			unchanged = false
		await get_tree().physics_frame
		frames += 1
	_check("the punch reaches its hit frame", hit[0])
	_check("no slow between the click and the hit (%d frames)" % frames, unchanged and frames > 1)
	await _check_slowed_then_recovers("punch")


func _kick() -> void:
	var struck := [false]
	_player.kick_leg.kicked.connect(func(_t: Node3D) -> void: struck[0] = true, CONNECT_ONE_SHOT)
	_player.kick_leg.press()
	var frames := 0
	var unchanged := true
	while not struck[0] and frames < 120:
		if not is_equal_approx(_player.get_attack_slow_multiplier(), 1.0):
			unchanged = false
		await get_tree().physics_frame
		frames += 1
	_check("the kick strikes", struck[0])
	_check("no slow during the kick windup (%d frames)" % frames, unchanged and frames > 1)
	await _check_slowed_then_recovers("kick")


func _check_slowed_then_recovers(what: String) -> void:
	var m: float = _player.get_attack_slow_multiplier()
	_check("%s: speed at %.2f of full right after the strike" % [what, m],
			absf(m - _player.attack_slow_factor) < 0.05)
	# A second strike refreshes the slow instead of stacking below the factor.
	_player._start_attack_slow()
	_check("%s: a second strike does not stack" % what,
			_player.get_attack_slow_multiplier() >= _player.attack_slow_factor - 0.001)
	await TestWorld.physics_frames(self, int((_player.attack_slow_time + 0.05) * Engine.physics_ticks_per_second))
	_check("%s: full speed again after the slow" % what,
			is_equal_approx(_player.get_attack_slow_multiplier(), 1.0))


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
