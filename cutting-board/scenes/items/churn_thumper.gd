extends RigidBody3D

@export var ammo: ItemData = preload("res://resources/items/railroad_spike.tres")
@export var armed := false
@export var muzzle_speed := 32.0
@export var muzzle_lift := 0.03
@export var muzzle_distance := 0.7
@export var wear_per_shot := 6
@export var recoil_kick := deg_to_rad(5.0)
@export var recoil_push := 2.2
@export_group("Sounds")
@export var fire_sound: SoundBank = preload("res://resources/audio/thumper_fire.tres")
@export var dry_sound: SoundBank = preload("res://resources/audio/thumper_dry.tres")
@export var creak_sound: SoundBank = preload("res://resources/audio/thumper_creak.tres")
@export var latch_sound: SoundBank = preload("res://resources/audio/thumper_latch.tres")
@export_group("")

signal fired(spike: Node3D)
signal dry_fired
signal rearmed

const REARM_ACTION := &"rearm"

@onready var _usable: Usable = %Usable


func _ready() -> void:
	_usable.used.connect(_on_used)
	_usable.use_beat.connect(_on_use_beat)
	_sync_action()


func _on_used(by: Node) -> void:
	if armed:
		fire(by)
	else:
		armed = true
		Sfx.play(latch_sound, -2.0)
		rearmed.emit()
	_sync_action()


func _on_use_beat(beat_name: StringName, _by: Node) -> void:
	match beat_name:
		&"creak":
			Sfx.play(creak_sound, -3.0)
		&"latch":
			Sfx.play(latch_sound, -2.0)


func _sync_action() -> void:
	_usable.use_action = &"" if armed else REARM_ACTION
	_usable.held_verb = "Fire" if armed else "Rearm"


func fire(by: Node) -> Node3D:
	var inventory := by.get(&"inventory") as Inventory if by else null
	var entry := find_ammo(inventory)
	if entry == null:
		Sfx.play(dry_sound)
		dry_fired.emit()
		return null
	inventory.remove(entry)
	armed = false
	_sync_action()
	var spike := ammo.spawn()
	var aim := _aim_of(by)
	var forward := -aim.basis.z
	var world := get_tree().current_scene if get_tree().current_scene else get_tree().root
	world.add_child(spike)
	spike.global_position = aim.origin + forward * muzzle_distance
	if spike.has_method(&"launch"):
		spike.launch((forward + Vector3.UP * muzzle_lift) * muzzle_speed, by)
	Sfx.play(fire_sound)
	_recoil(by, forward)
	var destructible := get_node_or_null("Destructible") as Destructible
	if destructible:
		destructible.damage(wear_per_shot, true)
	fired.emit(spike)
	return spike


func find_ammo(inventory: Inventory) -> InventoryEntry:
	if inventory == null:
		return null
	for entry in inventory.get_entries():
		if entry.data == ammo:
			return entry
	return null


func _aim_of(by: Node) -> Transform3D:
	var camera := by.get(&"camera") as Camera3D if by else null
	if camera:
		return camera.global_transform
	return global_transform


func _recoil(by: Node, forward: Vector3) -> void:
	if by and by.has_method(&"recoil"):
		by.recoil(recoil_kick, -Vector3(forward.x, 0.0, forward.z).normalized() * recoil_push, self)
