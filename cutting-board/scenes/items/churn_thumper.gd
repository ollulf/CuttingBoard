extends RigidBody3D

## The Churn Thumper (concept G of docs/concepts/nail-gun.md): a butter churn laid on its
## side on a stock. Its dasher is hauled back against two strips of inner tube and
## latched; a click lets it go and the dasher slams one railroad spike out of the lid.
##
## Used from the hand, so a click never swings it (there is no melee with it):
## - armed, with a Railroad Spike in the holder's inventory: fires. One spike leaves the
##   bag and flies as the real item (railroad_spike.gd), the holder is kicked back, the
##   view jolts, and the Thumper is unarmed and worn by wear_per_shot.
## - armed, no spike: a dry click, nothing spent.
## - unarmed: rearms. The click plays the two-armed rearm (rearm_thumper_both, 1.35 s:
##   the free hand hauls the dasher back, the straps creak, the latch clicks) as a timed
##   use, so nothing else can be done meanwhile and moving off cancels it, still unarmed.
## A Thumper comes out of a bag unarmed, since the record keeps no state but wear.

## The ammunition it takes from the holder's inventory.
@export var ammo: ItemData = preload("res://resources/items/railroad_spike.tres")
## Whether the dasher is latched back, ready to fire.
@export var armed := false
## Speed the spike leaves the lid at, in metres per second; gravity does the rest.
@export var muzzle_speed := 32.0
## A little lift on the shot, as a fraction of muzzle speed, so it flies a short arc
## that comes back down onto the crosshair at a dozen metres rather than dropping under it.
@export var muzzle_lift := 0.03
## How far ahead of the eye the spike appears, clear of the holder's own capsule.
@export var muzzle_distance := 0.7
## Durability one shot costs the Thumper, on its Destructible's scale.
@export var wear_per_shot := 6
## The recoil: how far the view jolts up, in radians, and how hard the holder is pushed
## back, in metres per second.
@export var recoil_kick := deg_to_rad(5.0)
@export var recoil_push := 2.2
@export_group("Sounds")
@export var fire_sound: SoundBank = preload("res://resources/audio/thumper_fire.tres")
@export var dry_sound: SoundBank = preload("res://resources/audio/thumper_dry.tres")
@export var creak_sound: SoundBank = preload("res://resources/audio/thumper_creak.tres")
@export var latch_sound: SoundBank = preload("res://resources/audio/thumper_latch.tres")
@export_group("")

## A dry click, a shot or a rearm, with the outcome.
signal fired(spike: Node3D)
signal dry_fired
signal rearmed

const REARM_ACTION := &"rearm"

@onready var _usable: Usable = %Usable


func _ready() -> void:
	_usable.used.connect(_on_used)
	_usable.use_beat.connect(_on_use_beat)
	_sync_action()


## Fires when armed, rearms when not: the one thing a click does.
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


## An unarmed Thumper's click is the timed rearm; an armed one fires at once. The hand
## prompt reads the verb, so it says which.
func _sync_action() -> void:
	_usable.use_action = &"" if armed else REARM_ACTION
	_usable.held_verb = "Fire" if armed else "Rearm"


## Lets the dasher go for `by`. With no spike in their inventory it is a dry click and
## the Thumper stays armed. Returns the spike in flight, or null.
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


## The first Railroad Spike in `inventory`, or null.
func find_ammo(inventory: Inventory) -> InventoryEntry:
	if inventory == null:
		return null
	for entry in inventory.get_entries():
		if entry.data == ammo:
			return entry
	return null


## Where the shot comes from and points: the holder's eye, else the Thumper's own lid.
func _aim_of(by: Node) -> Transform3D:
	var camera := by.get(&"camera") as Camera3D if by else null
	if camera:
		return camera.global_transform
	return global_transform


## The kick: the holder's arm jerks, the view jolts up and the body is shoved back.
func _recoil(by: Node, forward: Vector3) -> void:
	if by and by.has_method(&"recoil"):
		by.recoil(recoil_kick, -Vector3(forward.x, 0.0, forward.z).normalized() * recoil_push, self)
