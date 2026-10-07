extends Node3D

## Headless checks on the first-person blows, the bare punch and the weapon swing: all
## through each one the cut end of the arm (the UpperArm bone's origin, with a margin for
## the arm's thickness) stays out of the camera's view at the game's 16:9 aspect, and at
## the hit frame the fist lands near the middle of the screen. Prints PASS/FAIL per check
## and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/fp_arm_view_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
## The game's aspect, from the project's viewport size.
const ASPECT := 1280.0 / 720.0
## How far round the bone's origin the arm's skin reaches, in metres.
const ARM_RADIUS := 0.12
## At the hit, the fist must sit within this fraction of the half-width of centre.
const CENTRE_SPAN := 0.35
## The animation sets swept: the bare punch and the swing every weapon uses.
const SETS := ["unarmed", "weapon"]

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = player.get_node("%Camera3D")
	for set_name in SETS:
		for side in ["Left", "Right"]:
			var anim_player: AnimationPlayer = player.get_node("%%%sPlayer" % side)
			var skeleton: Skeleton3D = player.get_node("%%Arm%sSkeleton" % side)
			var slot: Node3D = player.get_node("%%HandSlot%s" % side)
			var animation_name := "punch_%s_%s" % [set_name, side.to_lower()]
			var length := anim_player.get_animation(animation_name).length
			anim_player.play(animation_name)
			var worst := -INF
			var t := 0.0
			while t <= length:
				anim_player.seek(t, true)
				worst = maxf(worst, _view_overlap(camera, skeleton))
				t += 0.01
			_check(worst < 0.0, "%s %s keeps the arm's cut end out of view (margin %.3f)" % [side, animation_name, -worst])
			anim_player.seek(_hit_time(anim_player.get_animation(animation_name)), true)
			(player.get_node("%%Hand%s" % side) as BoneAttachment3D).on_skeleton_update()
			var fist := camera.global_transform.affine_inverse() * slot.global_position
			var half_width := -fist.z * tan(deg_to_rad(camera.fov * 0.5)) * ASPECT
			var across := fist.x / half_width
			_check(absf(across) < CENTRE_SPAN, "%s %s lands near the centre (%.2f of half-width)" % [side, animation_name, across])
	_check_two_armed(player, camera)
	_check_walk(player, camera)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


## Sweeps the walk swing (up to a run's stride) and the jump lift, at rest and all
## through each blow thrown mid-stride (the striking arm letting go of the sway as the
## player does), checking the cut ends stay hidden.
func _check_walk(player: Node3D, camera: Camera3D) -> void:
	var settle_time: float = player.arm_action_settle_time
	for set_name in SETS:
		for side in ["Left", "Right"]:
			var anim_player: AnimationPlayer = player.get_node("%%%sPlayer" % side)
			var skeleton: Skeleton3D = player.get_node("%%Arm%sSkeleton" % side)
			var animation_name := "punch_%s_%s" % [set_name, side.to_lower()]
			var length := anim_player.get_animation(animation_name).length
			anim_player.play(animation_name)
			var worst := -INF
			for jump in [-1.0, 0.0, 1.0]:
				var swing := -1.5
				while swing <= 1.5:
					var t := 0.0
					while t <= length:
						var sway := clampf(1.0 - t / settle_time, 0.0, 1.0)
						player.pose_arms(swing, jump, sway, sway)
						anim_player.seek(t, true)
						worst = maxf(worst, _view_overlap(camera, skeleton))
						t += 0.01
					swing += 0.25
			player.pose_arms(0.0, 0.0)
			_check(worst < 0.0, "%s %s keeps the cut end out of view through the walk swing and jump (margin %.3f)" % [side, animation_name, -worst])


## The two-armed glue use, as held in the right hand and mirrored for the left: both
## cut ends stay hidden all through it, and it ends with the view level again.
func _check_two_armed(player: Node3D, camera: Camera3D) -> void:
	var arms: ArmAnimator = player.get_node("%Arms")
	var anim_player: AnimationPlayer = player.get_node("%LeftPlayer")
	for animation_name in ["use_glue_both", arms._mirrored("use_glue_both")]:
		var length := anim_player.get_animation(animation_name).length
		anim_player.play(animation_name)
		var worst := -INF
		var t := 0.0
		while t <= length:
			anim_player.seek(t, true)
			camera.rotation.x = arms.view_tilt
			for side in ["Left", "Right"]:
				worst = maxf(worst, _view_overlap(camera, player.get_node("%%Arm%sSkeleton" % side)))
			t += 0.01
		_check(worst < 0.0, "%s keeps both cut ends out of view (margin %.3f)" % [animation_name, -worst])
		anim_player.seek(length, true)
		_check(is_zero_approx(arms.view_tilt), "%s ends with the view level" % animation_name)
		anim_player.stop()
	camera.rotation.x = 0.0


## When the animation's emit_hit key fires.
func _hit_time(animation: Animation) -> float:
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_METHOD:
			return animation.track_get_key_time(track, 0)
	return 0.0


## How far the UpperArm bone's origin, grown by ARM_RADIUS, reaches into the view
## frustum: negative while it stays outside.
func _view_overlap(camera: Camera3D, skeleton: Skeleton3D) -> float:
	var bone := skeleton.find_bone("UpperArm")
	var at := camera.global_transform.affine_inverse() \
			* (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin
	var depth := -at.z
	if depth + ARM_RADIUS < camera.near:
		return -1.0
	var half_height := tan(deg_to_rad(camera.fov * 0.5))
	var half_width := half_height * ASPECT
	# Distance outside each side plane, measured square to the plane.
	var outside := maxf(
			(absf(at.x) - half_width * depth) / sqrt(1.0 + half_width * half_width),
			(absf(at.y) - half_height * depth) / sqrt(1.0 + half_height * half_height))
	return ARM_RADIUS - outside


func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
