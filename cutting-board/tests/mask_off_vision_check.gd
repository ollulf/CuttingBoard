extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")
const MASK := Equipment.Slot.MASK

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player = TestWorld.masked_player(PLAYER)
	add_child(player)
	var equipment: Equipment = player.equipment
	var vision: MaskOffVision = player.get_node("MaskOffVision")
	var health := Health.find_in(player)
	health.max_health = 1000
	health.reset()
	await _frames(2)
	_check("masked: the world shows", vision.amount == 0.0 and not vision.visible)

	equipment.unequip(MASK)
	await _frames(3)
	_check("bare face: the fade starts", vision.amount > 0.0 and vision.amount < 1.0 and vision.visible)
	await _seconds(0.8)
	_check("bare face: the grain is fully in", vision.amount == 1.0 and vision.visible)

	equipment.equip(MASK, PLAYER_MASK)
	await _seconds(0.8)
	_check("mask on: the world is back", vision.amount == 0.0 and not vision.visible)

	var body: HumanBody = player.body
	for i in 20:
		if equipment.is_free(MASK):
			break
		var info := DamageInfo.new(10)
		var head := body.skeleton.find_bone("Head")
		info.position = body.skeleton.global_transform * body.skeleton.get_bone_global_pose(head) * Vector3(0, 0.12, -0.15)
		info.direction = Vector3.BACK
		health.apply_damage(info)
	await _frames(2)
	_check("the mask breaks off", equipment.is_free(MASK))
	await _seconds(0.8)
	_check("broken mask: the grain is fully in", vision.amount == 1.0 and vision.visible)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	var left := duration
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
