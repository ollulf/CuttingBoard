extends Node

## Plays the game's music, autoloaded as Music: the Outside cue by default, crossfading to
## the Combat cue while an NPC is going for the player.
##
## Like DamageNumbers, nothing has to opt in: every CombatTracker is hooked as it enters
## the tree, and its targeted_changed says when some NPC — villager, bandit, a rock
## thrower — is chasing or throwing at its owner. Once no NPC has done so for
## `combat_grace` seconds the music fades back to Outside, so a fight that pauses for a
## breath does not flap between the two. A dead NPC or one whose grudge has run out no
## longer goes for anyone, so it drops out on its own.
##
## Both cues are seamless loops (loop=true in their .import) on the Music bus, which
## carries no effects: the cues are mixed with their own hall and should not be dulled.

enum Cue { OUTSIDE, COMBAT }

const OUTSIDE := preload("res://assets/audio/music/outside.ogg")
const COMBAT := preload("res://assets/audio/music/combat.ogg")

## Seconds a crossfade between the cues takes.
@export var fade_time := 1.5
## Seconds after the last NPC stopped going for the player before Combat fades out.
@export var combat_grace := 5.0
## Level of both cues on the Music bus.
@export var volume_db := 0.0

var _outside: AudioStreamPlayer
var _combat: AudioStreamPlayer
## 0 is all Outside, 1 is all Combat; eased towards the current cue every frame.
var _mix := 0.0
var _cue := Cue.OUTSIDE
## Seconds since no tracker reported an NPC going for its owner, while in Combat.
var _calm_for := 0.0
var _trackers: Array[CombatTracker] = []


func _ready() -> void:
	# The music goes on while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_outside = _make_player(OUTSIDE)
	_combat = _make_player(COMBAT)
	_apply_mix()
	_outside.play()
	get_tree().node_added.connect(_on_node_added)
	_hook_tree.call_deferred(get_tree().root)


func get_cue() -> Cue:
	return _cue


## How far the crossfade has got: 0 all Outside, 1 all Combat.
func get_mix() -> float:
	return _mix


func _process(delta: float) -> void:
	if _cue == Cue.COMBAT and not _is_targeted():
		_calm_for += delta
		if _calm_for >= combat_grace:
			_set_cue(Cue.OUTSIDE)
	var goal := 1.0 if _cue == Cue.COMBAT else 0.0
	if _mix != goal:
		_mix = move_toward(_mix, goal, delta / maxf(fade_time, 0.001))
		_apply_mix()


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	add_child(player)
	return player


## Equal-power crossfade; a cue faded right out is paused, so Outside picks up where it
## left off after a fight.
func _apply_mix() -> void:
	var outside_gain := cos(_mix * PI * 0.5)
	var combat_gain := sin(_mix * PI * 0.5)
	_outside.volume_db = linear_to_db(maxf(outside_gain, 0.0001)) + volume_db
	_combat.volume_db = linear_to_db(maxf(combat_gain, 0.0001)) + volume_db
	_outside.stream_paused = _mix >= 1.0
	_combat.stream_paused = _mix <= 0.0


func _set_cue(cue: Cue) -> void:
	_calm_for = 0.0
	if cue == _cue:
		return
	_cue = cue
	# Every fight starts at the top of the Combat loop, on its lean first section.
	if cue == Cue.COMBAT:
		_combat.stream_paused = false
		_combat.play()
	elif not _outside.playing:
		_outside.play()


func _is_targeted() -> bool:
	for tracker in _trackers:
		if is_instance_valid(tracker) and tracker.is_targeted():
			return true
	return false


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	var tracker := node as CombatTracker
	if tracker == null or _trackers.has(tracker):
		return
	_trackers.append(tracker)
	if not tracker.targeted_changed.is_connected(_on_targeted_changed):
		tracker.targeted_changed.connect(_on_targeted_changed)
		tracker.tree_exiting.connect(_on_tracker_exiting.bind(tracker))


func _on_tracker_exiting(tracker: CombatTracker) -> void:
	_trackers.erase(tracker)


func _on_targeted_changed(targeted: bool) -> void:
	if targeted:
		_set_cue(Cue.COMBAT)
