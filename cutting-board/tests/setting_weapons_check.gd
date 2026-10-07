extends Node3D

## Headless checks of the five setting weapons (rolling pin, chair leg, peg knuckles,
## scratcher rake, rocker sickle): each loads, is a weapon held with the weapon arm set,
## spawns its world scene, sits in a hand, hits for its own damage and wears on a landed
## blow. Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/setting_weapons_check.tscn

const WEAPONS := [
	"pegged_rolling_pin", "chair_leg_club", "clothes_peg_knuckles", "back_scratcher_rake",
	"rocker_sickle",
]

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var target := _add_target(Vector3(0, 1, -1))
	var aim := Node3D.new()
	aim.position = Vector3(0, 1, 0)
	add_child(aim)
	var melee := MeleeAttack.new()
	aim.add_child(melee)
	var hand := HandSlot.new()
	add_child(hand)
	await _physics_frames(2)

	for name in WEAPONS:
		var data := load("res://resources/items/%s.tres" % name) as ItemData
		if not _check("%s loads" % name, data != null):
			continue
		_check("%s is a weapon on the weapon arm set" % data.display_name,
			data.is_weapon() and data.animation_set == &"weapon")
		var hits := ceili(float(data.durability) / maxi(data.wear_per_hit, 1))
		_check("%s lasts 30-60 landed hits (%d)" % [data.display_name, hits], hits >= 30 and hits <= 60)
		var item := data.spawn()
		if not _check("%s spawns its world scene" % data.display_name, item is RigidBody3D):
			continue
		add_child(item)
		_check("%s weighs what its record says" % data.display_name,
			is_equal_approx((item as RigidBody3D).mass, data.weight))
		var carryable := item.get_node("Carryable") as Carryable
		carryable.take(self)
		_check("%s is held" % data.display_name, hand.hold(item) and hand.get_item_data() == data)
		await _physics_frames(1)
		melee.strike(hand)
		_check("%s wears %d on a landed blow" % [data.display_name, data.wear_per_hit],
			hand.get_durability() == data.durability - data.wear_per_hit)
		_check("%s hits for its own damage (%d)" % [data.display_name, carryable.impact_damage],
			melee._damage_for(hand) == carryable.impact_damage and carryable.impact_damage > 0)
		hand.release().queue_free()
		await _physics_frames(1)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## A wall that never breaks, for blows to land on.
func _add_target(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.5)
	shape.shape = box
	body.add_child(shape)
	var destructible := Destructible.new()
	destructible.indestructible = true
	body.add_child(destructible)
	body.position = at
	add_child(body)
	return body


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> bool:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
	return ok
