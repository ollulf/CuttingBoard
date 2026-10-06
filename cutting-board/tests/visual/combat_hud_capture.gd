extends Node

## A fight in the test level for the combat HUD: one bandit, everyone else cleared away.
## The bandit spots the player and comes at them (the target bar appears), they trade
## blows (both bars drain), the bandit dies (its bar runs out and goes), and once the
## fight has been quiet for CombatTracker.linger seconds the player's bar is released.
##
##   godot --path cutting-board res://tests/visual/combat_hud_capture.tscn -- --shots=<dir>
##   godot --path cutting-board --write-movie <out>.avi --fixed-fps 30 \
##       res://tests/visual/combat_hud_capture.tscn
##
## The player keeps facing the bandit and punches whenever it is in reach; punches are
## made harder than usual so the fight is over in a few blows. Needs a real window to
## save shots; under --headless it still runs and prints what the tracker reports.

const LEVEL := preload("res://scenes/levels/test_level.tscn")

## Damage of the player's punch for this capture, so a 60 HP bandit falls in three.
const PUNCH_DAMAGE := 20
const PUNCH_EVERY := 0.8
## When the bandit turns up, 9 m in front of the player.
const ARRIVE_AT := 2.0
## Closest the bandit is let come, flat, in metres.
const MIN_GAP := 1.15

var _shots_dir := ""
var _player: CharacterBody3D
var _bandit: Npc
var _tracker: CombatTracker
var _time := 0.0
var _until_punch := 0.6
var _bandit_died_at := -1.0
var _shots_taken := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var level := LEVEL.instantiate()
	add_child(level)
	_player = level.get_node("Player")
	_tracker = _player.get_node("%CombatTracker")
	_player.melee.unarmed_damage = PUNCH_DAMAGE
	# One bandit, nobody else to fight or flee, nothing standing in between.
	for node in level.find_children("*", "Npc", true, false):
		if node.name != "Bandit":
			node.queue_free()
	level.get_node("TrainingDummy").queue_free()
	_bandit = level.get_node("Bandit")
	# Parked out of sight until it is time for it to turn up.
	_bandit.position = _player.position + Vector3(0.0, 0.0, 40.0)
	_bandit.rotation.y = 0.0
	_bandit.health.died.connect(func(_info: DamageInfo) -> void: _bandit_died_at = _time)
	_tracker.combat_changed.connect(func(on: bool) -> void: print("%.2f combat %s" % [_time, on]))
	_tracker.target_changed.connect(func(t: Node3D) -> void:
		print("%.2f target %s" % [_time, CombatTracker.name_of(t) if t else "none"]))
	_player.health.changed.connect(func(c: int, _m: int) -> void: print("%.2f player %d" % [_time, c]))
	_bandit.health.changed.connect(func(c: int, _m: int) -> void: print("%.2f bandit %d" % [_time, c]))


func _process(delta: float) -> void:
	_time += delta
	if _time >= ARRIVE_AT and _time - delta < ARRIVE_AT:
		_bandit.global_position = (_player.global_position
			+ _player.global_basis * Vector3(1.0, 0.0, -9.0))
		# It has spotted the player, whichever way it happened to be looking.
		_bandit.memory.remember(_player)
	if _time >= ARRIVE_AT:
		_face_bandit(delta)
		_keep_distance()
	if is_instance_valid(_bandit) and _bandit.health.is_alive():
		var reach: float = _player.global_position.distance_to(_bandit.global_position)
		_until_punch -= delta
		# The player holds off until the bandit has landed a blow, so both bars drain.
		var hurt: bool = _player.health.get_current() < _player.health.max_health
		if reach < 1.7 and hurt and _until_punch <= 0.0:
			_until_punch = PUNCH_EVERY
			_player._punch(_player.hand_right)

	_shot_at(1.0, "01_before_combat")
	_shot_when(_tracker.get_target() != null, 0.3, "02_bar_appears")
	_shot_when(_player.health.get_current() < _player.health.max_health, 0.15, "03_player_hit")
	_shot_when(_bandit.health.get_current() < _bandit.health.max_health, 0.15, "04_bandit_hit_trail")
	if _bandit_died_at >= 0.0:
		_shot_at(_bandit_died_at + 0.6, "05_bandit_dead_bar_empty")
		_shot_at(_bandit_died_at + 3.0, "06_still_in_combat_no_target")
		_shot_at(_bandit_died_at + _tracker.linger + 1.5, "07_combat_over")
		if _time > _bandit_died_at + _tracker.linger + 2.0:
			get_tree().quit()
	if _time > 40.0:
		print("timed out")
		get_tree().quit()


## Turns the player and their view onto the bandit's chest, a little at a time.
func _face_bandit(delta: float) -> void:
	if not is_instance_valid(_bandit):
		return
	var chest := _bandit.global_position + Vector3.UP * 1.1
	var to: Vector3 = chest - _player.camera_pivot.global_position
	var yaw := atan2(-to.x, -to.z)
	var weight := 1.0 - exp(-8.0 * delta)
	_player.rotation.y = lerp_angle(_player.rotation.y, yaw, weight)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_player.camera_pivot.rotation.x = lerpf(_player.camera_pivot.rotation.x, pitch, weight)


## Steps the player back when the bandit crowds in. A bandit that runs in closer than
## its swing starts its blow from inside the player's capsule, where the ray cannot
## find them, so without this the fight would be one-sided.
func _keep_distance() -> void:
	if not is_instance_valid(_bandit) or not _bandit.health.is_alive():
		return
	var away: Vector3 = _player.global_position - _bandit.global_position
	away.y = 0.0
	if away.length() < MIN_GAP and not away.is_zero_approx():
		_player.global_position = _bandit.global_position + away.normalized() * MIN_GAP \
			+ Vector3.UP * (_player.global_position.y - _bandit.global_position.y)


func _shot_at(at: float, shot_name: String) -> void:
	if _time >= at:
		_shot(shot_name)


## Saves `shot_name` `delay` seconds after `condition` first holds.
func _shot_when(condition: bool, delay: float, shot_name: String) -> void:
	var key := "when_" + shot_name
	if condition and not _shots_taken.has(key):
		_shots_taken[key] = _time
	if _shots_taken.has(key) and _time >= _shots_taken[key] + delay:
		_shot(shot_name)


func _shot(shot_name: String) -> void:
	if _shots_taken.has(shot_name):
		return
	_shots_taken[shot_name] = _time
	print("%.2f shot %s" % [_time, shot_name])
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
