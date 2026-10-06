class_name InventoryPanel
extends Control

## The inventory screen, laid out like a gear screen: what is near you on the left, the
## character and what they wear and hold in the middle, the pack on the right, and the
## player's health along the top, with the hotbar along the bottom of the screen. It
## binds to any Inventory component, so the same screen serves the player, a chest or a
## wagon. Opening a container puts that container's grid up in the left-hand panel, and
## dragging between the two grids is what moves items in and out of it.
##
## The places an item can be are different in kind, and dragging between them is how it
## gets from one to another. A grid square is storage, holding a record. A hand slot is
## the hand itself: what is shown there is the live world object the player is carrying,
## so dragging an item onto a hand puts the real thing in it straight away, and dragging
## it off into the grid packs it away. A worn slot — mask, head, body, pack — holds a
## record again, on the player's Equipment, and only takes its own kind of item. A
## hotbar square is none of these — it is only a link to an item that stays in the grid,
## so that a number key can reach it.
##
## Items do not stack: each one holds its own squares, so a drag always carries exactly
## one item. Dragging is done with the left mouse button, and a drag clear of the window
## drops the item into the world. Right-click turns an item on its side, either where it
## lies or in the middle of a drag, so a long item can be made to fit down a grid it will
## not fit across.

## Edge length of one inventory square, in pixels. Square plus gap is 48, which is 24
## pixels of the 640 x 360 grid the UI is drawn to, so squares land on whole pixels.
@export var cell_size := 46
## Gap drawn between squares, in pixels.
@export var cell_gap := 2
## How long the cursor must be on an item before its tooltip appears, in seconds. The
## cursor does not have to be still: the wait runs while the mouse is moving.
@export var tooltip_delay := 0.5
## Where the tooltip's corner sits relative to the cursor, in pixels.
@export var tooltip_offset := Vector2(18, 20)
@export var empty_cell_color := Color(1, 1, 1, 0.07)
@export var item_color := Color(0.66, 0.39, 0.16, 0.4)
@export var item_border_color := Color(0.86, 0.68, 0.36, 0.6)
@export var item_text_color := Color(0.96, 0.9, 0.76)
## Outline of an empty equipment slot.
@export var slot_border_color := Color(0.85, 0.79, 0.63, 0.18)
## Outline of a hand that has something in it.
@export var held_border_color := Color(0.55, 0.9, 0.55, 0.95)
@export var valid_drop_color := Color(0.45, 0.85, 0.45, 0.35)
@export var invalid_drop_color := Color(0.9, 0.35, 0.3, 0.35)
## Tint of the dragged ghost once it is clear of the window and would be dropped.
@export var eject_color := Color(1.0, 0.85, 0.55, 0.9)

const NO_CELL := Vector2i(-1, -1)

## The two grids the screen can show. A cell index on its own does not say which
## inventory it belongs to, so every point on screen and every drag carries a side
## along with it.
enum Side { PLAYER, CONTAINER }
const NO_SIDE := -1

## Emitted when an item is dragged clear of the window. The panel does not know how to
## put things into the world, so whoever owns this inventory performs the drop and then
## takes the record out of the grid. The inventory it came out of travels with it, since
## that may be an open container rather than the player's own grid.
signal drop_requested(inventory: Inventory, entry: InventoryEntry)

@onready var _window: Control = %Window
@onready var _size_label: Label = %PlayerSize
@onready var _grid: Control = %PlayerGrid
@onready var _container_title: Label = %ContainerTitle
@onready var _container_size: Label = %ContainerSize
@onready var _container_grid: Control = %ContainerGrid
@onready var _nearby_empty: Control = %NearbyEmpty
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_value: Label = %HealthValue
@onready var _figure: PaperDoll = %Figure
@onready var _hand_boxes: Array[Panel] = [%LeftHandSlot, %RightHandSlot]
@onready var _hand_labels: Array[Label] = [%LeftHandLabel, %RightHandLabel]
## The box of each worn slot, by Equipment.Slot.
@onready var _wear_boxes: Dictionary = {
	Equipment.Slot.MASK: %MaskSlot,
	Equipment.Slot.HEAD: %HeadSlot,
	Equipment.Slot.BODY: %BodySlot,
	Equipment.Slot.PACK: %PackSlot,
}
@onready var _tooltip: ItemTooltip = %ItemTooltip
@onready var _tooltip_timer: Timer = %TooltipTimer

## What an empty worn slot says, by Equipment.Slot.
const WEAR_NAMES := {
	Equipment.Slot.MASK: "Mask",
	Equipment.Slot.HEAD: "Head",
	Equipment.Slot.BODY: "Body",
	Equipment.Slot.PACK: "Pack",
}

