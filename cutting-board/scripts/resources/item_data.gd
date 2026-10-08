class_name ItemData
extends Resource

## Data record stored by the inventory; the world Node3D is freed once picked up.

## What kind of item this is. Equipment slots use it to decide what they will accept;
## MISC is the default so an item is only a weapon when it says so. The last four are
## things worn on the body, and each fits exactly one slot of the player's Equipment.
## New kinds go on the end: the type is saved as its number, so inserting one would
## quietly turn every authored item into something else.
enum Type { MISC, WEAPON, MASK, HEAD, BODY, PACK }

@export var display_name: String
@export var icon: Texture2D
@export var item_type: Type = Type.MISC
## Flavour text shown at the foot of the inventory tooltip. Optional: an item without
## one simply shows its stats.
@export_multiline var description: String
## Which set of arm animations this item is held with — "hammer", "shield". Blank, or
## naming a set that has no animation for the action being played, falls back to the
## unarmed set, so an item only needs this once it has animations of its own.
@export var animation_set: StringName = &""
## Whether this is something to throw — a rock rather than a hammer. NPCs reach for these
## in their inventory to open a fight at range. Anything can still be thrown by hand;
## this only says it is meant to be.
@export var throwable := false
## What the item weighs, in kilograms. Authored here rather than read off the world
## scene, because that scene is freed the moment the item is stowed and only this record
## survives in the inventory. Keep it in step with the RigidBody3D's mass, which is the
## engine's own property and is what the physics actually uses.
@export var weight := 0.0
## Durability the item is built with, on the same scale as Destructible.durability.
## This is the authored maximum rather than the wear on one particular object: picking
## an item up frees the node that was tracking what it had left.
@export_range(0, 9999) var durability := 0
## Durability a melee blow that lands with this item in hand costs it. A whiff costs
## nothing. Zero means swinging it never wears it, which is right for anything that is
## not meant as a weapon. Pick it as durability over the landed hits it should survive.
@export_range(0, 999) var wear_per_hit := 0
## Footprint in inventory squares: x wide by y tall.
@export var grid_size := Vector2i(1, 1)
## Scene the item is rebuilt from when it leaves an inventory. Held as a path, not as a
## PackedScene: an item scene points at its ItemData, so an eager reference back at the
## scene would be a cyclic load. Loading lazily at drop time sidesteps that.
@export_file("*.tscn") var world_scene_path: String

## melee_damage() per world scene path, so each scene is only built once to be read.
static var _damage_cache := {}


## The squares this item covers, turned on its side when `rotated`. Which way round any
## one item is stored is not kept here — this record is shared by every copy of the item
## — but the two shapes it can take are the same for all of them.
func footprint(rotated: bool) -> Vector2i:
	return Vector2i(grid_size.y, grid_size.x) if rotated else grid_size


## Instantiates the world object this record came from, or null if no scene is set.
func spawn() -> Node3D:
	if world_scene_path.is_empty():
		return null
	var scene := load(world_scene_path) as PackedScene
	return scene.instantiate() as Node3D if scene else null


func is_weapon() -> bool:
	return item_type == Type.WEAPON


## What a blow with this item in hand deals: the impact damage authored on its world
## scene's Carryable, which is what MeleeAttack reads off the held object. It stays on
## the scene rather than being copied here so there is one number to tune; the inventory
## only needs it for show, so the scene is built once, read, freed, and the answer
## cached. Zero for an item that hits no harder than a fist.
func melee_damage() -> int:
	if world_scene_path.is_empty():
		return 0
	if _damage_cache.has(world_scene_path):
		return _damage_cache[world_scene_path]
	var damage := 0
	var item := spawn()
	if item:
		var carryable := item.get_node_or_null("Carryable") as Carryable
		damage = carryable.impact_damage if carryable else 0
		item.free()
	_damage_cache[world_scene_path] = damage
	return damage
