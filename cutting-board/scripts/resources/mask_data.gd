class_name MaskData
extends ItemData

@export var worn_scene: PackedScene
@export var faction: FactionData


func _init() -> void:
	item_type = Type.MASK
