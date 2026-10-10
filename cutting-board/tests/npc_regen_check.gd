extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")


class Fighter extends Node3D:
	var fighting := false

	func is_in_combat() -> bool:
		return fighting


var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _regens_after_delay()
	await _not_while_fighting()
	await _hit_resets_delay()
	await _stops_at_max()
	await _never_when_dead()
	await _villager()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _regens_after_delay() -> void:
	var f := _fighter()
	var health: Health = f.get_node("Health")
	var regen: HealthRegen = f.get_node("HealthRegen")
	health.apply_damage(DamageInfo.new(50))
	await _seconds(regen.delay - 1.0)
	_check("no healing before the delay", health.get_current() == 50)
	await _seconds(3.0)
	var expected := 50 + int(regen.rate * 2.0)
	_check("heals at the set rate after the delay (%d, ~%d)" % [health.get_current(), expected],
			absi(health.get_current() - expected) <= 2)
	f.queue_free()


func _not_while_fighting() -> void:
	var f := _fighter()
	var health: Health = f.get_node("Health")
	var regen: HealthRegen = f.get_node("HealthRegen")
	health.apply_damage(DamageInfo.new(50))
	f.fighting = true
	await _seconds(regen.delay + 3.0)
	_check("no healing while fighting", health.get_current() == 50)
	f.fighting = false
	await _seconds(regen.delay - 1.0)
	_check("the delay restarts once the fight ends", health.get_current() == 50)
	await _seconds(2.0)
	_check("heals once out of combat long enough", health.get_current() > 50)
	f.queue_free()


func _hit_resets_delay() -> void:
	var f := _fighter()
	var health: Health = f.get_node("Health")
	var regen: HealthRegen = f.get_node("HealthRegen")
	health.apply_damage(DamageInfo.new(40))
	await _seconds(regen.delay + 2.0)
	_check("healing started", regen.is_regenerating())
	health.apply_damage(DamageInfo.new(10))
	var after_hit := health.get_current()
	await _seconds(regen.delay - 1.0)
	_check("a hit stops healing and restarts the delay", health.get_current() == after_hit)
	f.queue_free()


func _stops_at_max() -> void:
	var f := _fighter()
	var health: Health = f.get_node("Health")
	var regen: HealthRegen = f.get_node("HealthRegen")
	health.apply_damage(DamageInfo.new(3))
	await _seconds(regen.delay + 5.0)
	_check("stops at the maximum", health.get_current() == health.max_health)
	_check("not regenerating at the maximum", not regen.is_regenerating())
	f.queue_free()


func _never_when_dead() -> void:
	var f := _fighter()
	var health: Health = f.get_node("Health")
	var regen: HealthRegen = f.get_node("HealthRegen")
	health.apply_damage(DamageInfo.new(1000))
	await _seconds(regen.delay + 5.0)
	_check("a dead body never heals", health.get_current() == 0 and not health.is_alive())
	f.queue_free()


func _villager() -> void:
	var npc := VILLAGER.instantiate() as Npc
	add_child(npc)
	await _physics_frames(3)
	var regen := npc.get_node_or_null("HealthRegen") as HealthRegen
	_check("villager has HealthRegen", regen != null)
	_check("idle villager is not in combat", not npc.is_in_combat())
	if regen == null:
		return
	npc.health.apply_damage(DamageInfo.new(10))
	var hurt := npc.health.get_current()
	await _seconds(regen.delay + 2.0)
	_check("villager heals out of combat (%d -> %d)" % [hurt, npc.health.get_current()],
			npc.health.get_current() > hurt)
	npc.queue_free()


func _fighter() -> Fighter:
	var f := Fighter.new()
	var health := Health.new()
	health.name = "Health"
	f.add_child(health)
	var regen := HealthRegen.new()
	regen.name = "HealthRegen"
	f.add_child(regen)
	add_child(f)
	return f


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _seconds(seconds: float) -> void:
	await _physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
