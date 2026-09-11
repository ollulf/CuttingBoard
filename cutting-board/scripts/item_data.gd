class_name ItemData
extends Resource

## Data record stored by the inventory; the world Node3D is freed once picked up.

@export var display_name: String
@export var icon: Texture2D
@export var grid_size := Vector2i(1, 1)
@export var stack_max := 1
@export var world_scene: PackedScene