var _inventory: Inventory
## The container whose grid is up beside the player's, or null when none is open. The
## panel only displays it: opening and closing is driven from the world.
var _container: Inventory
var _interactor: Interactor
var _hands: Array[HandSlot] = []
## What the player is wearing. The screen only shows it and moves records in and out.
var _equipment: Equipment
var _health: Health
## The bar along the bottom and the panel drawing it. The bar is not part of this
## screen — it is on show the whole time — but this screen owns the mouse while it is
## open, so assigning items to the bar is hit-tested against the panel from here.
var _hotbar: Hotbar
var _hotbar_panel: HotbarPanel

## Tiles by the entry, hand or worn slot's box they were built for, so a dragged item can
## be dimmed.
var _tiles: Dictionary = {}
## The clickable box of each hand slot, by hand.
var _slot_boxes: Dictionary = {}

## A drag carries one item, from any of the places the screen holds items: _drag_entry
## with _drag_side is set when it came out of a grid, _drag_hand when it came out of a
## hand, _drag_wear when it was taken off a worn slot, and _drag_hotbar when it is a
## hotbar link being moved along the bar.
var _drag_data: ItemData
var _drag_entry: InventoryEntry
var _drag_side := NO_SIDE
var _drag_hand: HandSlot
var _drag_wear := Equipment.NO_SLOT
var _drag_hotbar := HotbarPanel.NO_SLOT
## Which way round the carried item currently lies. It starts as the entry was stored
## and can be turned mid-drag, so it is drag state rather than something read back off
## the entry when the item lands.
var _drag_rotated := false
## Which square of the item the cursor grabbed, and where inside it, in pixels. The
## pixel offset is what keeps the ghost from snapping under the cursor on pick-up.
var _drag_grab_cell := Vector2i.ZERO
var _drag_grab_pixels := Vector2.ZERO
var _ghost: Control
var _drop_hint: ColorRect

## What the cursor is currently resting on, and whether a mouse button is down. Between
## them they are the whole condition for the tooltip: it waits out the delay on one
## item, and any press — a click or the start of a drag — takes it back off.
##
## The hover is tracked by _hover_source, the entry or hand the item sits in, and not by
## the record: two hammers share one ItemData, so comparing records would read a move
## from one to the other as no move at all and leave the card showing the first one.
var _hover_source: Object
var _hover_data: ItemData
## Wear of the item under the cursor. It is not on the ItemData — that record is shared
## by every copy of the item — so the tooltip has to be told separately.
var _hover_durability := -1
var _mouse_down := false


func _ready() -> void:
	_tooltip_timer.wait_time = tooltip_delay
	_tooltip_timer.timeout.connect(_on_tooltip_delay_elapsed)
	hide()


## Points the panel at an inventory and keeps it in step with that inventory's contents.
func bind(inventory: Inventory) -> void:
	if _inventory == inventory:
		return
	if _inventory and _inventory.changed.is_connected(_rebuild):
		_inventory.changed.disconnect(_rebuild)
	_inventory = inventory
	if _inventory:
		_inventory.changed.connect(_rebuild)
	_rebuild()


## Gives the panel the hands to show. Whatever they are physically holding appears in
## them, wherever it came from, which is what lets something picked up off the ground be
## dragged into the bag. The interactor is what turns a record into a world object and
## back again.
## The screen has a box for a left and a right hand, which the first two hands fill.
func bind_equipment(hands: Array[HandSlot], interactor: Interactor) -> void:
	_hands = hands
	_interactor = interactor
	_slot_boxes.clear()
	for index in mini(_hands.size(), _hand_boxes.size()):
		var hand := _hands[index]
		_slot_boxes[hand] = _hand_boxes[index]
		_hand_labels[index].text = hand.display_name
		hand.item_held.connect(_rebuild.unbind(1))
		hand.item_released.connect(_rebuild.unbind(1))
	_rebuild()


## Gives the panel the loadout to show in the worn slots around the figure.
func bind_loadout(equipment: Equipment) -> void:
	if _equipment and _equipment.changed.is_connected(_rebuild):
		_equipment.changed.disconnect(_rebuild)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(_rebuild)
	_figure.bind(_equipment)
	_rebuild()


## Gives the panel the health to show in its header.
func bind_health(health: Health) -> void:
	if _health and _health.changed.is_connected(_on_health_changed):
		_health.changed.disconnect(_on_health_changed)
	_health = health
	if _health:
		_health.changed.connect(_on_health_changed)
	_show_health()


func _on_health_changed(_current: int, _maximum: int) -> void:
	_show_health()


## Read off the component rather than taken from the signal alone, so that opening the
## screen can refresh it too: the panel is bound before Health has run its own _ready
## and filled itself up, and a value cached then would read as zero.
func _show_health() -> void:
	var current := _health.get_current() if _health else 0
	var maximum := _health.max_health if _health else 0
	_health_bar.max_value = maxi(maximum, 1)
	_health_bar.value = current
	_health_value.text = "%d / %d" % [current, maximum]


## Gives the panel the hotbar to assign items to, and the panel drawing it, which is
## what says where its squares are on screen.
func bind_hotbar(hotbar: Hotbar, panel: HotbarPanel) -> void:
	_hotbar = hotbar
	_hotbar_panel = panel


