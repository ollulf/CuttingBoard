class_name ItemTooltip
extends PanelContainer

@onready var _name_label: Label = %NameLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _weight_label: Label = %WeightLabel
@onready var _durability_label: Label = %DurabilityLabel
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	hide()


func show_item(data: ItemData, durability: int = -1) -> void:
	if data == null:
		hide()
		return
	_name_label.text = data.display_name
	var damage := data.melee_damage()
	_damage_label.text = "Damage  %d" % damage
	_damage_label.visible = damage > 0
	_weight_label.text = "Weight  %s kg" % String.num(data.weight, 1)
	_weight_label.visible = data.weight > 0.0
	var left := durability if durability >= 0 else data.durability
	_durability_label.text = "Durability  %d / %d" % [left, data.durability]
	_durability_label.visible = data.durability > 0
	_description_label.text = data.description
	_description_label.visible = not data.description.is_empty()
	reset_size()
	show()
