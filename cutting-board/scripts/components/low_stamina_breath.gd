class_name LowStaminaBreath
extends Node

@export var stamina: Stamina
@export var health: Health
@export var bank: SoundBank = preload("res://resources/audio/breath.tres")
@export_range(0.0, 1.0, 0.01) var start_ratio := 0.28
@export_range(0.0, 1.0, 0.01) var stop_ratio := 0.4
@export var interval_calm := 1.7
@export var interval_spent := 1.05
@export var volume_calm_db := -8.0
@export var volume_spent_db := 0.0
@export var fade_time := 0.6

var _player: AudioStreamPlayer
var _active := false
var _dead := false
var _until_next := 0.0
var _fade: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	if health:
		health.died.connect(_on_died)
		health.changed.connect(_on_health_changed)


func is_breathing() -> bool:
	return _active


func is_audible() -> bool:
	return _player.playing and not _player.stream_paused


func _process(delta: float) -> void:
	if stamina == null or _dead:
		return
	var ratio := stamina.get_ratio()
	if not _active and ratio < start_ratio:
		_start()
	elif _active and ratio > stop_ratio:
		_stop(fade_time)
	if not _active:
		return
	_until_next -= delta
	if _until_next <= 0.0:
		_breathe(1.0 - clampf(ratio / maxf(start_ratio, 0.001), 0.0, 1.0))


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_PAUSED:
		_player.stream_paused = true
	elif what == NOTIFICATION_UNPAUSED:
		_player.stream_paused = false


func _start() -> void:
	_active = true
	_until_next = 0.0


func _breathe(strain: float) -> void:
	if bank == null or bank.streams.is_empty():
		return
	if _fade:
		_fade.kill()
	_player.stream = bank.pick()
	_player.bus = bank.bus
	_player.volume_db = bank.random_volume_db() + lerpf(volume_calm_db, volume_spent_db, strain)
	_player.pitch_scale = bank.random_pitch() * lerpf(1.0, 1.12, strain)
	_player.play()
	_until_next = lerpf(interval_calm, interval_spent, strain)


func _stop(fade: float) -> void:
	_active = false
	if _fade:
		_fade.kill()
	if fade <= 0.0 or not _player.playing:
		_player.stop()
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, fade)
	_fade.tween_callback(_player.stop)


func _on_died(_info: DamageInfo) -> void:
	_dead = true
	_stop(0.0)


func _on_health_changed(_current: int, _maximum: int) -> void:
	if _dead and health.is_alive():
		_dead = false
