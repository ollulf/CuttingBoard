class_name ItemData
extends Resource

## Data record stored by the inventory; the world Node3D is freed once picked up.

## What kind of item this is. Equipment slots use it to decide what they will accept;
## MISC is the default so an item is only a weapon when it says so.
enum Type { MISC, WEAPON }

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
## What the item weighs, in kilograms. Authored here rather than read off the world
## scene, because that scene is freed the moment the item is stowed and only this record
## survives in the inventory. Keep it in step with the RigidBody3D's mass, which is the
## engine's own property and is what the physics actually uses.
@export var weight := 0.0
## Durability the item is built with, on the same scale as Destructible.durability.
## This is the authored maximum rather than the wear on one particular object: picking
## an item up frees the node that was tracking what it had left.
@export_range(0, 9999) var durability := 0
## Footprint in inventory squares: x wide by y tall.
@export var grid_size := Vector2i(1, 1)
## Scene the item is rebuilt from when it leaves an inventory. Held as a path, not as a
## PackedScene: an item scene points at its ItemData, so an eager reference back at the
## scene would be a cyclic load. Loading lazily at drop time sidesteps that.
@export_file("*.tscn") var world_scene_path: String


## Instantiates the world object this record came from, or null if no scene is set.
func spawn() -> Node3D:
	if world_scene_path.is_empty():
		return null
	var scene := load(world_scene_path) as PackedScene
	return scene.instantiate() as Node3D if scene else null


func is_weapon() -> bool:
	return item_type == Type.WEAPON
