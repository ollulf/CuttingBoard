extends Node3D

const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 60)
	await TestWorld.bake(TestWorld.add_nav_region(self))
	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	var player_health: Health = player.get_node("%Health")
	player_health.max_health = 100000
	player_health.reset()

	var bandit := _spawn(Vector3(0, 0.05, -3))
	var buddy := _spawn(Vector3(8, 0.05, -3))
	_toughen(bandit)
	_toughen(buddy)
	await _physics_frames(5)
	buddy.brain.shut_down()
	bandit.look_at(player.global_position, Vector3.UP)
	bandit.memory.remember(player)
	bandit.hold_grudge(player)
	await _wait(1.0)
	_check("a masked bandit targets the player", bandit.get_attack_target() == player)

	var body: HumanBody = bandit.body
	body.break_mask()
	await _physics_frames(2)
	_check("the mask is gone", body.mask == null)
	_check("the bandit goes blind", bandit.blind)
	_check("it forgets everyone", bandit.memory.get_known().is_empty())
	_check("it holds no grudge", bandit.get_grudges().is_empty())
	_check("it has no faction", bandit.faction.data == null)
	_check("it has no attack target", bandit.get_attack_target() == null)
	_check("it is not in combat", not bandit.is_in_combat())
	_check("its brain stops", bandit.brain.get_current_action() == null)
	_check("it plays the blind collapse", bandit.is_collapsing())
	_check("it lets go of what it held", bandit.hand_right.is_free() and bandit.hand_left.is_free())
	_check("other bandits leave it be", not buddy.faction.is_hostile_to(bandit))
	_check("the player is no enemy to it", not bandit.faction.is_hostile_to(player))

	var start := bandit.global_position
	var player_hp := player_health.get_current()
	var farthest := 0.0
	var seen_player := false
	for i in 8:
		await _wait(0.5)
		farthest = maxf(farthest, start.distance_to(bandit.global_position))
		seen_player = seen_player or bandit.memory.knows(player)
		bandit.hear_of(player, player.global_position)
	_check("it never sees or hears the player", not seen_player and not bandit.memory.knows(player))
	_check("it never hurts the player", player_health.get_current() == player_hp)
	_check("it gropes a few steps forward", farthest > 0.2 and farthest < 3.0)
	_check("it is still alive while it collapses", bandit.health.is_alive() and not body.is_limp())

	buddy.call_for_help(player, player.global_position)
	_check("a call for help does not reach it", not bandit.memory.knows(player))

	for i in 16:
		if not bandit.health.is_alive():
			break
		await _wait(0.5)
	_check("it dies at the end of the collapse", not bandit.health.is_alive())
	_check("its body goes ragdoll", body.is_limp())
	_check("it stops collapsing", not bandit.is_collapsing())
	_check("it is not rated a threat", not bandit.is_in_group(Faction.GROUP))

	var buddy_body: HumanBody = buddy.body
	buddy_body.break_mask()
	await _wait(1.0)
	_check("the second bandit collapses too", buddy.is_collapsing() and buddy.health.is_alive())
	buddy.health.apply_damage(DamageInfo.new(1, player))
	await _physics_frames(3)
	_check("a blow during the collapse kills it at once", not buddy.health.is_alive())
	_check("and it goes ragdoll right away", buddy_body.is_limp())
	_check("it bore no grudge for the blow", not buddy.has_grudge_against(player))

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _spawn(at: Vector3) -> Npc:
	var npc := BANDIT.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _toughen(npc: Npc) -> void:
	npc.health.max_health = 1000
	npc.health.reset()


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
