extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PLAYER.instantiate()
	add_child(player)
	await _frames(10)
	var stamina: Stamina = player.get_node("%Stamina")
	var health: Health = player.get_node("%Health")
	var breath: LowStaminaBreath = player.get_node("%LowStaminaBreath")
	stamina.regen_rate = 0.0

	_check("silent at full stamina", not breath.is_breathing())
	_set_ratio(stamina, 0.15)
	await _frames(5)
	_check("breathes below the start line", breath.is_breathing() and breath.is_audible())
	_set_ratio(stamina, 0.33)
	await _frames(5)
	_check("keeps breathing between the lines", breath.is_breathing())
	_set_ratio(stamina, 0.6)
	await _frames(5)
	_check("stops above the recovery line", not breath.is_breathing())
	await _seconds(breath.fade_time + 0.2)
	_check("and the last breath fades out", not breath.is_audible())

	_set_ratio(stamina, 0.1)
	await _frames(5)
	get_tree().paused = true
	await _frames(3)
	_check("silent while paused", not breath.is_audible())
	get_tree().paused = false
	await _frames(3)
	_check("heard again after unpausing", breath.is_audible())

	health.apply_damage(DamageInfo.new(health.max_health))
	await _frames(5)
	_check("stops on death", not breath.is_breathing() and not breath.is_audible())

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _set_ratio(stamina: Stamina, ratio: float) -> void:
	stamina.drain(stamina.get_current())
	stamina.reset()
	stamina.drain(stamina.max_stamina * (1.0 - ratio))


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout
