extends Node3D

## Headless checks that a held item rides the hand bone: while the player walks, and all
## through a punch, the item in each hand sits exactly where the Hand bone (plus the
## HandSlot's offset) puts it, position and rotation; and the walk does turn the hands,
## not only lift them, so what they hold tilts with each step. Prints PASS/FAIL per check
## and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/held_item_follow_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
## Both are weapons: a hand holding anything else (wood glue, say) does not punch.
const SAW := preload("res://resources/items/saw.tres")
const HAMMER := preload("res://resources/items/hammer.tres")
## How far the item may stray from the bone's pose, in metres and in radians.
const TOLERANCE := 0.002

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_add_floor()
	var player = PLAYER.instantiate()
	add_child(player)
	await _physics_frames(10)
	var left: Node3D = player.interactor.spawn_into_hand(SAW, -1, player.hand_left)
	var right: Node3D = player.interactor.spawn_into_hand(HAMMER, -1, player.hand_right)
	_check("both hands hold an item", left != null and right != null)
	if left == null or right == null:
		_finish()
		return
	await _walk(player, left, right)
	await _punch(player, player.hand_right, right, "Right")
	await _punch(player, player.hand_left, left, "Left")
	_finish()


## Walks forward for a second, comparing each item with its bone every frame and
## measuring how far the items turn against the camera.
func _walk(player, left: Node3D, right: Node3D) -> void:
	var start_left := _in_view(player, left).basis
	var start_right := _in_view(player, right).basis
	var worst := 0.0
	var turn_left := 0.0
	var turn_right := 0.0
	Input.action_press("move_forward")
	for i in 60:
		await get_tree().process_frame
		worst = maxf(worst, maxf(_stray(player, left, "Left"), _stray(player, right, "Right")))
		turn_left = maxf(turn_left, _angle(start_left, _in_view(player, left).basis))
		turn_right = maxf(turn_right, _angle(start_right, _in_view(player, right).basis))
	Input.action_release("move_forward")
	_check("walking, the held items stay on the hand bones (off by %.4f)" % worst, worst < TOLERANCE)
	_check("walking turns the left hand's item (%.1f deg)" % rad_to_deg(turn_left), turn_left > deg_to_rad(2.0))
	_check("walking turns the right hand's item (%.1f deg)" % rad_to_deg(turn_right), turn_right > deg_to_rad(2.0))
	await _physics_frames(30)


## Throws a punch with the item in `hand`, comparing it with its bone every frame.
func _punch(player, hand: HandSlot, item: Node3D, side: String) -> void:
	var start := _in_view(player, item)
	player._punch(hand)
	var worst := 0.0
	var travel := 0.0
	for i in 30:
		await get_tree().process_frame
		worst = maxf(worst, _stray(player, item, side))
		travel = maxf(travel, start.origin.distance_to(_in_view(player, item).origin))
	_check("%s punch: the item stays on the hand bone (off by %.4f)" % [side, worst], worst < TOLERANCE)
	_check("%s punch: the item travels with the fist (%.2f m)" % [side, travel], travel > 0.1)
	_check("%s punch: still held afterwards" % side, hand.get_held() == item)


## How far `item` is from where the Hand bone of `side` holds it: the larger of the
## distance between origins and the angle between the two orientations.
func _stray(player, item: Node3D, side: String) -> float:
	var skeleton: Skeleton3D = player.get_node("%%Arm%sSkeleton" % side)
	var slot: Node3D = player.get_node("%%HandSlot%s" % side)
	var bone := skeleton.find_bone("Hand")
	var expected := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * slot.transform
	var actual := item.global_transform
	return maxf(expected.origin.distance_to(actual.origin), _angle(expected.basis, actual.basis))


## The item's transform as the camera sees it, so the body's own turning is left out.
func _in_view(player, item: Node3D) -> Transform3D:
	return player.camera.global_transform.affine_inverse() * item.global_transform


func _angle(a: Basis, b: Basis) -> float:
	return a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion())


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1
