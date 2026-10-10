class_name Tooltip
extends PanelContainer

@onready var _key_label: Label = $Row/KeyBadge/KeyLabel
@onready var _action_label: Label = $Row/ActionLabel


func show_prompt(key: String, action: String) -> void:
	_key_label.text = key
	_action_label.text = action
	show()
