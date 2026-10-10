extends Node

enum Cue { OUTSIDE, COMBAT }

const OUTSIDE := preload("res://assets/audio/music/outside.ogg")
const COMBAT := preload("res://assets/audio/music/combat.ogg")

@export var fade_time := 1.5
@export var combat_grace := 5.0
@export var volume_db := 0.0

var _outside: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _mix := 0.0
var _cue := Cue.OUTSIDE
var _calm_for := 0.0
var _trackers: Array[CombatTracker] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_outside = _make_player(OUTSIDE)
	_combat = _make_player(COMBAT)
	_apply_mix()
	_outside.play()
	get_tree().node_added.connect(_on_node_added)
	_hook_tree.call_deferred(get_tree().root)


func get_cue() -> Cue:
	return _cue


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
