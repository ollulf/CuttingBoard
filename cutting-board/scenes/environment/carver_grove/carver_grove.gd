extends Node3D

## The Carver placed in a level: his model plus simple collision for the stump, the
## workbench, the chopping block, the plank stack and the brazier, so the player and the
## navmesh treat them as solid. The hanging masks, boards and shavings stay walk-through.
##
## His lights only shine when someone is near: each one fades out with distance, so the
## grove costs nothing from across the valley. The lanterns and candles themselves glow
## by their own material, so they still read as a landmark from afar.

## Distance from the camera where the lights start to fade, and over how many metres.
@export var light_fade_begin := 40.0
@export var light_fade_length := 15.0


func _ready() -> void:
	# The level's navmesh is baked from meshes, not collision: let it see the stump (with
	# its roots) and the yard, so NPCs walk round them. The hanging masks stay out of it.
	for part in [%Carver.get_node("Stump"), %Carver.get_node("Yard")]:
		part.add_to_group(&"navigation_source")
	for light: OmniLight3D in find_children("*", "OmniLight3D", true, false):
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = light_fade_begin
		light.distance_fade_length = light_fade_length
