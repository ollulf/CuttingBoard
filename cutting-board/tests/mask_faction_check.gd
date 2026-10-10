extends Node3D

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const BANDIT_MASK := preload("res://resources/items/bandit_mask.tres")
const VILLAGER_MASK := preload("res://resources/items/villager_mask.tres")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")

var _failures := 0
var _player: Node3D
var _equipment: Equipment
var _faction: Faction


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)

	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector3(0, 0.05, 0)
	_equipment = _player.get_node("%Equipment")
	_faction = Faction.find_in(_player)
	var health: Health = _player.get_node("%Health")
	health.max_health = 100000
	health.reset()

	var bandit := _spawn(BANDIT, Vector3(0, 0.05, -4))
	var villager := _spawn(VILLAGER, Vector3(4, 0.05, 0))
	await _physics_frames(5)
	bandit.brain.shut_down()
	villager.brain.shut_down()
	bandit.memory.remember(_player)
	villager.memory.remember(_player)

	_check("starting mask: player faction", _faction.data.id == &"player")
	_check("starting mask: bandit targets the player", bandit.get_attack_target() == _player)
	_check("starting mask: villager leaves the player be", not villager.faction.is_hostile_to(_player))

	_wear(BANDIT_MASK)
	_check("bandit mask: bandit faction", _faction.data.id == &"bandits")
	_check("bandit mask: the bandit drops the player", bandit.get_attack_target() != _player)
	_check("bandit mask: bandit sees no enemy in the player", not bandit.faction.is_hostile_to(_player))
	_check("bandit mask: villager takes the player for an enemy", villager.faction.is_hostile_to(_player))

	_wear(VILLAGER_MASK)
	_check("villager mask: villagers faction", _faction.data.id == &"villagers")
	_check("villager mask: bandit takes the player for an enemy", bandit.faction.is_hostile_to(_player))
	_check("villager mask: villager leaves the player be", not villager.faction.is_hostile_to(_player))

	_equipment.unequip(Equipment.Slot.MASK)
	_check("bare face: back to the player faction", _faction.data == _faction.own_data and _faction.data.id == &"player")
	_check("bare face: bandit targets the player", bandit.get_attack_target() == _player)
	_check("bare face: villager leaves the player be", not villager.faction.is_hostile_to(_player))

	_wear(PLAYER_MASK)
	_check("own mask: player faction", _faction.data.id == &"player")

	_wear(BANDIT_MASK)
	var body: HumanBody = _player.get_node("%Body")
	body.mask_broken.emit()
	_check("broken bandit mask: slot empty", _equipment.is_free(Equipment.Slot.MASK))
	_check("broken bandit mask: player faction again", _faction.data.id == &"player")

	_wear(BANDIT_MASK)
	bandit.health.apply_damage(DamageInfo.new(5, _player))
	_check("grudge: bandit holds it", bandit.has_grudge_against(_player))
	_check("grudge: bandit targets the masked player anyway", bandit.get_attack_target() == _player)
	_wear(VILLAGER_MASK)
	villager.health.apply_damage(DamageInfo.new(5, _player))
	_check("grudge: villager targets the villager-masked player", villager.get_attack_target() == _player)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _wear(mask: MaskData) -> void:
	_equipment.unequip(Equipment.Slot.MASK)
	_equipment.equip(Equipment.Slot.MASK, mask)


func _spawn(scene: PackedScene, at: Vector3) -> Npc:
	var npc := scene.instantiate() as Npc
	npc.position = at
	add_child(npc)
	return npc


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
