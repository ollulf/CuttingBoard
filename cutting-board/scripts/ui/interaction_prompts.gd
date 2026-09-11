extends CanvasLayer

## Contextual input prompts in the bottom-right corner: one row per hand, showing what
## that hand can do with whatever is currently under the crosshair.

## The two prompt rows stay on plain paths on purpose. "%" resolves against this node's
## owner, but only if this node registers no unique names of its own — marking the rows
## unique would make the lookups below search this scene instead of the player's.
@onready var _left_prompt: Tooltip = $Corner/Prompts/LeftHandPrompt
@onready var _right_prompt: Tooltip = $Corner/Prompts/RightHandPrompt

@onready var _interactor: Interactor = %Interactor
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hand_right: HandSlot = %HandSlotRight


func _ready() -> void:
	_interactor.hover_changed.connect(_refresh.unbind(1))
	_hand_left.item_held.connect(_refresh.unbind(1))
	_hand_left.item_released.connect(_refresh.unbind(1))
	_hand_right.item_held.connect(_refresh.unbind(1))
	_hand_right.item_released.connect(_refresh.unbind(1))
	_refresh()


func _refresh() -> void:
	_update_prompt(_left_prompt, "LMB", _hand_left)
	_update_prompt(_right_prompt, "RMB", _hand_right)


func _update_prompt(prompt: Tooltip, key: String, hand: HandSlot) -> void:
	if not hand.is_free():
		prompt.show_prompt(key, "Drop")
	elif _hovering_carryable():
		prompt.show_prompt(key, "Pick up")
	else:
		prompt.hide()


func _hovering_carryable() -> bool:
	var target := _interactor.get_hovered()
	if target == null or not is_instance_valid(target):
		return false
	return target.has_node("Carryable")