## Puts a container's grid up beside the player's and opens the screen on it. Opening a
## second container simply swaps which one is shown; closing the screen puts it away.
func open_container(container: Inventory) -> void:
	if container == null or container == _inventory:
		return
	_bind_container(container)
	open()


func _bind_container(container: Inventory) -> void:
	if _container == container:
		return
	if _container and _container.changed.is_connected(_rebuild):
		_container.changed.disconnect(_rebuild)
	_container = container
	if _container:
		_container.changed.connect(_rebuild)
	_rebuild()


## The panel handles its own key so the toggle still works once the panel has released
## the mouse — the player controller ignores input while the cursor is free.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		# Escape backs out of a drag first, and only closes the panel when idle.
		if _is_dragging():
			_cancel_drag()
		else:
			close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event is InputEventMouseButton:
		# Any button going down ends the hover, so the tooltip never sits over a click
		# or rides along with a drag.
		_mouse_down = event.pressed
		if event.pressed:
			_clear_hover()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.position)
			else:
				_end_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_rotate(event.position)
		if not event.pressed:
			# The button is up again, so the item under the cursor starts its wait over.
			_update_hover(event.position, true)
	elif event is InputEventMouseMotion:
		if _is_dragging():
			_update_drag(event.position)
		else:
			_update_hover(event.position, false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _inventory == null:
		return
	_rebuild()
	_show_health()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_cancel_drag()
	_clear_hover()
	# A container is only open for as long as the screen showing it is.
	_bind_container(null)
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Grids ------------------------------------------------------------------------

func _inventory_for(side: int) -> Inventory:
	return _container if side == Side.CONTAINER else _inventory


func _grid_for(side: int) -> Control:
	return _container_grid if side == Side.CONTAINER else _grid


## The sides currently on screen. The player's grid is always there; the container's is
## only there while one is open.
func _visible_sides() -> Array[int]:
	var sides: Array[int] = [Side.PLAYER]
	if _container:
		sides.append(Side.CONTAINER)
	return sides


## The grid square under a panel-local point, as {"side", "cell"}, or an empty
## dictionary when the point is not on any grid.
func _slot_at(pos: Vector2) -> Dictionary:
	for side in _visible_sides():
		var cell := _cell_at(side, pos)
		if cell != NO_CELL:
			return {"side": side, "cell": cell}
	return {}


# --- Dragging ---------------------------------------------------------------------

func _is_dragging() -> bool:
	return _drag_data != null


## The squares the carried item covers, which is the turned footprint once it has been
## rotated mid-drag.
func _drag_size() -> Vector2i:
	return _drag_data.footprint(_drag_rotated)


## Right-click turns an item on its side: the one being carried if a drag is running,
## otherwise the one under the cursor where it lies. A turn with no room for it is
## refused and nothing moves. On the hotbar there is nothing to turn — a square there is
## only a link — so right-click takes the link off instead.
func _rotate(pos: Vector2) -> void:
	if _is_dragging():
		_rotate_drag(pos)
		return
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		_hotbar.clear(hotbar_index)
		return
	var slot := _slot_at(pos)
	if slot.is_empty():
		return
	var inventory := _inventory_for(slot["side"])
	var entry := inventory.get_entry_at(slot["cell"])
	if entry:
		inventory.rotate_item(entry)


## Turns the carried item, keeping the cursor on the same corner of it by reflecting the
## grab across the diagonal — which is exactly what the footprint itself just did.
func _rotate_drag(pos: Vector2) -> void:
	_drag_rotated = not _drag_rotated
	_drag_grab_cell = Vector2i(_drag_grab_cell.y, _drag_grab_cell.x)
	_drag_grab_pixels = Vector2(_drag_grab_pixels.y, _drag_grab_pixels.x)
	# The ghost is built at a fixed size, so it has to be made again at the new one. It
	# goes back on top of the drop hint simply by being added after it.
	_ghost.queue_free()
	_ghost = _make_tile(_drag_data, _drag_rotated)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	_update_drag(pos)


func _begin_drag(pos: Vector2) -> void:
	var hand := _hand_at(pos)
	if hand:
		_begin_hand_drag(hand, pos)
		return
	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		_begin_wear_drag(wear, pos)
		return
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		_begin_hotbar_drag(hotbar_index, pos)
		return
	var slot := _slot_at(pos)
	if slot.is_empty():
		return
	var side: int = slot["side"]
	var cell: Vector2i = slot["cell"]
	var entry := _inventory_for(side).get_entry_at(cell)
	if entry == null:
		return
	_drag_entry = entry
	_drag_side = side
	_drag_data = entry.data
	_drag_rotated = entry.rotated
	_drag_grab_cell = cell - entry.origin
	_drag_grab_pixels = (
		pos - _grid_origin(side) - Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
	)

	# The item is on the cursor now, so the square it came from reads as empty.
	_dim_tile(entry)
	_start_ghost(pos)


func _begin_hand_drag(hand: HandSlot, pos: Vector2) -> void:
	var data := hand.get_item_data()
	if _interactor == null or data == null:
		return
	_drag_hand = hand
	_drag_data = data
	# Read off the live object, which is where the wear has been landing.
	# A hand holds an object, not a shape in a grid, so an item always comes out of one
	# upright and is turned from there if it has to be.
	_drag_rotated = false
	_drag_grab_cell = Vector2i.ZERO
	# Grabbed in the middle, since a hand has no square the cursor landed on.
	_drag_grab_pixels = Vector2(_span(data.grid_size.x), _span(data.grid_size.y)) * 0.5
	_dim_tile(hand)
	_start_ghost(pos)


## Taking something off. Like a hand, a worn slot has no squares for the cursor to have
## landed on, so the item comes off upright and grabbed in the middle. It stays on until
## it has somewhere to go.
func _begin_wear_drag(slot: int, pos: Vector2) -> void:
	var data := _equipment.get_item(slot)
	if data == null:
		return
	_drag_wear = slot
	_drag_data = data
	_drag_rotated = false
	_drag_grab_cell = Vector2i.ZERO
	_drag_grab_pixels = Vector2(_span(data.grid_size.x), _span(data.grid_size.y)) * 0.5
	_dim_tile(_wear_boxes[slot])
	_start_ghost(pos)


## A hotbar square carries only its link. What it points at stays exactly where it is,
## so this drag can do one of two things when it lands: move the link to another square,
## or, anywhere else, take it off. It is refused while the item is out in the hand, for
## the same reason the hotbar refuses to move such a link — the square's hand is fixed.
func _begin_hotbar_drag(index: int, pos: Vector2) -> void:
	var slot := _hotbar.get_slot(index)
	if slot == null or slot.entry == null:
		return
	_drag_hotbar = index
	_drag_data = slot.data
	_drag_rotated = false
	_drag_grab_cell = Vector2i.ZERO
	_drag_grab_pixels = (
		Vector2(_span(_drag_data.grid_size.x), _span(_drag_data.grid_size.y)) * 0.5
	)
	_start_ghost(pos)


func _start_ghost(pos: Vector2) -> void:
	_ghost = _make_tile(_drag_data, _drag_rotated)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)

	_drop_hint = ColorRect.new()
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_hint)
	move_child(_drop_hint, _ghost.get_index())

	_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	_ghost.position = pos - _drag_grab_pixels
	# Clear of the window the item is on its way out, so the ghost says so.
	_ghost.modulate = eject_color if _is_outside_window(pos) else Color(1, 1, 1, 0.75)

	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		var rect := _hotbar_panel.slot_rect(hotbar_index)
		_drop_hint.position = rect.position - global_position
		_drop_hint.size = rect.size
		_drop_hint.color = (
			valid_drop_color if _accepts_link(hotbar_index) else invalid_drop_color
		)
		_drop_hint.show()
		return

	var hand := _hand_at(pos)
	if hand:
		var box: Control = _slot_boxes[hand]
		_drop_hint.position = box.global_position - global_position
		_drop_hint.size = box.size
		_drop_hint.color = valid_drop_color if _accepts(hand) else invalid_drop_color
		_drop_hint.show()
		return

	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		var wear_box: Control = _wear_boxes[wear]
		_drop_hint.position = wear_box.global_position - global_position
		_drop_hint.size = wear_box.size
		_drop_hint.color = valid_drop_color if _accepts_wear(wear) else invalid_drop_color
		_drop_hint.show()
		return

	var slot := _slot_at(pos)
	# A hotbar link has nowhere to land but the bar: dropped anywhere else it simply
	# comes off, and there is no square to promise it.
	if slot.is_empty() or _drag_hotbar != HotbarPanel.NO_SLOT:
		_drop_hint.hide()
		return
	var side: int = slot["side"]
	var cell: Vector2i = slot["cell"]
	var origin := cell - _drag_grab_cell
	var footprint := _drag_size()
	_drop_hint.position = _grid_origin(side) + Vector2(_offset(origin.x), _offset(origin.y))
	_drop_hint.size = Vector2(_span(footprint.x), _span(footprint.y))
	_drop_hint.color = valid_drop_color if _can_drop_at(side, cell) else invalid_drop_color
	_drop_hint.show()


