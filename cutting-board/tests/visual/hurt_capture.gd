extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")

const TIMELINE := [
	[1.0, 8],
	[2.2, 22],
	[3.6, 15],
	[5.0, 28],
	[8.0, 15],
	[11.5, -60],
]
const CLIPS := {
	"light": [[0.5, 8]],
	"heavy": [[0.5, 22]],
	"low": [[0.5, 70], [2.5, 18], [9.0, -60]],
}

var _die := false
var _player: Node3D
var _health: Health
var _time := 0.0
var _next := 0
var _timeline: Array = TIMELINE


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--die":
			_die = true
		elif arg == "--no-retro":
			PsxScreen.enabled = false
		elif arg.begins_with("--clip="):
			_timeline = CLIPS[arg.trim_prefix("--clip=")]
	var level := LEVEL.instantiate()
	add_child(level)
	_player = level.get_node("Player")
	_health = Health.find_in(_player)
	MouseGrab.release()
	if "--no-mirror" in OS.get_cmdline_user_args():
		var mirror := _player.find_child("FunhouseMirror", true, false) as FunhouseMirror
		mirror.enabled = false


func _process(delta: float) -> void:
	_time += delta
	if _next >= _timeline.size():
		return
	var step: Array = _timeline[_next]
	if _time < step[0]:
		return
	_next += 1
	var amount: int = step[1]
	if amount < 0 and _die:
		amount = _health.get_current()
	if amount < 0:
		_health.heal(-amount)
		print("t=%.1f heal %d -> %d" % [_time, -amount, _health.get_current()])
	else:
		var info := DamageInfo.new(amount)
		info.position = _player.global_position + _player.global_basis.z * 4.0
		_health.apply_damage(info)
		print("t=%.1f hit %d -> %d" % [_time, amount, _health.get_current()])
