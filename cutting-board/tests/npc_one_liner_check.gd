extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")
const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")
const MONGER_VOICE := preload("res://resources/audio/monger_voice.tres")

var _failures := 0
var _player: Node3D
var _equipment: Equipment
var _interactor: Interactor
var _interact_prompt: Tooltip


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(5)
	_slab(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(0, 0.05, -2.0)
	_player.rotation.y = PI
	var health := _player.get_node("%Health") as Health
	health.max_health = 100000
	health.reset()
	_equipment = _player.get_node("%Equipment")
	_interactor = _player.get_node("%Interactor")
	_interact_prompt = _player.get_node("%InteractionPrompts").get_node(
			"Corner/Prompts/InteractPrompt")
	await _physics_frames(5)

	await _villager()
	await _bandit()
	await _voices()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _villager() -> void:
	_equipment.unequip(Equipment.Slot.MASK)
	var villager := _spawn(VILLAGER)
	await _physics_frames(10)
	var dialogue := villager.get_node("%Dialogue") as Dialogue
	_check("the villager has a Dialogue with 8+ one-liners",
			dialogue != null and dialogue.one_liners.size() >= 8)
	_check("the villager is under the crosshair", _interactor.get_hovered() == villager)
	_check("offers Talk to a bare face", dialogue.get_prompt(_player) == "Talk")
	_check("the prompt reads E Talk", _interact_prompt.visible
			and _interact_prompt._action_label.text == "Talk")

	var shown: Array[String] = []
	dialogue.line_shown.connect(func(text: String) -> void: shown.append(text))
	_interactor.interact(_player.get_node("%Inventory"))
	_check("E starts a talk with one line from the pool", dialogue.is_talking()
			and shown.size() == 1 and shown[0] in dialogue.one_liners)
	_check("the Brain is paused while talking", not villager.brain.is_physics_processing())
	dialogue.advance()
	_check("one line and the talk is over", not dialogue.is_talking() and shown.size() == 1)
	_check("the Brain is back", villager.brain.is_physics_processing())

	var repeats := 0
	for i in 30:
		dialogue.use(_player)
		dialogue.advance()
		if shown[-1] == shown[-2]:
			repeats += 1
	_check("never the same line twice running (%d repeats)" % repeats,
			repeats == 0 and shown.size() == 31)
	_check("the plank shows the villager's own name",
			dialogue._speaker() == villager.inventory.get_display_name())

	_equipment.equip(Equipment.Slot.MASK, VILLAGER_MASK)
	await _physics_frames(2)
	_check("offers Talk to a villager mask", dialogue.get_prompt(_player) == "Talk")

	_equipment.unequip(Equipment.Slot.MASK)
	_equipment.equip(Equipment.Slot.MASK, BANDIT_MASK)
	await _physics_frames(2)
	_check("no Talk to a bandit mask", dialogue.get_prompt(_player) == ""
			and not _interact_prompt.visible)
	_equipment.unequip(Equipment.Slot.MASK)
	await _physics_frames(2)

	villager.health.apply_damage(DamageInfo.new(5, _player))
	await _physics_frames(2)
	_check("no Talk after hitting it", dialogue.get_prompt(_player) == ""
			and not _interact_prompt.visible)
	villager.queue_free()
	await _physics_frames(2)


func _bandit() -> void:
	_equipment.unequip(Equipment.Slot.MASK)
	var bandit := _spawn(BANDIT)
	await _physics_frames(10)
	var dialogue := bandit.get_node("%Dialogue") as Dialogue
	_check("the bandit has a Dialogue with 8+ one-liners",
			dialogue != null and dialogue.one_liners.size() >= 8)
	_check("no Talk to a bare face", dialogue.get_prompt(_player) == ""
			and not _interact_prompt.visible)
	_equipment.equip(Equipment.Slot.MASK, VILLAGER_MASK)
	await _physics_frames(2)
	_check("no Talk to a villager mask", dialogue.get_prompt(_player) == "")
	_equipment.unequip(Equipment.Slot.MASK)
	_equipment.equip(Equipment.Slot.MASK, BANDIT_MASK)
	await _physics_frames(30)
	bandit.global_position = Vector3(0, 0.05, 0)
	bandit.locomotion.stop()
	await _physics_frames(3)
	_check("Talk to a bandit mask", dialogue.get_prompt(_player) == "Talk"
			and _interact_prompt.visible and _interact_prompt._action_label.text == "Talk")
	_check("and it talks", dialogue.use(_player)
			and dialogue.current_line() in dialogue.one_liners)
	dialogue.advance()
	_equipment.unequip(Equipment.Slot.MASK)
	await _physics_frames(2)
	_check("the mask off, Talk is gone again", dialogue.get_prompt(_player) == "")


func _voices() -> void:
	var villager := _spawn(VILLAGER)
	var bandit := _spawn(BANDIT)
	var other := _spawn(VILLAGER)
	await _physics_frames(2)
	var villager_voice := (villager.get_node("%Dialogue") as Dialogue).voice
	var bandit_voice := (bandit.get_node("%Dialogue") as Dialogue).voice
	var monger_streams: Array[AudioStream] = MONGER_VOICE.streams
	_check("villager and bandit have voice banks of their own", villager_voice != null
			and bandit_voice != null and villager_voice != bandit_voice
			and villager_voice != MONGER_VOICE and bandit_voice != MONGER_VOICE)
	var shared := 0
	for stream in villager_voice.streams + bandit_voice.streams:
		if stream in monger_streams:
			shared += 1
	for stream in villager_voice.streams:
		if stream in bandit_voice.streams:
			shared += 1
	_check("their blips are their own (%d shared takes)" % shared, shared == 0
			and villager_voice.streams.size() >= 4 and bandit_voice.streams.size() >= 4)
	var pitches: Array[float] = []
	var labels := ["a villager", "the bandit", "another villager"]
	for i in 3:
		var npc: Npc = [villager, bandit, other][i]
		var dialogue := npc.get_node("%Dialogue") as Dialogue
		pitches.append(dialogue.voice_pitch)
		_check("%s voice pitch %.3f within its spread" % [labels[i], dialogue.voice_pitch],
				dialogue.voice_pitch_spread > 0.0
				and absf(dialogue.voice_pitch - 1.0) <= dialogue.voice_pitch_spread)
	_check("two villagers differ in pitch", pitches[0] != pitches[2])
	for npc in [villager, bandit, other]:
		npc.queue_free()
	await _physics_frames(2)


func _spawn(scene: PackedScene) -> Npc:
	var npc: Npc = scene.instantiate()
	add_child(npc)
	npc.global_position = Vector3(0, 0.05, 0)
	return npc


func _slab(size: Vector3, center: Vector3) -> void:
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	slab.add_child(shape)
	add_child(slab)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
