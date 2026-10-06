extends Node3D

## Walks the player up to a villager and then to the Mask-Monger in the village, so the
## target bar names each in turn. Meant for Movie Maker:
##
##   godot --path cutting-board --write-movie out.avi --fixed-fps 30 --quit-after 240
##       res://tests/visual/npc_nameplate_capture.tscn

const VILLAGE := preload("res://scenes/levels/village.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
## Where the Monger stands in village.tscn (Market/MaskMonger).
const MONGER_POS := Vector3(2.6, 0.0, 8.4)
## Where the villager is put for the shot, out in the open.
const VILLAGER_POS := Vector3(0.4, 0.0, 4.2)
## (from, to, seconds, looked-at point) legs the player walks.
const LEGS := [
	[Vector3(1.6, 0.0, -3.0), Vector3(1.2, 0.0, 1.8), 2.5, VILLAGER_POS],
	[Vector3(1.2, 0.0, 1.8), Vector3(1.2, 0.0, 1.8), 1.0, VILLAGER_POS],
	[Vector3(1.2, 0.0, 1.8), Vector3(2.6, 0.0, 5.6), 2.5, MONGER_POS],
	[Vector3(2.6, 0.0, 5.6), Vector3(2.6, 0.0, 5.6), 2.0, MONGER_POS],
]

var _player: Node3D
var _time := 0.0
var _villager: CharacterBody3D
var _monger: CharacterBody3D


func _ready() -> void:
	var village := VILLAGE.instantiate()
	add_child(village)
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.set_process_input(false)
	await get_tree().process_frame
	var villagers := village.get_node("Villagers")
	for npc in get_tree().get_nodes_in_group(Faction.GROUP):
		if npc is Npc:
			npc.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var villager := villagers.get_child(0) as Node3D
	_villager = villager as CharacterBody3D
	_monger = village.find_child("MaskMonger", true, false) as CharacterBody3D
	# Everyone else steps well out of the way.
	for i in range(1, villagers.get_child_count()):
		(villagers.get_child(i) as Node3D).global_position += Vector3(40, 0, 40)


func _process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	# Pinned where they stand for the shot, facing the player.
	if _villager:
		_villager.global_position = VILLAGER_POS
		_villager.velocity = Vector3.ZERO
		_villager.look_at(_player.global_position, Vector3.UP, true)
	if _monger:
		_monger.global_position = MONGER_POS
		_monger.velocity = Vector3.ZERO
		_monger.look_at(_player.global_position, Vector3.UP, true)
	var t := _time
	for leg in LEGS:
		if t <= leg[2]:
			var at: Vector3 = (leg[0] as Vector3).lerp(leg[1], t / leg[2])
			_player.global_position = at
			var look: Vector3 = leg[3] - at
			_player.rotation.y = atan2(-look.x, -look.z)
			return
		t -= leg[2]
