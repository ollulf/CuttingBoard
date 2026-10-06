extends Node3D

## Headless checks for the Music autoload: Outside plays at the start and while the player
## only hits things, Combat fades in once an NPC goes for the player — a villager with a
## grudge, a bandit — and Outside comes back combat_grace seconds after the last one
## stopped: its grudge ran out, or it died. Prints PASS/FAIL per check and quits with the
## number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/music_check.tscn

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const DUMMY := preload("res://scenes/characters/training_dummy.tscn")

const OUTSIDE := 0
const COMBAT := 1

var _failures := 0
var _player: Node3D
var _music: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(5)
	_music = get_node("/root/Music")
	_music.fade_time = 0.4
	_music.combat_grace = 1.5
	var region := _build_floor()
	await _bake(region)
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(0, 0.05, 0)
	await _physics_frames(5)
	var player_health: Health = _player.get_node("%Health")
	player_health.max_health = 100000
	player_health.reset()

	await _wait(0.5)
	_check("Outside at the start", _music.get_cue() == OUTSIDE and _music.get_mix() == 0.0)
	_check("Outside cue is a loop on the Music bus", _player_of("outside"))

	# The player's own blows on something that does not fight back are not a fight.
	var dummy := DUMMY.instantiate() as Node3D
	add_child(dummy)
	dummy.position = Vector3(0, 0, -20)
	Health.find_in(dummy).apply_damage(DamageInfo.new(10, _player))
	await _wait(1.0)
	_check("hitting a dummy keeps Outside", _music.get_cue() == OUTSIDE)
	dummy.queue_free()

	await _villager_grudge()
	await _bandit()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## A villager hit by the player goes for it: Combat. Its short grudge runs out and, after
## the grace time, Outside is back.
func _villager_grudge() -> void:
	var villager := _spawn(VILLAGER, Vector3(0, 0.05, -4))
	villager.grudge_duration = 2.0
	await _physics_frames(5)
	villager.health.apply_damage(DamageInfo.new(5, _player))
	var waited := await _wait_for_cue(COMBAT, 4.0)
	print("  villager: Combat after %.2f s" % waited)
	_check("villager with a grudge: Combat", _music.get_cue() == COMBAT)
	await _wait(0.6)
	_check("villager: crossfade completes", is_equal_approx(_music.get_mix(), 1.0))

	# Grudges expire on the wall clock, which under --fixed-fps runs slower than the game,
	# so wait on the fight itself rather than a set time.
	var wall_start := Time.get_ticks_msec()
	while _is_fighting(villager) and Time.get_ticks_msec() - wall_start < 8000:
		await get_tree().physics_frame
		_pin_player()
	await _wait(0.5)
	_check("grudge over: villager stops going for the player", not _is_fighting(villager))
	_check("grudge over: Combat held through the grace time", _music.get_cue() == COMBAT)
	waited = await _wait_for_cue(OUTSIDE, 3.0)
	print("  villager: Outside %.2f s later" % waited)
	_check("grudge over: Outside after the grace time", _music.get_cue() == OUTSIDE)
	await _wait(0.6)
	_check("grudge over: crossfade back completes", _music.get_mix() == 0.0)
	villager.queue_free()
	await _physics_frames(2)


## A bandit spots the player and attacks: Combat. Killed, it no longer counts.
func _bandit() -> void:
	var bandit := _spawn(BANDIT, Vector3(0, 0.05, -5))
	await _physics_frames(5)
	var waited := await _wait_for_cue(COMBAT, 12.0)
	print("  bandit: Combat after %.2f s" % waited)
	_check("bandit going for the player: Combat", _music.get_cue() == COMBAT)
	bandit.health.apply_damage(DamageInfo.new(99999, _player))
	await _wait(0.5)
	_check("bandit dead: Combat held through the grace time", _music.get_cue() == COMBAT)
	await _wait_for_cue(OUTSIDE, 3.0)
	_check("bandit dead: Outside after the grace time", _music.get_cue() == OUTSIDE)


## Waits, in game time, until the music is on `cue` or `limit` seconds have passed.
## Returns the time waited.
func _wait_for_cue(cue: int, limit: float) -> float:
	var waited := 0.0
	while waited < limit and _music.get_cue() != cue:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		_pin_player()
	return waited


func _player_of(which: String) -> bool:
	for child in _music.get_children():
		var player := child as AudioStreamPlayer
		if player and player.stream and player.stream.resource_path.ends_with(which + ".ogg"):
			return player.bus == &"Music" and player.stream.loop and player.playing
	return false


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _is_fighting(npc: Npc) -> bool:
	var action := npc.brain.get_current_action()
	return action is AttackTargetAction or action is ThrowAtTargetAction


## Keeps the player standing where it was put.
func _pin_player() -> void:
	_player.global_position = Vector3(0, _player.global_position.y, 0)


func _build_floor() -> NavigationRegion3D:
	var floor_body := StaticBody3D.new()
	floor_body.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)
	return region


func _bake(region: NavigationRegion3D) -> void:
	region.bake_navigation_mesh(false)
	var map := get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			break


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