func _end_drag(pos: Vector2) -> void:
	if not _is_dragging():
		return
	var entry := _drag_entry
	var from := _inventory_for(_drag_side)
	var from_hand := _drag_hand
	var from_wear := _drag_wear
	var from_hotbar := _drag_hotbar
	var rotated := _drag_rotated
	var grab := _drag_grab_cell
	var slot := _slot_at(pos)
	var target_hand := _hand_at(pos)
	var target_wear := _wear_at(pos)
	# Judged while the drag is still running, since that is the state it reads.
	var wear_ok := _accepts_wear(target_wear)
	var target_hotbar := _hotbar_at(pos)
	var outside := _is_outside_window(pos)
	_cancel_drag()

	if from_hotbar != HotbarPanel.NO_SLOT:
		# A link, not an item. It either moves along the bar or comes off it; the item
		# it pointed at never moves either way.
		if target_hotbar != HotbarPanel.NO_SLOT:
			_hotbar.move_assignment(from_hotbar, target_hotbar)
		else:
			_hotbar.clear(from_hotbar)
		return
	if target_hotbar != HotbarPanel.NO_SLOT:
		# Only an item sitting in the player's own grid can be linked to a key: the bar
		# points into that one bag. Something in the hand is not in there to be pointed
		# at, and something in a chest is about to be left behind when the lid shuts.
		if entry and from == _inventory:
			_hotbar.assign(target_hotbar, entry)
		return
	if target_hand:
		_drop_on_hand(target_hand, entry, from_hand)
		return
	if target_wear != Equipment.NO_SLOT:
		if wear_ok:
			_put_on(target_wear, from, entry)
		return
	if outside:
		# Released clear of the window: out into the world it goes. An item in the hand
		# is already a world object, so it is simply let go rather than rebuilt.
		if from_hand:
			_interactor.drop_hand(from_hand)
		elif from_wear != Equipment.NO_SLOT:
			_drop_worn(from_wear)
		else:
			drop_requested.emit(from, entry)
		return
	if slot.is_empty():
		# Still over the window but off the grids — a miss, not a drop. The item stays.
		return
	var to := _inventory_for(slot["side"])
	var cell: Vector2i = slot["cell"]
	if from_hand:
		_stow_hand_to_grid(from_hand, to, cell - grab, rotated)
		return
	if from_wear != Equipment.NO_SLOT:
		_take_off(from_wear, to, cell - grab, rotated)
		return
	_place_item(from, entry, to, cell - grab, rotated)


