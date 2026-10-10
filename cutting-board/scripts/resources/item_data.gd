class_name ItemData
extends Resource

enum Type { MISC, WEAPON, MASK, HEAD, BODY, PACK }

@export var display_name: String
@export var icon: Texture2D
@export var item_type: Type = Type.MISC
@export_multiline var description: String
@export var animation_set: StringName = &""
@export var throwable := false
@export var weight := 0.0
@export_range(0, 9999) var durability := 0
@export_range(0, 999) var wear_per_hit := 0
@export var grid_size := Vector2i(1, 1)
@export_file("*.tscn") var world_scene_path: String

static var _damage_cache := {}


func footprint(rotated: bool) -> Vector2i:
	return Vector2i(grid_size.y, grid_size.x) if rotated else grid_size


func spawn() -> Node3D:
	if world_scene_path.is_empty():
		return null
	var scene := load(world_scene_path) as PackedScene
	return scene.instantiate() as Node3D if scene else null


func is_weapon() -> bool:
	return item_type == Type.WEAPON


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
