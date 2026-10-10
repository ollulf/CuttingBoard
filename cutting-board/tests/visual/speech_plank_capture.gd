extends Node

func _ready() -> void:
	var plank := SpeechPlank.new()
	add_child(plank)
	plank.show_line("Mask-Monger", "Welcome to the world, little one. You can't see a thing yet, can you? Here, wear this mask and look around.", null)
