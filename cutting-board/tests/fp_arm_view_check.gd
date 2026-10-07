extends Node3D

## Headless checks on the first-person punches: all through each punch the cut end of
## the arm (the UpperArm bone's origin, with a margin for the arm's thickness) stays out
## of the camera's view at the game's 16:9 aspect, and at the hit frame the fist lands
## near the middle of the screen. Prints PASS/FAIL per check and quits with the number
## of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/fp_arm_view_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
## The game's aspect, from the project's viewport size.
const ASPECT := 1280.0 / 720.0
## How far round the bone's origin the arm's skin reaches, in metres.
const ARM_RADIUS := 0.12
## At the hit, the fist must sit within this fraction of the half-width of centre.
const CENTRE_SPAN := 0.35

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player: Node3D = PLAYER.instantiate()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = player.get_node("%Camera3D")
	for side in ["Left", "Right"]:
		var anim_player: AnimationPlayer = player.get_node("%%%sPlayer" % side)
		var skeleton: Skeleton3D = player.get_node("%%Arm%sSkeleton" % side)
		var slot: Node3D = player.get_node("%%HandSlot%s" % side)
		anim_player.play("punch_unarmed_%s" % side.to_lower())
		var worst := -INF
		var t := 0.0
		while t <= 0.35:
			anim_player.seek(t, true)
			worst = maxf(worst, _view_overlap(camera, skeleton))
			t += 0.01
		_check(worst < 0.0, "%s punch keeps the arm's cut end out of view (margin %.3f)" % [side, -worst])
		anim_player.seek(0.18, true)
		(player.get_node("%%Hand%s" % side) as BoneAttachment3D).on_skeleton_update()
		var fist := camera.global_transform.affine_inverse() * slot.global_position
		var half_width := -fist.z * tan(deg_to_rad(camera.fov * 0.5)) * ASPECT
		var across := fist.x / half_width
		_check(absf(across) < CENTRE_SPAN, "%s fist lands near the centre (%.2f of half-width)" % [side, across])
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


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
