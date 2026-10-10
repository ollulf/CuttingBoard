class_name ArmAnimator
extends Node3D

signal hit(arm: int)
signal beat(beat_name: StringName)

enum Arm { LEFT, RIGHT, BOTH }

const FALLBACK_SET := &"unarmed"
const MIRRORED_LIBRARY := &"mirrored"

var view_tilt := 0.0

@onready var _left_player: AnimationPlayer = %LeftPlayer
@onready var _right_player: AnimationPlayer = %RightPlayer

var _both_busy := false


func _ready() -> void:
	_left_player.animation_finished.connect(_on_left_finished.unbind(1))


func play_action(action: StringName, arm: int, held: ItemData = null, mirror := false) -> bool:
	if is_busy(arm):
		return false
	var animation := _resolve(action, held, _side_name(arm))
	if animation.is_empty():
		return false
	if arm == Arm.BOTH:
		if mirror:
			animation = _mirrored(animation)
		_right_player.stop()
		_both_busy = true
		_left_player.play(animation)
		return true
	_player_for(arm).play(animation)
	return true


func is_busy(arm: int) -> bool:
	if _both_busy:
		return true
	match arm:
		Arm.LEFT:
			return _left_player.is_playing()
		Arm.RIGHT:
			return _right_player.is_playing()
	return _left_player.is_playing() or _right_player.is_playing()


func is_two_armed() -> bool:
	return _both_busy


func cancel() -> void:
	if not _both_busy:
		return
	_both_busy = false
	_left_player.seek(_left_player.current_animation_length, true)
	_left_player.stop(true)
	view_tilt = 0.0


func emit_hit(arm: int) -> void:
	hit.emit(arm)


func emit_beat(beat_name: StringName) -> void:
	if _both_busy:
		beat.emit(beat_name)


func _resolve(action: StringName, held: ItemData, side: String) -> String:
	if held and not held.animation_set.is_empty():
		var named := "%s_%s_%s" % [action, held.animation_set, side]
		if _left_player.has_animation(named):
			return named
	var fallback := "%s_%s_%s" % [action, FALLBACK_SET, side]
	return fallback if _left_player.has_animation(fallback) else ""


func _side_name(arm: int) -> String:
	match arm:
		Arm.LEFT:
			return "left"
		Arm.RIGHT:
			return "right"
	return "both"


func _player_for(arm: int) -> AnimationPlayer:
	return _right_player if arm == Arm.RIGHT else _left_player


func _mirrored(animation_name: String) -> String:
	var mirrored_name := "%s/%s" % [MIRRORED_LIBRARY, animation_name]
	if _left_player.has_animation(mirrored_name):
		return mirrored_name
	if not _left_player.has_animation_library(MIRRORED_LIBRARY):
		_left_player.add_animation_library(MIRRORED_LIBRARY, AnimationLibrary.new())
	var animation: Animation = _left_player.get_animation(animation_name).duplicate(true)
	for track in animation.get_track_count():
		var path := String(animation.track_get_path(track))
		if not path.contains("Left") and not path.contains("Right"):
			continue
		path = path.replace("Left", "\u0001").replace("Right", "Left").replace("\u0001", "Right")
		animation.track_set_path(track, NodePath(path))
		for key in animation.track_get_key_count(track):
			var value = animation.track_get_key_value(track, key)
			match animation.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					var q: Quaternion = value
					animation.track_set_key_value(track, key, Quaternion(q.x, -q.y, -q.z, q.w))
				Animation.TYPE_POSITION_3D:
					var p: Vector3 = value
					animation.track_set_key_value(track, key, Vector3(-p.x, p.y, p.z))
	_left_player.get_animation_library(MIRRORED_LIBRARY).add_animation(animation_name, animation)
	return mirrored_name


func _on_left_finished() -> void:
	_both_busy = false
