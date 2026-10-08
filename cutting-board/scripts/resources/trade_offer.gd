class_name TradeOffer
extends Resource

## One line of a trader's stock: the item and what it costs in soul flasks.

@export var item: ItemData
## Soul flasks the trader asks for one of these.
@export_range(1, 99) var price := 1
## How many it has to sell; each is its own tile in the trader's grid.
@export_range(1, 9) var count := 1
