class_name ItemTooltip
extends PanelContainer

## The hover card shown beside the cursor in the inventory: what the item is, what it
## weighs, the durability it was built with, and its description. Fill it in with
## show_item(); placing it beside the cursor is the inventory panel's job.

@onready var _name_label: Label = %NameLabel
@onready var _weight_label: Label = %WeightLabel
@onready var _durability_label: Label = %DurabilityLabel
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	hide()


## Fills the card in from an item record and puts it on screen. Rows the item has no
## value for are taken off the card rather than left showing a zero, so an item that
## has not been given a weight, a durability or a description yet still reads cleanly.
##
## `durability` is what this particular item has left, which the record cannot tell us —
## an ItemData is shared by every copy of the item, so it only knows the value they were
## all built with. Pass -1 for an item that has taken no damage.
func show_item(data: ItemData, durability: int = -1) -> void:
	if data == null:
		hide()
		return
	_name_label.text = data.display_name
	_weight_label.text = "Weight  %s kg" % String.num(data.weight, 1)
	_weight_label.visible = data.weight > 0.0
	# Always shown as a fraction, undamaged included: "220 / 220" says at a glance that
	# the item is whole, where a bare "220" leaves the reader to guess what full is.
	var left := durability if durability >= 0 else data.durability
	_durability_label.text = "Durability  %d / %d" % [left, data.durability]
	_durability_label.visible = data.durability > 0
	_description_label.text = data.description
	_description_label.visible = not data.description.is_empty()
	# The card is sized to whatever survived, so a stats-only item is not padded out to
	# the height of one with a description.
	reset_size()
	show()