## Puts a dragged item down on a grid square. Within one grid that is a plain
## relocation, which silently fails and leaves the item put if the destination is
## blocked.
##
## Crossing between the player and a container is the same gesture, with one difference:
## the item is only taken out of the source once the destination has accepted it, so a
## chest with no room leaves it where it was rather than losing it on the way across.
func _place_item(
	from: Inventory, entry: InventoryEntry, to: Inventory, origin: Vector2i, rotated: bool
) -> void:
	if from == null or to == null or entry == null:
		return
	if from == to:
		to.move(entry, origin, rotated)
		return
	# Across grids the square it was dropped on is only a preference: an item aimed at
	# an occupied corner still goes in, wherever it fits. Its wear and the way round it
	# was turned travel with it.
	if not to.add_at(entry.data, origin, entry.durability, rotated):
		var free := to.find_free_origin(entry.data.footprint(rotated))
		if free.x < 0 or not to.add_at(entry.data, free, entry.durability, rotated):
			return
	from.remove(entry)


## Dropping an item onto a hand puts the real thing straight into it — the record leaves
## the grid and the world object is built in its place. Dragged from the other hand it
## simply changes hands, object and all.
## The drag is already over by the time this runs, so what is being dropped arrives as
## arguments rather than being read back off the drag state.
func _drop_on_hand(hand: HandSlot, entry: InventoryEntry, from_hand: HandSlot) -> void:
	if hand == null or hand == from_hand or not hand.is_free():
		return
	if from_hand:
		_hotbar.move_between_hands(from_hand, hand)
		return
	if entry == null:
		return
	# Routed through the hotbar rather than the interactor so that an item with a key
	# assigned to it keeps that link while it is out in the hand.
	_hotbar.hold_entry(entry, hand)


## Packs what a hand is holding into a grid, preferring the square it was dropped on and
## falling back to anywhere it fits. The object is only destroyed once the record is
## safely stored, so a full inventory leaves the item in the hand rather than losing it.
func _stow_hand_to_grid(
	hand: HandSlot, to: Inventory, origin: Vector2i, rotated: bool
) -> void:
	if to == null or hand.is_free():
		return
	if to == _inventory:
		# The player's own bag is where the hotbar links point, so this goes through the
		# bar: an item with a key keeps it, and lands back under that key.
		_hotbar.put_away_hand(hand, origin, rotated)
		return
	_interactor.stow_held(hand, to, origin, rotated)


## Puts an item from a grid on. The record moves out of the grid and onto the loadout,
## wear and all; the grid only lets go of it once the slot has taken it.
func _put_on(slot: int, from: Inventory, entry: InventoryEntry) -> void:
	if from == null or entry == null:
		return
	if _equipment.equip(slot, entry.data, entry.durability):
		from.remove(entry)


## Takes a worn item off into a grid, preferring the square it was dropped on and falling
## back to anywhere it fits, the same as an item crossing between grids. A grid with no
## room leaves it on.
func _take_off(slot: int, to: Inventory, origin: Vector2i, rotated: bool) -> void:
	var data := _equipment.get_item(slot)
	if to == null or data == null:
		return
	var durability := _equipment.get_durability(slot)
	if not to.add_at(data, origin, durability, rotated):
		var free := to.find_free_origin(data.footprint(rotated))
		if free.x < 0 or not to.add_at(data, free, durability, rotated):
			return
	_equipment.unequip(slot)


