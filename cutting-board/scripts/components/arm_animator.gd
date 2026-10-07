class_name ArmAnimator
extends Node3D

## The first-person arm rig, and the component that animates it. Actions are asked for
## by name — "punch" — and which animation actually plays is resolved from what the hand
## is holding, so giving a weapon its own swing is a new animation plus a name on its
## ItemData, never a change here.
##
## Animations are named <action>_<set>_<side>: punch_unarmed_left, swing_hammer_right,
## block_shield_both. The set comes from ItemData.animation_set and falls back to
## FALLBACK_SET, which is what lets an item with no animations of its own still throw a
## plain punch.
##
## Each arm has its own AnimationPlayer, so the hands are independent: the left can
## punch while the right is busy with something else. A two-armed action is a single
## animation with tracks for both arms, played on the left player while the right one is
## held; both arms then read as busy until it has finished.
##
## Animation, not procedural motion, is what lives here. The walk bob and jump lift in
## player.gd are written to the ArmLeftPivot / ArmRightPivot nodes above each arm, and
## these animations pose the bones of the arm's skeleton inside its pivot (UpperArm,
## Forearm and Hand, see tools/import/build_fp_arms.gd), so the two compose instead of
## overwriting one another every frame. Each animation starts and ends on the idle pose
## the skeletons rest in, a slightly bent elbow and wrist.

## The moment a blow lands, fired from a method track inside the animation itself rather
## than on a timer here, so retiming a swing in the editor retimes its damage with it.
signal hit(arm: int)
## A named moment inside a two-armed action — "dab", "clamp", "mend" in the glue use —
## fired from its method track, so whoever started the action can hang sounds and
## effects off the frames they belong to.
signal beat(beat_name: StringName)

enum Arm { LEFT, RIGHT, BOTH }

## The animation set used when the held item names none, or names one that has no
## animation for the action being played.
const FALLBACK_SET := &"unarmed"
## The library the mirrored copies of two-armed animations are kept in, built on demand.
const MIRRORED_LIBRARY := &"mirrored"

## How far the view tilts down (radians, about the camera's x) for an action that needs
## to look at the body, like the glue use looking at the chest. Animated by the action's
## own track; the player adds it to the camera.
var view_tilt := 0.0

@onready var _left_player: AnimationPlayer = %LeftPlayer
@onready var _right_player: AnimationPlayer = %RightPlayer

## True while a two-armed animation is running on the left player, which is what makes
## the right arm report as busy even though its own player is idle.
var _both_busy := false


func _ready() -> void:
	_left_player.animation_finished.connect(_on_left_finished.unbind(1))


## Plays an action on one arm or on both. Returns false when the arm is already busy or
## no animation exists for it, so a caller can fall through to some other behaviour
## rather than pretend the action happened. `mirror` plays a two-armed action with the
## arms' roles swapped, so a glue pot held in the left hand dabs with the left.
func play_action(action: StringName, arm: int, held: ItemData = null, mirror := false) -> bool:
	if is_busy(arm):
		return false
	var animation := _resolve(action, held, _side_name(arm))
	if animation.is_empty():
		return false
	if arm == Arm.BOTH:
		if mirror:
			animation = _mirrored(animation)
		# One animation drives both arms, so the other player is taken out of the way
		# rather than left to fight it over the same tracks.
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


## True while a two-armed action is running: both arms are taken.
func is_two_armed() -> bool:
	return _both_busy


## Cuts a two-armed action short: both arms and the view snap back to rest, and no
## further beats fire.
func cancel() -> void:
	if not _both_busy:
		return
	_both_busy = false
	# Every animation ends on the idle pose and a level view.
	_left_player.seek(_left_player.current_animation_length, true)
	_left_player.stop(true)
	view_tilt = 0.0


## Called from the method track in each attack animation, at the frame the blow lands.
## It is public because the animation addresses it by name.
func emit_hit(arm: int) -> void:
	hit.emit(arm)


## Called from the method track of a two-armed action at each of its beats. A cancelled
## action has no more beats.
func emit_beat(beat_name: StringName) -> void:
	if _both_busy:
		beat.emit(beat_name)


## The animation to play, preferring the held item's own set and falling back to the
## unarmed one. Returns an empty string when neither exists, which is how an action
## nobody has animated yet stays silent instead of erroring.
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


## The mirror image of a two-armed animation, named for playing on the left player:
## the arms trade tracks, and since the two rigs are mirror images across the view's
## centre, each pose flips across x (positions negate x, rotations negate y and z).
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
