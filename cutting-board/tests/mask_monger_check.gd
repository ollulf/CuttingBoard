extends Node3D

## Headless checks for the Mask-Monger NPC (scenes/characters/mask_monger.tscn): he
## spawns with his own MaskMongerBody, is on the villagers' side and friendly to them
## and to the player, walks a navigation path with his four-beat gait advancing as he
## goes and settling once he stops, and takes a blow and a killing blow without a
## ragdoll. Prints PASS/FAIL per check and quits with the number of failures as the exit
## code.
##
##   godot --headless --path cutting-board res://tests/mask_monger_check.tscn

const MONGER := preload("res://scenes/characters/mask_monger.tscn")
const VILLAGER := preload("res://scenes/characters/villager.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var region := _build_floor()
	await TestWorld.bake(region)

	var monger: Npc = MONGER.instantiate()
	var villager: Npc = VILLAGER.instantiate()
	var player := PLAYER.instantiate()
	add_child(monger)
	add_child(villager)
	add_child(player)
	monger.global_position = Vector3(0, 0.05, 0)
	villager.global_position = Vector3(3, 0.05, 3)
	player.global_position = Vector3(-3, 0.05, 3)
	await _physics_frames(10)

	var body := monger.body as MaskMongerBody
	_check("spawns with a MaskMongerBody", body != null)
	if body == null:
		_finish()
		return
	_check("spawns alive, in the actor group",
		monger.health.is_alive() and monger.is_in_group(Faction.GROUP))
	_check("is a villager", monger.faction.data and monger.faction.data.id == &"villagers")
	_check("is friendly to villagers", not monger.faction.is_hostile_to(villager)
		and not villager.faction.is_hostile_to(monger))
	_check("is friendly to the player", not monger.faction.is_hostile_to(player)
		and not Faction.find_in(player).is_hostile_to(monger))
	_check("his body resolves to him", body.get_actor() == monger)
	villager.queue_free()
	player.queue_free()

	await _walk(monger, body)
	await _hit(monger, body)
	_finish()


## Sends him, brain off, along a path around a block and follows the gait as he goes.
func _walk(monger: Npc, body: MaskMongerBody) -> void:
	monger.brain.shut_down()
	var goal := Vector3(0, 0, 7)
	var start_phase := body._phase
	var leg := monger.get_node("%Body/%LegL") as Node3D
	var leg_rest := leg.basis
	var gait_peak := 0.0
	var leg_turn := 0.0
	var top_speed := 0.0
	monger.locomotion.move_to(goal)
	var waited := 0.0
	while waited < 25.0 and monger.locomotion.is_moving():
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		gait_peak = maxf(gait_peak, body._gait)
		leg_turn = maxf(leg_turn, leg.basis.get_euler().x - leg_rest.get_euler().x)
		top_speed = maxf(top_speed, _flat(monger.get_real_velocity()).length())
	var cycles := body._phase - start_phase
	var off := _flat(monger.global_position - goal).length()
	print("  walk: %.2f s, %.2f m from the goal, top speed %.2f m/s, %.1f gait cycles, gait peak %.2f, leg swung %.1f deg" % [
		waited, off, top_speed, cycles, gait_peak, rad_to_deg(leg_turn)
	])
	_check("walks the path to the goal", off < 1.0)
	_check("walks slowly (under 1.2 m/s)", top_speed > 0.3 and top_speed < 1.2)
	_check("the gait advances while he walks", cycles > 3.0 and gait_peak > 0.5)
	_check("his legs swing", leg_turn > deg_to_rad(5.0))
	await _physics_frames(120)
	print("  standing: gait %.2f" % body._gait)
	_check("the gait settles once he stops", body._gait < 0.05)


## A blow rocks him without a ragdoll; a killing blow slumps him for good.
func _hit(monger: Npc, body: MaskMongerBody) -> void:
	var info := DamageInfo.new(10)
	info.direction = Vector3.RIGHT
	info.knockback = 3.0
	monger.health.apply_damage(info)
	await _physics_frames(6)
	print("  hit: rocked %.1f deg" % rad_to_deg(absf(body._jolt)))
	_check("a hit rocks him and he stands", absf(body._jolt) > deg_to_rad(0.5) and not body.is_limp())
	var limp := [false]
	body.went_limp.connect(func() -> void: limp[0] = true)
	var killing := DamageInfo.new(1000)
	killing.direction = Vector3.LEFT
	monger.health.apply_damage(killing)
	await _physics_frames(90)
	_check("a killing blow slumps him", body.is_limp() and limp[0] and body._slump > 0.9
		and not monger.health.is_alive())


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## A flat floor with a wall across the straight line to the goal, and a navigation region
## baked from both, set up like test_level's.
func _build_floor() -> NavigationRegion3D:
	TestWorld.add_floor(self, 60)
	TestWorld.add_slab(self, Vector3(3, 2, 1), Vector3(0, 1, 3.5))
	return TestWorld.add_nav_region(self)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
