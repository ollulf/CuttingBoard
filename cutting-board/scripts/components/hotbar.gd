class_name Hotbar
extends Node

signal changed

const SLOTS_PER_HAND := 3

@export var draw_sound: SoundBank = preload("res://resources/audio/draw.tres")
@export var stow_sound: SoundBank = preload("res://resources/audio/stow.tres")

var _slots: Array[HotbarSlot] = []
var _inventory: Inventory
var _hands: Array[HandSlot] = []
var _interactor: Interactor


func setup(inventory: Inventory, hands: Array[HandSlot], interactor: Interactor) -> void:
	_inventory = inventory
	_hands = hands
	_interactor = interactor
	_slots.clear()
	for hand_index in hands.size():
		for _i in SLOTS_PER_HAND:
			_slots.append(HotbarSlot.new(hand_index))
	if _inventory and not _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.connect(_on_inventory_changed)
	for hand in _hands:
		if not hand.item_released.is_connected(_on_item_released):
			hand.item_released.connect(_on_item_released)
	changed.emit()


func slot_count() -> int:
	return _slots.size()


func get_slot(index: int) -> HotbarSlot:
	return _slots[index] if index >= 0 and index < _slots.size() else null


func get_slots() -> Array[HotbarSlot]:
	return _slots


func get_hand(index: int) -> HandSlot:
	var slot := get_slot(index)
	return _hands[slot.hand_index] if slot and slot.hand_index < _hands.size() else null


func get_hand_name(index: int) -> String:
	var hand := get_hand(index)
	return hand.display_name if hand else ""


func assign(index: int, entry: InventoryEntry) -> bool:
	var slot := get_slot(index)
	if slot == null or entry == null:
		return false
	for other in _slots:
		if other != slot and other.entry == entry:
			other.clear()
	slot.assign(entry)
	changed.emit()
	return true


func assign_held(index: int, hand: HandSlot) -> bool:
	var slot := get_slot(index)
	if slot == null or hand == null or hand.is_free():
		return false
	var item := hand.get_held()
	for other in _slots:
		if other != slot and other.is_held() and other.held == item:
			other.clear()
	slot.link_held(item, hand.get_item_data())
	changed.emit()
	return true


func move_assignment(from_index: int, to_index: int) -> bool:
	var from := get_slot(from_index)
	var to := get_slot(to_index)
	if from == null or to == null or from == to or from.is_held() or to.is_held():
		return false
	var entry := from.entry
	var other := to.entry
	from.clear()
	to.clear()
	if entry:
		to.assign(entry)
	if other:
		from.assign(other)
	changed.emit()
	return true


func clear(index: int) -> bool:
	var slot := get_slot(index)
	if slot == null or slot.is_empty():
		return false
	slot.clear()
	changed.emit()
	return true


func use(index: int) -> bool:
	var slot := get_slot(index)
	if slot == null:
		return false
	if slot.is_held():
		return put_away_slot(slot)
	if slot.entry == null:
		return false
	return hold_entry(slot.entry, get_hand(index))


func hold_entry(entry: InventoryEntry, hand: HandSlot) -> bool:
	if entry == null or hand == null or _inventory == null or _interactor == null:
		return false
	if not _inventory.get_entries().has(entry):
		return false
	if not hand.is_free() and not put_away_hand(hand):
		_interactor.drop_hand(hand)
	var item := _interactor.spawn_into_hand(entry.data, entry.durability, hand)
	if item == null:
		return false
	var slot := _slot_for_entry(entry)
	if slot:
		slot.take_into_hand(item, entry)
	_inventory.remove(entry)
	Sfx.play(draw_sound)
	changed.emit()
	return true


func put_away_hand(hand: HandSlot, origin := Vector2i(-1, -1), rotated := false) -> bool:
	if hand == null or hand.is_free():
		return false
	return _bank(hand, _slot_for_held(hand.get_held()), origin, rotated)


func put_away_slot(slot: HotbarSlot) -> bool:
	if slot == null or not slot.is_held():
		return false
	return _bank(_hand_holding(slot.held), slot)


func stow_hands() -> int:
	var stowed := 0
	for hand in _hands:
		if put_away_hand(hand):
			stowed += 1
	return stowed


func has_held() -> bool:
	for hand in _hands:
		if not hand.is_free():
			return true
	return false


func move_between_hands(from: HandSlot, to: HandSlot) -> bool:
	if from == null or to == null or _interactor == null:
		return false
	var item := from.get_held()
	var slot := _slot_for_held(item)
	if slot:
		slot.held = null
	if not _interactor.move_held(from, to):
		if slot:
			slot.held = item
		return false
	if slot:
		slot.held = item
	changed.emit()
	return true


func _bank(
	hand: HandSlot, slot: HotbarSlot, origin := Vector2i(-1, -1), rotated := false
) -> bool:
	if hand == null or hand.is_free() or _inventory == null or _interactor == null:
		return false
	var item := hand.get_held()
	if origin.x < 0 and slot:
		origin = slot.origin
		rotated = slot.rotated
	if slot:
		slot.held = null
	var entry := _interactor.stow_held(hand, _inventory, origin, rotated)
	if entry == null:
		if slot:
			slot.held = item
		return false
	if slot:
		slot.return_to_grid(entry)
	Sfx.play(stow_sound)
	changed.emit()
	return true


func _hand_holding(item: Node3D) -> HandSlot:
	for hand in _hands:
		if hand.get_held() == item:
			return hand
	return null


func _slot_for_entry(entry: InventoryEntry) -> HotbarSlot:
	for slot in _slots:
		if slot.entry == entry:
			return slot
	return null


func _slot_for_held(item: Node3D) -> HotbarSlot:
	if item == null:
		return null
	for slot in _slots:
		if slot.is_held() and slot.held == item:
			return slot
	return null


func _on_item_released(item: Node3D) -> void:
	var slot := _slot_for_held(item)
	if slot == null:
		return
	slot.clear()
	changed.emit()


func _on_inventory_changed() -> void:
	var entries := _inventory.get_entries()
	for slot in _slots:
		if slot.entry == null:
			continue
		if not entries.has(slot.entry):
			slot.clear()
		else:
			slot.origin = slot.entry.origin
			slot.rotated = slot.entry.rotated
	changed.emit()
