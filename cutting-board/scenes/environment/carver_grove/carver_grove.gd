extends Node3D

@export var light_fade_begin := 40.0
@export var light_fade_length := 15.0


func _ready() -> void:
	for part in [%Carver.get_node("Stump"), %Carver.get_node("Yard")]:
		part.add_to_group(&"navigation_source")
	for light: OmniLight3D in find_children("*", "OmniLight3D", true, false):
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = light_fade_begin
		light.distance_fade_length = light_fade_length
