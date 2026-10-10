extends Node3D

const MONGER := preload("res://scenes/characters/mask_monger.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const MASK := preload("res://resources/items/shattered_mask.tres")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_slab(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	var monger: Npc = MONGER.instantiate()
	var player := PLAYER.instantiate()
	add_child(monger)
	add_child(player)
	monger.global_position = Vector3(0, 0.05, 0)
	player.global_position = Vector3(0, 0.05, -2.0)
	player.rotation.y = PI
	await _physics_frames(10)
	for i in 15:
		monger.health.apply_damage(DamageInfo.new(20))
	await _physics_frames(10)
	_check("a beating leaves him alive at full health", monger.health.is_alive()
		and monger.health.get_current() == monger.health.max_health)

	var dialogue := monger.get_node("%Dialogue") as Dialogue
	var interactor := player.get_node("%Interactor") as Interactor
	var equipment := player.get_node("%Equipment") as Equipment
	var inventory := player.get_node("%Inventory") as Inventory
	var prompts := player.get_node("%InteractionPrompts")
	var interact_prompt: Tooltip = prompts.get_node("Corner/Prompts/InteractPrompt")
	_check("the Monger has a Dialogue", dialogue != null)
	if dialogue == null:
		_finish()
		return
	_check("the player starts bare-faced", equipment.is_free(Equipment.Slot.MASK))
	_check("the Monger is under the crosshair", interactor.get_hovered() == monger)
	_check("offers \"Talk\"", dialogue.get_prompt(player) == "Talk")
	prompts.refresh()
	_check("the prompt reads E Talk", interact_prompt.visible
			and interact_prompt._action_label.text == "Talk")

	var shown: Array[String] = []
	dialogue.line_shown.connect(func(text: String) -> void: shown.append(text))
	interactor.interact(inventory)
	_check("E starts the talk", dialogue.is_talking() and shown.size() == 1)
	_check("the Brain is paused while talking", not monger.brain.is_physics_processing())
	_check("no Talk offered mid-talk", dialogue.get_prompt(player) == "")
	var first_count := dialogue.first_lines.size()
	_check("the first talk has 3 to 5 lines (%d)" % first_count,
			first_count >= 3 and first_count <= 5)
	for i in first_count:
		await _physics_frames(2)
		_press_interact()
		await _physics_frames(2)
		if dialogue.is_talking() and shown.size() == i + 1:
			_press_interact()
	await _physics_frames(2)
	var expected: Array[String] = []
	expected.assign(dialogue.first_lines)
	_check("every line was shown once, in order (%d)" % shown.size(), shown == expected)
	_check("the talk ended after the last line", not dialogue.is_talking())
	_check("the Brain is back", monger.brain.is_physics_processing())
	var worn := equipment.get_item(Equipment.Slot.MASK)
	_check("the player wears the gift", worn != null and worn == dialogue.gift)

	var items_before := inventory.get_entries().size()
	shown.clear()
	_check("Talk is offered again", dialogue.get_prompt(player) == "Talk")
	_check("the second talk starts", dialogue.use(player))
	_check("it says the repeat line", shown.size() == 1 and shown[0] == dialogue.repeat_lines[0])
	while dialogue.is_talking():
		dialogue.advance()
	_check("nothing more is given", inventory.get_entries().size() == items_before
			and equipment.get_item(Equipment.Slot.MASK) == worn)

	inventory.add(MASK)
	prompts.refresh()
	_check("a mask only in the inventory still offers Talk",
			interact_prompt._action_label.text == "Talk")

	var hand := player.get_node("%HandSlotRight") as HandSlot
	interactor.spawn_into_hand(MASK, -1, hand)
	prompts.refresh()
	_check("a mask in hand offers Give mask", interact_prompt._action_label.text == "Give shattered mask")
	interactor.interact(inventory)
	var ritual := monger.get_node("%Usable") as MaskBurnRitual
	_check("E with a mask in hand burns it, no talk",
			ritual.is_playing() and not dialogue.is_talking())
	_finish()


func _press_interact() -> void:
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _slab(size: Vector3, center: Vector3) -> void:
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	slab.add_child(shape)
	add_child(slab)


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
