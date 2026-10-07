class_name Hotbar
extends Node

## The row of numbered slots along the bottom of the screen: three for the left hand and
## three for the right, worked with the number keys.
##
## A slot is a link to an item in the inventory, not a place items are kept. Assigning
## one leaves the item exactly where it is in the grid and only draws a line between the
## two, so the bar is a set of shortcuts rather than a second bag. Pressing the key is
## what moves anything: the item comes out of the grid and into the hand as a real world
## object, and pressing the key again puts it back in the squares it came from.

signal changed

## How many slots each hand gets. The first run of slots is the left hand's, the second
## the right's, which is what makes 1-3 and 4-6 read as two hands rather than six keys.
const SLOTS_PER_HAND := 3

## An item coming out of the bag into a hand, and going back into it. Heard however it
## happens — a number key, the stow key or a drag on the inventory screen.
@export var draw_sound: SoundBank = preload("res://resources/audio/draw.tres")
@export var stow_sound: SoundBank = preload("res://resources/audio/stow.tres")

var _slots: Array[HotbarSlot] = []
var _inventory: Inventory
var _hands: Array[HandSlot] = []
var _interactor: Interactor


## Wires the bar to the body it belongs to. Called by the player, which is the only
## thing that can see all three of these at once.
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


## The hand a slot's key reaches with. A slot keeps this even while its item is out in
## the other hand, since it is only ever a question of where the next draw goes.
func get_hand(index: int) -> HandSlot:
	var slot := get_slot(index)
	return _hands[slot.hand_index] if slot and slot.hand_index < _hands.size() else null


## The name of the hand a slot belongs to, for the bar's own captions.
func get_hand_name(index: int) -> String:
	var hand := get_hand(index)
	return hand.display_name if hand else ""


## Links a slot to an item sitting in the inventory. The item is not moved or copied:
## the grid keeps it, and the slot merely knows where it is.
func assign(index: int, entry: InventoryEntry) -> bool:
	var slot := get_slot(index)
	if slot == null or entry == null:
		return false
	# One item answers to one key. Assigning it again takes it off whichever slot had
	# it, rather than leaving two squares pointing at the same hammer.
	for other in _slots:
		if other != slot and other.entry == entry:
			other.clear()
	slot.assign(entry)
	changed.emit()
	return true


## Links a slot to whatever a hand is holding, and leaves it in the hand. The square then
## follows it just as it would an item drawn with its own key: pressing the key puts it
## away, and pressing it again draws it into the slot's hand. Its wear stays on the object.
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


## Moves a link from one square to another, swapping with whatever is there. Refused
## while either item is out in a hand: a slot's hand is fixed, so moving a link across
## the bar mid-use would leave the key pointing at the wrong arm.
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


## What a number key does: draws the slot's item if it is waiting in the bag, and puts
## it away again if it is already in hand. One key is the whole gesture, so the tap that
## brought the hammer out is the one that puts it back.
func use(index: int) -> bool:
	var slot := get_slot(index)
	if slot == null:
		return false
	if slot.is_held():
		return put_away_slot(slot)
	if slot.entry == null:
		return false
	return hold_entry(slot.entry, get_hand(index))


## Takes an item out of the grid and puts the real thing in a hand. Whatever that hand
## was holding is banked first, and dropped only if the bag has no room for it — a draw
## always ends with the item you asked for in your hand.
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
	# The slot is pointed at the object before the entry goes, so the removal below is
	# not mistaken for the item being lost.
	var slot := _slot_for_entry(entry)
	if slot:
		slot.take_into_hand(item, entry)
	_inventory.remove(entry)
	Sfx.play(draw_sound)
	changed.emit()
	return true


## Puts what a hand is holding back into the inventory, whether the bar knows about that
## item or not — something picked up off the ground goes into the bag the same way.
## Returns false, and leaves the item in the hand, when there is no room for it.
##
## `origin` is for a player dropping the item on a chosen square: left out, the item
## goes back to the squares it came from, which is what a key press wants.
func put_away_hand(hand: HandSlot, origin := Vector2i(-1, -1), rotated := false) -> bool:
	if hand == null or hand.is_free():
		return false
	return _bank(hand, _slot_for_held(hand.get_held()), origin, rotated)


func put_away_slot(slot: HotbarSlot) -> bool:
	if slot == null or not slot.is_held():
		return false
	# Which hand it is actually in, not which hand the key draws into: a dragged item
	# can have changed hands since.
	return _bank(_hand_holding(slot.held), slot)


## Empties both hands into the inventory, which is what the stow key does. Each hand is
## tried on its own, so a bag with room for one of the two still takes that one.
func stow_hands() -> int:
	var stowed := 0
	for hand in _hands:
		if put_away_hand(hand):
			stowed += 1
	return stowed


## Whether anything is in hand at all, which is the whole condition for the stow prompt.
func has_held() -> bool:
	for hand in _hands:
		if not hand.is_free():
			return true
	return false


## Hands a held item across to the other hand, keeping its slot pointed at it.
func move_between_hands(from: HandSlot, to: HandSlot) -> bool:
	if from == null or to == null or _interactor == null:
		return false
	var item := from.get_held()
	var slot := _slot_for_held(item)
	# Detached first: the release inside the move would otherwise read as a loss.
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


## The common half of putting something away: bank the record, destroy the object, and
## leave the slot — if this item had one — pointing at where it landed.
func _bank(
	hand: HandSlot, slot: HotbarSlot, origin := Vector2i(-1, -1), rotated := false
) -> bool:
	if hand == null or hand.is_free() or _inventory == null or _interactor == null:
		return false
	var item := hand.get_held()
	if origin.x < 0 and slot:
		# No square was asked for, so it goes back where it came from.
		origin = slot.origin
		rotated = slot.rotated
	if slot:
		slot.held = null
	var entry := _interactor.stow_held(hand, _inventory, origin, rotated)
	if entry == null:
		# No room. The item never left the hand, so the slot goes back to watching it.
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


## An item that leaves a hand by any route the bar did not drive — thrown, dropped or
## smashed — is loose in the world, so its square lets go of it.
func _on_item_released(item: Node3D) -> void:
	var slot := _slot_for_held(item)
	if slot == null:
		return
	slot.clear()
	changed.emit()


## Links only survive as long as the item they point at. Dragging an item into a chest
## or out into the world takes it out of the grid, and the square it answered to goes
## quiet rather than pointing at an entry that no longer exists.
func _on_inventory_changed() -> void:
	var entries := _inventory.get_entries()
	for slot in _slots:
		if slot.entry == null:
			continue
		if not entries.has(slot.entry):
			slot.clear()
		else:
			# The item may have been moved or turned in the grid since. The slot follows
			# it, so putting it away later still aims at where it actually sits.
			slot.origin = slot.entry.origin
			slot.rotated = slot.entry.rotated
	changed.emit()
