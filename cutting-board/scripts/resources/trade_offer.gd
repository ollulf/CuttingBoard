class_name TradeOffer
extends Resource

@export var item: ItemData
@export_range(1, 99) var price := 1
@export_range(1, 9) var count := 1