## Drops a worn item into the world, which only takes it off once it is out there: an
## item with no world scene stays on rather than vanishing.
func _drop_worn(slot: int) -> void:
	if _interactor and _interactor.drop_item(
		_equipment.get_item(slot), _equipment.get_durability(slot)
	):
		_equipment.unequip(slot)


## Clears drag state and its overlays; safe to call when no drag is running.
func _cancel_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _drop_hint:
		_drop_hint.queue_free()
		_drop_hint = null
	for key in [_drag_entry, _drag_hand, _wear_boxes.get(_drag_wear)]:
		var tile := _tiles.get(key) as Control
		if tile:
			tile.modulate.a = 1.0
	_drag_data = null
	_drag_entry = null
	_drag_side = NO_SIDE
	_drag_hand = null
	_drag_wear = Equipment.NO_SLOT
	_drag_hotbar = HotbarPanel.NO_SLOT
	_drag_rotated = false


## Whether a hand will take the item being dragged: the hand must be empty, and the item
## must be something there is a world object to make — a record with no scene behind it
## has nothing to put in a hand. What kind of item it is does not come into it: a hand
## can carry a barrel as readily as a hammer.
func _accepts(hand: HandSlot) -> bool:
	if hand == null or _drag_data == null or hand == _drag_hand:
		return false
	# Something being taken off goes into a grid first: there is no path yet that turns a
	# worn record straight into an object in the hand.
	if _drag_hotbar != HotbarPanel.NO_SLOT or _drag_wear != Equipment.NO_SLOT:
		return false
	return hand.is_free() and not _drag_data.world_scene_path.is_empty()


## Whether a worn slot will take what is being dragged: it has to be free, the item has
## to be its kind, and it has to come out of a grid. An item in a hand is a live object
## and would first have to be packed away into a record.
func _accepts_wear(slot: int) -> bool:
	if _equipment == null or _drag_data == null or slot == Equipment.NO_SLOT:
		return false
	if _drag_entry == null or slot == _drag_wear:
		return false
	return _equipment.is_free(slot) and _equipment.accepts(slot, _drag_data)


## Whether a hotbar square will take what is being dragged. Links are made to items in
## the grid, so only a grid item can be dropped on an empty square; a link already on
## the bar can be dropped on any other square, which moves or swaps it.
func _accepts_link(index: int) -> bool:
	if _hotbar == null:
		return false
	if _drag_hotbar != HotbarPanel.NO_SLOT:
		var target := _hotbar.get_slot(index)
		# A square whose item is out in the hand is not a place a link can be put: its
		# key is tied to the arm the item is in.
		return index != _drag_hotbar and target != null and not target.is_held()
	return _drag_entry != null and _drag_side == Side.PLAYER


func _can_drop_at(side: int, cell: Vector2i) -> bool:
	var to := _inventory_for(side)
	var origin := cell - _drag_grab_cell
	# An item may reuse the squares it is itself vacating, but only in the grid it is
	# leaving — coming out of a hand, or out of the other grid, it vacates nothing here.
	var vacating := _drag_entry if side == _drag_side else null
	return to.is_region_free(origin, _drag_size(), vacating)


# --- Tooltip ----------------------------------------------------------------------

## Follows the cursor between items. The delay is a wait on the item, not on the mouse
## holding still: it runs while the cursor is moving, and moving about within a single
## item does not restart it. Once a card is up it travels with the cursor, and sweeping
## on to the next item swaps it straight over — having waited once, the player is
## reading tooltips, and being made to wait again for each one only gets in the way.
func _update_hover(pos: Vector2, restart: bool) -> void:
	var hovered := _hover_at(pos)
	var source: Object = hovered.get("source")
	if source == _hover_source and not restart:
		if _tooltip.visible:
			_place_tooltip(pos)
		return
	var was_showing := _tooltip.visible
	_hover_source = source
	_hover_data = hovered.get("data") as ItemData
	_hover_durability = int(hovered.get("durability", -1))
	if _hover_data == null or _mouse_down:
		_tooltip.hide()
		_tooltip_timer.stop()
		return
	if was_showing:
		_tooltip_timer.stop()
		_tooltip.show_item(_hover_data, _hover_durability)
		_place_tooltip(pos)
		return
	_tooltip.hide()
	_tooltip_timer.start()


func _clear_hover() -> void:
	_hover_source = null
	_hover_data = null
	_hover_durability = -1
	_tooltip_timer.stop()
	_tooltip.hide()


func _on_tooltip_delay_elapsed() -> void:
	# The conditions are re-checked rather than trusted: short as the delay is, a drag
	# or a click can still have begun while it was running.
	if _hover_data == null or _mouse_down or _is_dragging():
		return
	_tooltip.show_item(_hover_data, _hover_durability)
	_place_tooltip(get_local_mouse_position())


