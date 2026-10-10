extends CanvasLayer

@onready var _left_prompt: Tooltip = $Corner/Prompts/LeftHandPrompt
@onready var _right_prompt: Tooltip = $Corner/Prompts/RightHandPrompt
@onready var _interact_prompt: Tooltip = $Corner/Prompts/InteractPrompt
@onready var _stow_prompt: Tooltip = $Corner/Prompts/StowPrompt
@onready var _kick_prompt: Tooltip = $Corner/Prompts/KickPrompt
@onready var _inventory_panel: InventoryPanel = $InventoryPanel
@onready var _hotbar_panel: HotbarPanel = $HotbarPanel
@onready var _hurt_overlay: HurtOverlay = $HurtOverlay
@onready var _mend_overlay: MendOverlay = $MendOverlay
@onready var _funhouse_mirror: FunhouseMirror = $FunhouseMirror
@onready var _cheat_menu: CheatMenu = $CheatMenu
@onready var _refused_label: Label = $RefusedLabel

const REFUSED_HOLD := 1.0
const REFUSED_FADE := 0.5
const GROUP := &"interaction_prompts"

var _refused_tween: Tween

@onready var _interactor: Interactor = %Interactor
@onready var _hand_left: HandSlot = %HandSlotLeft
@onready var _hand_right: HandSlot = %HandSlotRight
@onready var _inventory: Inventory = %Inventory
@onready var _hotbar: Hotbar = %Hotbar
@onready var _equipment: Equipment = %Equipment
@onready var _health: Health = %Health
@onready var _kick: Kick = get_node_or_null("%Kick")


func _ready() -> void:
	add_to_group(GROUP)
	_kick_prompt.hide()
	if _kick:
		_kick.target_changed.connect(_on_kick_target_changed)
	_inventory_panel.bind(_inventory)
	_cheat_menu.bind(_inventory)
	_inventory_panel.drop_requested.connect(_on_drop_requested)
	var hands: Array[HandSlot] = [_hand_left, _hand_right]
	_inventory_panel.bind_equipment(hands, _interactor)
	_inventory_panel.bind_loadout(_equipment)
	_inventory_panel.bind_health(_health)
	_hotbar_panel.bind(_hotbar)
	_hotbar_panel.bind_equipment(_equipment)
	_inventory_panel.bind_hotbar(_hotbar, _hotbar_panel)
	_hurt_overlay.bind(_health)
	_mend_overlay.bind(_health)
	_funhouse_mirror.bind(_hurt_overlay)
	_interactor.container_opened.connect(_inventory_panel.open_container)
	_interactor.trader_opened.connect(_inventory_panel.open_trade)
	_interactor.hover_changed.connect(_refresh.unbind(1))
	_hand_left.item_held.connect(_refresh.unbind(1))
	_hand_left.item_released.connect(_refresh.unbind(1))
	_hand_right.item_held.connect(_refresh.unbind(1))
	_hand_right.item_released.connect(_refresh.unbind(1))
	_inventory.changed.connect(_refresh)
	_interactor.stow_refused.connect(_on_stow_refused)
	_refused_label.modulate.a = 0.0
	_refresh()


func _physics_process(_delta: float) -> void:
	if Dialogue.find_dialogue_in(_interactor.get_hovered()):
		_update_interact_prompt()


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	_update_hand_prompt(_left_prompt, "LMB", _hand_left)
	_update_hand_prompt(_right_prompt, "RMB", _hand_right)
	_update_interact_prompt()
	_update_stow_prompt()


func _update_hand_prompt(prompt: Tooltip, key: String, hand: HandSlot) -> void:
	var held := hand.get_item_data()
	var usable := Usable.find_in(hand.get_held())
	if hand.is_free() and _hovering_carryable():
		prompt.show_prompt(key, "Pick up")
	elif Equipment.slot_for(held) != Equipment.NO_SLOT:
		prompt.show_prompt(key, "Put on %s" % held.display_name)
	elif held and usable and usable.is_used_in_hand():
		prompt.show_prompt(key, "%s %s" % [usable.held_verb, held.display_name])
	elif held and held.is_weapon():
		prompt.show_prompt(key, "Swing %s" % held.display_name)
	elif not hand.is_free():
		prompt.show_prompt("Shift+" + key, "Drop")
	else:
		prompt.show_prompt(key, "Punch")


func _update_interact_prompt() -> void:
	var container := _interactor.get_hovered_container()
	var usable := Usable.find_in(_interactor.get_hovered())
	var offer := usable.get_prompt(_interactor.get_owner()) if usable else ""
	var dialogue := Dialogue.find_dialogue_in(_interactor.get_hovered())
	if offer.is_empty() and dialogue:
		offer = dialogue.get_prompt(_interactor.get_owner())
	if _interactor.can_stow_hovered(_inventory):
		_interact_prompt.show_prompt("E", "Take")
	elif container:
		_interact_prompt.show_prompt("E", "Open %s" % container.get_display_name())
	elif _hovering_carryable():
		_interact_prompt.show_prompt("E", "Inventory full")
	elif not offer.is_empty():
		_interact_prompt.show_prompt("E", offer)
	else:
		_interact_prompt.hide()


func _on_stow_refused(_data: ItemData) -> void:
	if _refused_tween:
		_refused_tween.kill()
	_refused_label.modulate.a = 1.0
	_refused_tween = create_tween()
	_refused_tween.tween_interval(REFUSED_HOLD)
	_refused_tween.tween_property(_refused_label, "modulate:a", 0.0, REFUSED_FADE)


func _on_drop_requested(inventory: Inventory, entry: InventoryEntry) -> void:
	if _interactor.drop_item(entry.data, entry.durability):
		inventory.remove(entry)


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


func _on_kick_target_changed(target: Node3D) -> void:
	if target:
		_kick_prompt.show_prompt("Q", "Kick")
	else:
		_kick_prompt.hide()
