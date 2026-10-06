extends Node

## Puts the health bar through its states for screenshots and clips: loads the test
## level, then hurts the player on a fixed timeline — full, a hit with the damage trail
## draining, a second hit, a hit down to critical (the frame beats), and a heal.
##
##   godot --path cutting-board res://tests/visual/health_bar_capture.tscn -- --shots=<dir>
##   godot --path cutting-board --write-movie <out>.avi --fixed-fps 30 \
##       res://tests/visual/health_bar_capture.tscn
##
## Needs a real window to save shots; under --headless it only runs the timeline. Quits
## when the timeline is over, so a movie recording stops by itself.

const LEVEL := preload("res://scenes/levels/test_level.tscn")

## Seconds to wait, then what to do: an int hurts (negative heals), a String saves a shot.
const TIMELINE := [
	[1.5, "01_full"],
	[0.3, 30],
	[0.1, "02_hit_trail"],
	[0.7, "03_trail_draining"],
	[1.4, "04_settled_70"],
	[0.3, 25],
	[2.2, "05_hurt_45"],
	[0.3, 30],
	[0.1, "06_critical_hit_trail"],
	[2.0, "07_critical_beat_a"],
	[0.5, "08_critical_beat_b"],
	[0.6, -40],
	[0.15, "09_heal"],
	[1.5, "10_healed_55"],
]

var _shots_dir := ""
var _health: Health


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	var level := LEVEL.instantiate()
	add_child(level)
	_health = Health.find_in(level.get_node("Player"))
	_run.call_deferred()


func _run() -> void:
	for step in TIMELINE:
		await get_tree().create_timer(step[0]).timeout
		if step[1] is String:
			await _save(step[1])
		elif step[1] > 0:
			_health.apply_damage(DamageInfo.new(step[1]))
		else:
			_health.heal(-step[1])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _save(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _shots_dir.path_join("%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
