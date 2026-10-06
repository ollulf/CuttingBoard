extends Node3D

## Headless checks for the random extra items NPCs get at spawn: villagers and bandits
## roll wood glue at about their configured rate, a chance of 0 never gives the item and
## 1 always does, and a spawned NPC really ends up with it in its inventory. Prints
## PASS/FAIL per check and quits with the number of failures as the exit code.
##
##   godot --headless --path cutting-board res://tests/npc_extra_items_check.tscn

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const GLUE := preload("res://resources/items/wood_glue.tres")
const ROLLS := 1000

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(12345)
	var villager: Npc = VILLAGER.instantiate()
	var bandit: Npc = BANDIT.instantiate()
	_check_rate(villager, "villager", 0.3)
	_check_rate(bandit, "bandit", 0.2)
	villager.extra_item_chances = [0.0]
	_check_rate(villager, "chance 0", 0.0, 0.0)
	villager.extra_item_chances = [1.0]
	_check_rate(villager, "chance 1", 1.0, 0.0)
	villager.extra_item_chances = []
	_check_rate(villager, "missing chance", 0.0, 0.0)
	villager.free()
	bandit.free()
	await _check_spawn(1.0, true)
	await _check_spawn(0.0, false)
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check_rate(npc: Npc, label: String, expected: float, tolerance := 0.05) -> void:
	var hits := 0
	for i in ROLLS:
		if npc.pick_extra_items().has(GLUE):
			hits += 1
	var rate := float(hits) / ROLLS
	_report(absf(rate - expected) <= tolerance,
		"%s glue rate %.3f (expected %.2f)" % [label, rate, expected])


## Spawns a villager with the given glue chance and checks what its inventory holds.
func _check_spawn(chance: float, expect_glue: bool) -> void:
	var npc: Npc = VILLAGER.instantiate()
	npc.extra_item_chances = [chance]
	add_child(npc)
	await get_tree().process_frame
	await get_tree().process_frame
	var has_glue := false
	for entry in npc.inventory.get_entries():
		if entry.data == GLUE:
			has_glue = true
	_report(has_glue == expect_glue,
		"spawned villager with chance %.0f has glue: %s" % [chance, has_glue])
	npc.queue_free()
	await get_tree().process_frame


func _report(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1
