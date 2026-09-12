extends CanvasLayer

## Contextual input prompts in the bottom-right corner: one row per hand plus the
## interact row, showing what can be done with whatever is currently under the
## crosshair. Also the place the inventory panel is bound to the player's Inventory,
## since this node — instanced into the player scene — can see the player's "%" names.

## The prompt rows stay on plain paths on purpose. "%" resolves against this node's
## owner, but only if this node registers no unique names of its own — marking the rows
## unique would make the lookups below search this scene instead of the player's.
@onready var _left_prompt: Tooltip = $Corner/Prompts/LeftHandPrompt
@onready var _right_prompt: Tooltip = $Corner/Prompts/RightHandPrompt
@onready var _interact_prompt: Tooltip = $Corner/Prompts/InteractPrompt
@onready var _inventory_panel: InventoryPanel = $InventoryPanel

@onready var _interactor: Interactor = %Interactor
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _inventory: Inventory = %Inventory


func _ready() -> void:
	_inventory_panel.bind(_inventory)
	_interactor.hover_changed.connect(_refresh.unbind(1))
	_hand_left.item_held.connect(_refresh.unbind(1))
	_hand_left.item_released.connect(_refresh.unbind(1))
	_hand_right.item_held.connect(_refresh.unbind(1))
	_hand_right.item_released.connect(_refresh.unbind(1))
	_inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_update_hand_prompt(_left_prompt, "LMB", _hand_left)
	_update_hand_prompt(_right_prompt, "RMB", _hand_right)
	_update_interact_prompt()


func _update_hand_prompt(prompt: Tooltip, key: String, hand: HandSlot) -> void:
	if not hand.is_free():
		prompt.show_prompt(key, "Drop")
	elif _hovering_carryable():
		prompt.show_prompt(key, "Pick up")
	else:
		prompt.hide()


func _update_interact_prompt() -> void:
	if _interactor.can_stow_hovered(_inventory):
		_interact_prompt.show_prompt("E", "Take")
	elif _hovering_carryable():
		# Carryable but refused, which at this point only means the grid is full.
		_interact_prompt.show_prompt("E", "Inventory full")
	else:
		_interact_prompt.hide()


func _hovering_carryable() -> bool:
	var target := _interactor.get_hovered()
	if target == null or not is_instance_valid(target):
		return false
	return target.has_node("Carryable")
