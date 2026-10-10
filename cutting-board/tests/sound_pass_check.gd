extends Node3D

const PLAYER := preload("res://scenes/characters/player.tscn")
const CHAIR := preload("res://scenes/characters/walking_chair.tscn")
const ROCK := preload("res://resources/items/rock.tres")
const BARREL := preload("res://resources/items/barrel.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TestWorld.add_floor(self, 20)
	var player = TestWorld.masked_player(PLAYER)
	add_child(player)
	await _physics_frames(5)
	_pickups(player)
	player.queue_free()
	await _walking_chair()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _pickups(player) -> void:
	_check("a light item picks the plain pickup bank", player.pickup_sound_for(ROCK) == player.pickup_sound)
	_check("a mask picks the mask pickup bank", player.pickup_sound_for(VILLAGER_MASK) == player.pickup_mask_sound)
	_check("a heavy item picks the heavy pickup bank", player.pickup_sound_for(BARREL) == player.pickup_heavy_sound)
	for data: ItemData in [ROCK, VILLAGER_MASK, BARREL]:
		_stop_all()
		player.interactor.item_stowed.emit(data)
		var bank: SoundBank = player.pickup_sound_for(data)
		_check("stowing %s plays its pickup bank" % data.display_name, _playing(bank))


func _walking_chair() -> void:
	_stop_all()
	var chair: Node3D = CHAIR.instantiate()
	add_child(chair)
	var heard := false
	for frame in 90:
		chair.global_position += Vector3(0, 0, -0.02)
		await get_tree().process_frame
		heard = heard or _playing(chair.step_sound)
	_check("a walking chair's hands play its step bank", heard)


func _playing(bank: SoundBank) -> bool:
	for player in Sfx.get_children():
		if player.playing and bank.streams.has(player.stream):
			return true
	return false


func _stop_all() -> void:
	for player in Sfx.get_children():
		player.stop()


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1
