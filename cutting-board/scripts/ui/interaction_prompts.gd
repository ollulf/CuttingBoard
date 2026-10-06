extends CanvasLayer

## Contextual input prompts in the bottom-right corner: one row per hand plus the
## interact row, showing what can be done with whatever is currently under the
## crosshair. Also the place the inventory screen and the hotbar are bound to the
## player's own components, since this node — instanced into the player scene — can see
## the player's "%" names.

## The prompt rows stay on plain paths on purpose. "%" resolves against this node's
## owner, but only if this node registers no unique names of its own — marking the rows
## unique would make the lookups below search this scene instead of the player's.
@onready var _left_prompt: Tooltip = $Corner/Prompts/LeftHandPrompt
@onready var _right_prompt: Tooltip = $Corner/Prompts/RightHandPrompt
@onready var _interact_prompt: Tooltip = $Corner/Prompts/InteractPrompt
@onready var _stow_prompt: Tooltip = $Corner/Prompts/StowPrompt
@onready var _inventory_panel: InventoryPanel = $InventoryPanel
@onready var _hotbar_panel: HotbarPanel = $HotbarPanel

@onready var _interactor: Interactor = %Interactor
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _inventory: Inventory = %Inventory
@onready var _hotbar: Hotbar = %Hotbar
@onready var _equipment: Equipment = %Equipment
@onready var _health: Health = %Health


func _ready() -> void:
	_inventory_panel.bind(_inventory)
	_inventory_panel.drop_requested.connect(_on_drop_requested)
	var hands: Array[HandSlot] = [_hand_left, _hand_right]
	_inventory_panel.bind_equipment(hands, _interactor)
	_inventory_panel.bind_loadout(_equipment)
	_inventory_panel.bind_health(_health)
	# The bar draws itself from the hotbar; the inventory screen only needs to know
	# where its squares are, so that items can be dragged onto them.
	_hotbar_panel.bind(_hotbar)
	_inventory_panel.bind_hotbar(_hotbar, _hotbar_panel)
	_interactor.container_opened.connect(_inventory_panel.open_container)
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
	_update_stow_prompt()


## An empty hand pointed at something loose picks it up on a plain click; otherwise it
## swings what it is holding. Shift works the world with it.
func _update_hand_prompt(prompt: Tooltip, key: String, hand: HandSlot) -> void:
	var held := hand.get_item_data()
	if hand.is_free() and _hovering_carryable():
		prompt.show_prompt(key, "Pick up")
	elif held and held.is_weapon():
		prompt.show_prompt(key, "Swing %s" % held.display_name)
	elif not hand.is_free():
		prompt.show_prompt("Shift+" + key, "Drop")
	else:
		# An empty hand with nothing to pick up throws a punch, which is the same order
		# the click itself resolves in.
		prompt.show_prompt(key, "Punch")


func _update_interact_prompt() -> void:
	var container := _interactor.get_hovered_container()
	if _interactor.can_stow_hovered(_inventory):
		_interact_prompt.show_prompt("E", "Take")
	elif container:
		_interact_prompt.show_prompt("E", "Open %s" % container.get_display_name())
	elif _hovering_carryable():
		# Carryable but refused, which at this point only means the grid is full.
		_interact_prompt.show_prompt("E", "Inventory full")
	else:
		_interact_prompt.hide()


## An item dragged clear of the inventory window goes back into the world in front of
## the player. It only leaves the grid once it has actually made it out there, so an
## item with no world scene to rebuild from stays safely put instead of vanishing. The
## inventory comes with the request because the item may have been dragged out of an
## open chest rather than out of the player's own grid.
func _on_drop_requested(inventory: Inventory, entry: InventoryEntry) -> void:
	if _interactor.drop_item(entry.data, entry.durability):
		inventory.remove(entry)


## F packs both hands into the inventory, so it is offered whenever either hand has
## anything in it at all — what was picked up off the ground goes into the bag the same
## way as what came out of it.
func _update_stow_prompt() -> void:
	if _hotbar.has_held():
		_stow_prompt.show_prompt("F", "Put away")
	else:
		_stow_prompt.hide()


func _hovering_carryable() -> bool:
	var target := _interactor.get_hovered()
	if target == null or not is_instance_valid(target):
		return false
	return target.has_node("Carryable")
