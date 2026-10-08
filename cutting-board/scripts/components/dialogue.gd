class_name Dialogue
extends Usable

## Lets the player talk to an NPC: E offers "Talk" under the crosshair and a speech plank
## shows the lines one by one (E or a click goes on). The first slice of
## docs/concepts/dialogue-system.md: a plain line list instead of a `.dlg` file, no
## choices, one speaker.
##
## Sits on the NPC beside its own Usable (the Mask-Monger's burn ritual), which comes
## first: the Interactor and the prompts only fall back to talking when that Usable has
## nothing to offer. The first talk says `first_lines` and ends by giving `gift`, worn
## straight away when it is something worn and its slot is free, else put in the
## inventory. Every later talk says `repeat_lines` and gives nothing.
##
## An everyday NPC (a villager, a bandit) has `one_liners` instead: each talk is one line
## drawn from them, and it only talks while friendly to the listener: not of a side
## hostile to the listener's (a bandit mask makes bandits take you for one of theirs), no
## grudge against them, not fighting.

signal talk_started(by: Node)
signal line_shown(text: String)
signal talk_ended

## The name on the plank. Empty uses the NPC's own name.
@export var speaker_name := ""
@export_multiline var first_lines: PackedStringArray = []
@export_multiline var repeat_lines: PackedStringArray = []
## Handed over at the end of the first talk; null for none.
@export var gift: ItemData
## When set, every talk says one of these, never the same twice running, and only to a
## friendly listener; first_lines, repeat_lines and gift are left unused.
@export_multiline var one_liners: PackedStringArray = []
## The voice blips played while a line types out.
@export var voice: SoundBank
## How far this NPC's voice may sit above or below the bank's pitch, as a fraction; drawn
## once per NPC, so a village sharing one voice bank does not all sound alike.
@export_range(0.0, 0.3, 0.01) var voice_pitch_spread := 0.0
## Metres the listener may walk away before the talk breaks off.
@export var talk_range := 5.0

## Player.ControlMode.LOOK_ONLY (the player script has no class_name).
const CONTROL_LOOK_ONLY := 1

var talked := false
## This NPC's own pitch scale on top of the voice bank's, drawn from voice_pitch_spread.
var voice_pitch := 1.0
var _lines: PackedStringArray = []
var _index := -1
var _listener: Node3D
var _plank: SpeechPlank
var _listener_control := 0
## Index into one_liners of the line said last, so the next talk says another.
var _last_one_liner := -1

@onready var _npc: Npc = get_parent() as Npc


func _ready() -> void:
	can_use = _can_talk
	# Its own generator, so drawing the pitch leaves the global random sequence (which
	# seeded tests replay) untouched.
	var rng := RandomNumberGenerator.new()
	voice_pitch = 1.0 + rng.randf_range(-voice_pitch_spread, voice_pitch_spread)
	used.connect(_on_used)
	set_physics_process(false)


func get_prompt(by: Node) -> String:
	return "Talk" if _can_talk(by) else ""


func is_talking() -> bool:
	return _index >= 0


func current_line() -> String:
	return _lines[_index] if is_talking() else ""


func _can_talk(by: Node) -> bool:
	if is_talking() or by == null:
		return false
	if _npc:
		var health := Health.find_in(_npc)
		if health and not health.is_alive():
			return false
		if _npc.has_grudge_against(by as Node3D):
			return false
	if not one_liners.is_empty():
		return _is_friendly_to(by)
	var lines := repeat_lines if talked else first_lines
	return not lines.is_empty()


func _on_used(by: Node) -> void:
	_listener = by as Node3D
	if one_liners.is_empty():
		_lines = repeat_lines if talked else first_lines
	else:
		_lines = PackedStringArray([_pick_one_liner()])
	_index = 0
	if _npc:
		_npc.brain.set_physics_process(false)
		_npc.locomotion.stop()
		if _listener:
			_npc.locomotion.face(_listener.global_position)
	if "control" in by:
		_listener_control = by.control
		by.control = CONTROL_LOOK_ONLY
	_plank = SpeechPlank.new()
	_plank.dialogue = self
	add_child(_plank)
	set_physics_process(true)
	talk_started.emit(by)
	_show_line()
	get_tree().call_group(&"interaction_prompts", &"refresh")


## Goes on to the next line, or ends the talk after the last one.
func advance() -> void:
	if not is_talking():
		return
	_index += 1
	if _index >= _lines.size():
		_end(true)
	else:
		_show_line()


func _show_line() -> void:
	_plank.show_line(_speaker(), _lines[_index], voice, voice_pitch)
	line_shown.emit(_lines[_index])


func _physics_process(_delta: float) -> void:
	# Not on an Npc (the Carver talks from his stump's body): measure from the parent.
	var anchor := _npc if _npc else get_parent() as Node3D
	if not is_instance_valid(_listener) or (anchor
			and _listener.global_position.distance_to(anchor.global_position) > talk_range):
		_end(false)


## `heard_out`: the listener stayed to the last line, so the first talk counts and the
## gift is handed over.
func _end(heard_out: bool) -> void:
	var by := _listener
	_index = -1
	set_physics_process(false)
	if is_instance_valid(_plank):
		_plank.queue_free()
	_plank = null
	if is_instance_valid(by) and "control" in by:
		by.control = _listener_control
	if _npc:
		_npc.locomotion.clear_facing()
		_npc.brain.set_physics_process(true)
	if heard_out and not talked and one_liners.is_empty():
		talked = true
		_give(by)
	_listener = null
	talk_ended.emit()
	get_tree().call_group(&"interaction_prompts", &"refresh")


## speaker_name, or failing that the NPC's own name (the one drawn from its name_pool).
func _speaker() -> String:
	if not speaker_name.is_empty() or _npc == null:
		return speaker_name
	return _npc.inventory.get_display_name()


## Friendly enough for small talk: its side is not hostile to the listener's (which
## follows the listener's mask) and it is not in a fight or holding a grudge.
func _is_friendly_to(by: Node) -> bool:
	var own: Faction = _npc.faction if _npc else Faction.find_in(get_parent())
	if own and own.is_hostile_to(by):
		return false
	return _npc == null or not _npc.is_in_combat()


## A line from one_liners other than the one said last time, when there is another.
func _pick_one_liner() -> String:
	var index := randi() % one_liners.size()
	if one_liners.size() > 1 and index == _last_one_liner:
		index = (index + 1 + randi() % (one_liners.size() - 1)) % one_liners.size()
	_last_one_liner = index
	return one_liners[index]


## Puts the gift on when it is worn and the slot is free (a first mask lifts the grain),
## otherwise into the inventory.
func _give(by: Node) -> void:
	if gift == null or not is_instance_valid(by):
		return
	var equipment := by.get_node_or_null("%Equipment") as Equipment
	var slot := Equipment.slot_for(gift)
	if equipment and slot != Equipment.NO_SLOT and equipment.equip(slot, gift):
		return
	var inventory := by.get_node_or_null("%Inventory") as Inventory
	if inventory:
		inventory.add(gift)


static func find_dialogue_in(node: Node) -> Dialogue:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Dialogue") as Dialogue
