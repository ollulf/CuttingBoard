class_name WatchAction
extends NpcAction

@export var watch_score := 0.85
@export var bark_at: Array[float] = [0.0, 0.4, 0.8]
@export var barks: Array[StringName] = [&"hm", &"mutter", &"hey"]
@export var draw_at := 0.4

var _next_bark := 0
var _search_look := 0.0


func score(npc: Npc) -> float:
	if npc.alertness and npc.alertness.is_busy():
		return watch_score
	return 0.0


func enter(npc: Npc) -> void:
	_next_bark = 0
	_search_look = 0.0
	npc.locomotion.stop()


func exit(npc: Npc) -> void:
	npc.locomotion.stop()
	npc.locomotion.clear_facing()


func tick(npc: Npc, delta: float) -> void:
	var alertness := npc.alertness
	match alertness.state:
		Alertness.State.WATCHING:
			npc.locomotion.stop()
			npc.locomotion.face(alertness.last_seen_position)
			var fraction := alertness.meter / alertness.watch_time
			if _next_bark < mini(bark_at.size(), barks.size()) and fraction >= bark_at[_next_bark]:
				npc.bark(barks[_next_bark])
				_next_bark += 1
			if fraction >= draw_at and npc.holster:
				npc.holster.draw_now()
		Alertness.State.CALLING:
			npc.locomotion.stop()
			npc.locomotion.face(alertness.last_seen_position)
		Alertness.State.SEARCHING:
			_next_bark = 0
			if npc.flat_distance_to(alertness.last_seen_position) > npc.locomotion.arrive_distance:
				npc.locomotion.clear_facing()
				npc.locomotion.move_to(alertness.last_seen_position)
				return
			npc.locomotion.stop()
			_search_look -= delta
			if _search_look <= 0.0:
				_search_look = 1.2
				var around := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
				npc.locomotion.face(npc.global_position + around.normalized() * 3.0)
