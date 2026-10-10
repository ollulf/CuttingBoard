extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const CHAIR := preload("res://scenes/characters/chair_creature.tscn")
const JUNK := [
	"finger_joint",
	"knee_hinge_pin",
	"sawdust_pouch",
	"lacquer_flakes",
	"splintered_dowel",
	"carved_eye_bead",
	"peg_teeth",
]
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
	_check_no_junk("villager", villager)
	_check_no_junk("bandit", bandit)
	_check_rates("chair", chair.pick_loot, CHAIR_JUNK)
	villager.free()
	bandit.free()
	chair.free()
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


func _check_no_junk(label: String, npc: Npc) -> void:
	var junk := {}
	for item_name in JUNK:
		junk[_load(item_name)] = true
	var carried := false
	for data in npc.extra_items:
		if junk.has(data):
			carried = true
	_report(not carried, "%s carries no puppet junk" % label)
	_report(npc.extra_items.size() == npc.extra_item_chances.size(),
		"%s extra item chances match items" % label)


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


func _report(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1