## Sets the card beside the cursor, flipping it to the other side at the edges of the
## screen so it is never clipped and never pushed off under the cursor itself.
func _place_tooltip(pos: Vector2) -> void:
	var card := _tooltip.size
	var target := pos + tooltip_offset
	if target.x + card.x > size.x:
		target.x = pos.x - tooltip_offset.x - card.x
	if target.y + card.y > size.y:
		target.y = pos.y - tooltip_offset.y - card.y
	_tooltip.position = target.clamp(Vector2.ZERO, (size - card).max(Vector2.ZERO))


## What the cursor is on, as {"source", "data", "durability"}, or an empty dictionary
## where there is no item. A hand reports what it is holding and a hotbar square what it
## is linked to. The source is the entry, hand, slot or square the item is in, and it is what
## identifies this particular item — the record does not, since every copy of an item
## shares one, and the wear is not on the record for that same reason.
func _hover_at(pos: Vector2) -> Dictionary:
	var hand := _hand_at(pos)
	if hand:
		var held := hand.get_item_data()
		if held == null:
			return {}
		return {"source": hand, "data": held, "durability": hand.get_durability()}
	var wear := _wear_at(pos)
	if wear != Equipment.NO_SLOT:
		var worn := _equipment.get_item(wear)
		if worn == null:
			return {}
		return {
			"source": _wear_boxes[wear], "data": worn,
			"durability": _equipment.get_durability(wear),
		}
	var hotbar_index := _hotbar_at(pos)
	if hotbar_index != HotbarPanel.NO_SLOT:
		var link := _hotbar.get_slot(hotbar_index)
		if link == null or link.data == null:
			return {}
		return {"source": link, "data": link.data, "durability": link.get_durability()}
	var slot := _slot_at(pos)
	if slot.is_empty():
		return {}
	var entry := _inventory_for(slot["side"]).get_entry_at(slot["cell"])
	if entry == null:
		return {}
	return {"source": entry, "data": entry.data, "durability": entry.durability}


# --- Layout -----------------------------------------------------------------------

func _rebuild() -> void:
	if not is_node_ready() or _inventory == null:
		return
	_tiles.clear()
	_rebuild_grid(Side.PLAYER)
	_rebuild_nearby()
	_rebuild_equipment()


## The left-hand panel is always there, so the screen does not jump about as chests are
## opened and shut; with nothing open it says so in place of a grid.
func _rebuild_nearby() -> void:
	_container_grid.visible = _container != null
	_nearby_empty.visible = _container == null
	if _container:
		_rebuild_grid(Side.CONTAINER)
		return
	for child in _container_grid.get_children():
		child.queue_free()
	_container_title.text = "Nearby"
	_container_size.text = ""


func _rebuild_grid(side: int) -> void:
	var inventory := _inventory_for(side)
	var host := _grid_for(side)
	for child in host.get_children():
		child.queue_free()

	var cells := inventory.grid_size
	var size_text := "%d x %d" % [cells.x, cells.y]
	if side == Side.CONTAINER:
		_container_title.text = inventory.get_display_name()
		_container_size.text = size_text
	else:
		_size_label.text = size_text
	host.custom_minimum_size = Vector2(_span(cells.x), _span(cells.y))

	for y in cells.y:
		for x in cells.x:
			host.add_child(_make_cell(Vector2i(x, y)))
	for entry in inventory.get_entries():
		var tile := _make_tile(entry.data, entry.rotated)
		tile.position = Vector2(_offset(entry.origin.x), _offset(entry.origin.y))
		host.add_child(tile)
		_tiles[entry] = tile


## Fills the boxes around the figure: the two hands with what they are holding, and the
## worn slots with what the loadout has on. The boxes themselves are laid out in the
## scene; only what is in them changes.
func _rebuild_equipment() -> void:
	for hand: HandSlot in _slot_boxes:
		var data := hand.get_item_data()
		_fill_slot(_slot_boxes[hand], hand, data, "empty", data != null)
	for slot in _wear_boxes:
		var worn := _equipment.get_item(slot) if _equipment else null
		_fill_slot(_wear_boxes[slot], _wear_boxes[slot], worn, WEAR_NAMES[slot], false)


