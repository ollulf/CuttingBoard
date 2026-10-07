extends Node3D

## Headless checks for the puppet junk dead puppets carry: every junk item loads with a
## name, an icon and a world scene that shows its mesh and points back at it; villagers,
## bandits and walking chairs roll each of their junk at about its configured rate; and a
## villager given every junk for certain really ends up with all of it in its inventory.
## Prints PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/puppet_junk_loot_check.tscn

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const CHAIR := preload("res://scenes/characters/chair_creature.tscn")
## Item file name -> expected drop chance on villagers and bandits.
const JUNK := {
	"finger_joint": 0.35,
	"knee_hinge_pin": 0.15,
	"sawdust_pouch": 0.35,
	"lacquer_flakes": 0.15,
	"splintered_dowel": 0.35,
	"carved_eye_bead": 0.05,
	"peg_teeth": 0.15,
}
## Walking chairs only carry the wooden bits a chair is made of.
const CHAIR_JUNK := {
	"splintered_dowel": 0.35,
	"finger_joint": 0.2,
	"peg_teeth": 0.15,
}
const ROLLS := 2000

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(4242)
	for item_name in JUNK:
		_check_item(item_name)
	var villager: Npc = VILLAGER.instantiate()
	var bandit: Npc = BANDIT.instantiate()
	var chair := CHAIR.instantiate()
	_check_rates("villager", villager.pick_extra_items, JUNK)
	_check_rates("bandit", bandit.pick_extra_items, JUNK)
	_check_rates("chair", chair.pick_loot, CHAIR_JUNK)
	villager.free()
	bandit.free()
	chair.free()
	await _check_spawn_all()
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _load(item_name: String) -> ItemData:
	return load("res://resources/items/%s.tres" % item_name) as ItemData


func _check_item(item_name: String) -> void:
	var data := _load(item_name)
	if data == null:
		_report(false, "%s loads" % item_name)
		return
	_report(not data.display_name.is_empty() and data.icon != null,
		"%s has a name (%s) and an icon" % [item_name, data.display_name])
	var node := data.spawn()
	if node == null:
		_report(false, "%s spawns a world scene" % item_name)
		return
	var mesh_node := node.find_child("MeshInstance3D") as MeshInstance3D
	_report(mesh_node != null and mesh_node.mesh != null
		and mesh_node.mesh.resource_path.contains("junk_"),
		"%s world scene shows a junk mesh" % item_name)
	var carryable := node.find_child("Carryable")
	_report(carryable != null and carryable.item_data == data,
		"%s world scene picks up as itself" % item_name)
	node.free()


func _check_rates(label: String, roll: Callable, expected: Dictionary) -> void:
	var hits := {}
	for item_name in expected:
		hits[item_name] = 0
	var items := {}
	for item_name in expected:
		items[_load(item_name)] = item_name
	for i in ROLLS:
		for data in roll.call():
			if items.has(data):
				hits[items[data]] += 1
	for item_name in expected:
		var rate := float(hits[item_name]) / ROLLS
		_report(absf(rate - expected[item_name]) <= 0.04,
			"%s %s rate %.3f (expected %.2f)" % [label, item_name, rate, expected[item_name]])


## Spawns a villager that carries every junk for certain and checks its inventory.
func _check_spawn_all() -> void:
	var npc: Npc = VILLAGER.instantiate()
	var chances: Array[float] = [0.0]
	for i in JUNK.size():
		chances.append(1.0)
	npc.extra_item_chances = chances
	add_child(npc)
	await get_tree().process_frame
	await get_tree().process_frame
	var held := {}
	for entry in npc.inventory.get_entries():
		held[entry.data] = true
	for item_name in JUNK:
		_report(held.has(_load(item_name)), "spawned villager carries %s" % item_name)
	npc.queue_free()
	await get_tree().process_frame


func _report(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1
