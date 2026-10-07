extends Node3D

## Headless checks for the Mask-Monger's burn ritual (scenes/characters/mask_burn_ritual.gd):
## nothing is offered without a mask; a mask in hand is taken, burnt and comes back as
## exactly one Soul in a Bottle pickup at the player's feet; a second offer mid-ritual is
## refused; a mask only in the inventory is neither offered nor taken; and a Monger
## holding a grudge refuses. Prints PASS/FAIL per check and quits with the number of
## failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/monger_burn_ritual_check.tscn

const MONGER := preload("res://scenes/characters/mask_monger.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const MASK := preload("res://resources/items/villager_mask.tres")
const BOTTLE := preload("res://resources/items/soul_bottle.tres")

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
	await _physics_frames(10)

	var ritual := monger.get_node("%Usable") as MaskBurnRitual
	var interactor := player.get_node("%Interactor") as Interactor
	var hand := player.get_node("%HandSlotRight") as HandSlot
	var inventory := player.get_node("%Inventory") as Inventory
	_check("the Monger has the ritual as its Usable", ritual != null)
	if ritual == null:
		_finish()
		return

	_check("nothing offered without a mask", ritual.get_prompt(player) == "")
	_check("refused without a mask", not ritual.use(player))

	# A mask in hand.
	var cues: Array[float] = []
	var cue_times: Array[float] = []
	ritual.sound_cued.connect(func(_bank: SoundBank, at: float) -> void:
		cues.append(at)
		cue_times.append(ritual._time))
	interactor.spawn_into_hand(MASK, -1, hand)
	_check("offers \"Give mask\" with a mask in hand", ritual.get_prompt(player) == "Give mask")
	_check("takes the mask", ritual.use(player))
	_check("the hand is empty", hand.is_free())
	_check("the ritual is playing", ritual.is_playing())
	_check("the Brain is paused", not monger.brain.is_physics_processing())
	inventory.add(MASK)
	_check("refused mid-ritual", not ritual.use(player) and _masks_in(inventory) == 1)
	await _until_done(ritual)
	_check("the ritual finishes", not ritual.is_playing())
	_check("the Brain is back", monger.brain.is_physics_processing())
	var on_beat := cues.size() == 9
	for i in cues.size():
		on_beat = on_beat and cue_times[i] - cues[i] < 0.1
	_check("each beat's sound fires once, on its beat (%d)" % cues.size(), on_beat)
	await _physics_frames(60)
	var bottles := _bottles()
	_check("exactly one soul bottle", bottles.size() == 1)
	if bottles.size() == 1:
		var bottle := bottles[0]
		var off := Vector2(bottle.global_position.x - player.global_position.x,
				bottle.global_position.z - player.global_position.z).length()
		print("  bottle %.2f m from the player, frozen %s" % [off, bottle.freeze])
		_check("the bottle is a loose pickup near the player", not bottle.freeze and off < 1.5)

	# A mask only in the inventory, hands empty: neither offered nor taken.
	_check("no \"Give mask\" for a mask only in the inventory",
			ritual.get_prompt(player) == "")
	_check("refuses a mask only in the inventory", not ritual.use(player)
			and _masks_in(inventory) == 1)

	# A grudge, mask in hand.
	interactor.spawn_into_hand(MASK, -1, hand)
	_check("a mask in hand is offered again", ritual.get_prompt(player) == "Give mask")
	monger.hold_grudge(player)
	_check("refused while it holds a grudge", ritual.get_prompt(player) == ""
			and not ritual.use(player) and not hand.is_free())
	_finish()


func _until_done(ritual: MaskBurnRitual) -> void:
	var waited := 0
	while ritual.is_playing() and waited < 900:
		await get_tree().process_frame
		waited += 1


func _masks_in(inventory: Inventory) -> int:
	var count := 0
	for entry in inventory.get_entries():
		if entry.data is MaskData:
			count += 1
	return count


func _bottles() -> Array[RigidBody3D]:
	var found: Array[RigidBody3D] = []
	for node in find_children("*", "RigidBody3D", true, false):
		var carryable := node.get_node_or_null("Carryable") as Carryable
		if carryable and carryable.item_data == BOTTLE:
			found.append(node)
	return found


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