## Puts an item's tile in a slot box, or the slot's name when it is empty. A hand with
## something in it is outlined, as its square on the hotbar is.
func _fill_slot(box: Panel, key: Object, data: ItemData, empty_text: String, held: bool) -> void:
	for child in box.get_children():
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = empty_cell_color
	style.set_border_width_all(2)
	style.border_color = held_border_color if held else slot_border_color
	box.add_theme_stylebox_override("panel", style)

	if data == null:
		var label := Label.new()
		label.text = empty_text
		label.modulate = Color(1, 1, 1, 0.3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var tile := _make_slot_tile(data, box.size)
	box.add_child(tile)
	_tiles[key] = tile


## An item's tile sized for a slot box rather than for the grid. It goes in upright when
## it fits, turned when only that fits, and shrunk to fit when neither does — a barrel
## in a hand is still a barrel, just drawn smaller. It is centred either way.
func _make_slot_tile(data: ItemData, room: Vector2) -> Control:
	var rotated := false
	var cells := data.footprint(false)
	var span := Vector2(_span(cells.x), _span(cells.y))
	if span.x > room.x or span.y > room.y:
		var turned := data.footprint(true)
		var turned_span := Vector2(_span(turned.x), _span(turned.y))
		if turned_span.x <= room.x and turned_span.y <= room.y:
			rotated = true
			span = turned_span
	var tile := _make_tile(data, rotated)
	var fit := minf(1.0, minf(room.x / span.x, room.y / span.y))
	tile.scale = Vector2(fit, fit)
	tile.position = ((room - span * fit) * 0.5).floor()
	return tile


func _make_cell(cell: Vector2i) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = empty_cell_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(_offset(cell.x), _offset(cell.y))
	rect.size = Vector2(cell_size, cell_size)
	return rect


## Builds one item tile sized to its footprint. Callers place it: the grid positions it
## on a cell, an equipment slot centres it, a drag hands it to the cursor. Both the size
## and the minimum are set, since only one of the two is honoured in each of those.
##
## A plain Panel rather than a PanelContainer: a container grows to its content's minimum
## size, and a wrapping label measured before it has a width asks for one line per word,
## which stretched a fresh drag ghost into a tall column. A Panel keeps the footprint.
func _make_tile(data: ItemData, rotated: bool = false) -> Control:
	var tile := Panel.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.clip_contents = true
	# The tile covers its whole footprint including the gaps between the squares it spans.
	var cells := data.footprint(rotated)
	var footprint := Vector2(_span(cells.x), _span(cells.y))
	tile.size = footprint
	tile.custom_minimum_size = footprint

	var style := StyleBoxFlat.new()
	style.bg_color = item_color
	style.set_border_width_all(2)
	style.border_color = item_border_color
	tile.add_theme_stylebox_override("panel", style)

	var content: Control
	if data.icon:
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content = icon
	else:
		var label := Label.new()
		label.text = data.display_name
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", item_text_color)
		content = label
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	return tile


## True when a panel-local point lies beyond the whole window — header, all three panels
## and the hotbar included. The test is the window rather than the grids, so releasing
## on a margin or a title is a harmless miss while only a deliberate drag clear of the
## window throws an item away.
func _is_outside_window(pos: Vector2) -> bool:
	if _local_rect(_window).has_point(pos):
		return false
	if _hotbar_panel and _hotbar_panel.get_bar_rect().has_point(pos + global_position):
		return false
	return true


## The hand slot under a panel-local point, or null if there is none.
func _hand_at(pos: Vector2) -> HandSlot:
	for hand in _slot_boxes:
		if _local_rect(_slot_boxes[hand]).has_point(pos):
			return hand
	return null


## The worn slot under a panel-local point, or Equipment.NO_SLOT. The slots only count
## once there is a loadout behind them.
func _wear_at(pos: Vector2) -> int:
	if _equipment == null:
		return Equipment.NO_SLOT
	for slot in _wear_boxes:
		if _local_rect(_wear_boxes[slot]).has_point(pos):
			return slot
	return Equipment.NO_SLOT


## The hotbar square under a panel-local point. The bar is a panel of its own rather
## than part of this screen, so the point is handed over in screen coordinates and it
## answers for its own layout.
func _hotbar_at(pos: Vector2) -> int:
	if _hotbar == null or _hotbar_panel == null:
		return HotbarPanel.NO_SLOT
	return _hotbar_panel.slot_index_at(pos + global_position)


## Fades the square an item was picked up from, so it reads as the hole it has left.
func _dim_tile(key: Object) -> void:
	var tile := _tiles.get(key) as Control
	if tile:
		tile.modulate.a = 0.3


func _local_rect(control: Control) -> Rect2:
	return Rect2(control.global_position - global_position, control.size)


## A grid's top-left corner in this panel's coordinates, which is what mouse positions
## arriving in _gui_input are measured against.
func _grid_origin(side: int) -> Vector2:
	return _grid_for(side).global_position - global_position


## The square of one grid under a panel-local point, or NO_CELL when the point is off it.
func _cell_at(side: int, pos: Vector2) -> Vector2i:
	var local := pos - _grid_origin(side)
	if local.x < 0.0 or local.y < 0.0:
		return NO_CELL
	var pitch := cell_size + cell_gap
	var cell := Vector2i(int(local.x) / pitch, int(local.y) / pitch)
	var cells := _inventory_for(side).grid_size
	if cell.x >= cells.x or cell.y >= cells.y:
		return NO_CELL
	return cell


## Pixel offset of a cell index, and the pixel span of a run of cells.
func _offset(index: int) -> int:
	return index * (cell_size + cell_gap)


func _span(count: int) -> int:
	return count * cell_size + maxi(count - 1, 0) * cell_gap
