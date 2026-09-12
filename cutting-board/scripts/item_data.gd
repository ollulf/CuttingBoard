class_name ItemData
extends Resource

## Data record stored by the inventory; the world Node3D is freed once picked up.

## What kind of item this is. Equipment slots use it to decide what they will accept;
## MISC is the default so an item is only a weapon when it says so.
enum Type { MISC, WEAPON }

@export var display_name: String
@export var icon: Texture2D
@export var item_type: Type = Type.MISC
## Footprint in inventory squares: x wide by y tall.
@export var grid_size := Vector2i(1, 1)
@export var stack_max := 1
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
