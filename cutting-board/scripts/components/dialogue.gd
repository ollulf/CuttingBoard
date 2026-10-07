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

signal talk_started(by: Node)
signal line_shown(text: String)
signal talk_ended

## The name on the plank.
@export var speaker_name := ""
@export_multiline var first_lines: PackedStringArray = []
@export_multiline var repeat_lines: PackedStringArray = []
## Handed over at the end of the first talk; null for none.
@export var gift: ItemData
## The voice blips played while a line types out.
@export var voice: SoundBank
## Metres the listener may walk away before the talk breaks off.
@export var talk_range := 5.0

## Player.ControlMode.LOOK_ONLY (the player script has no class_name).
const CONTROL_LOOK_ONLY := 1

var talked := false
var _lines: PackedStringArray = []
var _index := -1
var _listener: Node3D
var _plank: SpeechPlank
var _listener_control := 0

@onready var _npc: Npc = get_parent() as Npc


func _ready() -> void:
	can_use = _can_talk
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
	var lines := repeat_lines if talked else first_lines
	return not lines.is_empty()


func _on_used(by: Node) -> void:
	_listener = by as Node3D
	_lines = repeat_lines if talked else first_lines
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
	_plank.show_line(speaker_name, _lines[_index], voice)
	line_shown.emit(_lines[_index])


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_listener) or (_npc
			and _listener.global_position.distance_to(_npc.global_position) > talk_range):
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
	if heard_out and not talked:
		talked = true
		_give(by)
	_listener = null
	talk_ended.emit()
	get_tree().call_group(&"interaction_prompts", &"refresh")


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
