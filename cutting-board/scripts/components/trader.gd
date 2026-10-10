class_name Trader
extends Usable

@export var currency: ItemData = preload("res://resources/items/soul_bottle.tres")
@export var offers: Array[TradeOffer] = []

@onready var _stock: Inventory = %Stock

var _prices: Dictionary = {}


func _ready() -> void:
	for offer in offers:
		if offer == null or offer.item == null:
			continue
		for i in offer.count:
			var entry := _stock.store(offer.item)
			if entry:
				_prices[entry] = offer.price


func get_stock() -> Inventory:
	return _stock


func get_prompt(by: Node) -> String:
	return "Trade" if by != null else ""


func price_of(entry: InventoryEntry) -> int:
	return _prices.get(entry, 0)


func count_currency(inventory: Inventory) -> int:
	var total := 0
	for entry in inventory.get_entries():
		if entry.data == currency:
			total += 1
	return total


func can_afford(entry: InventoryEntry, inventory: Inventory) -> bool:
	return inventory != null and _prices.has(entry) and count_currency(inventory) >= price_of(entry)


func buy(entry: InventoryEntry, inventory: Inventory, origin := Vector2i(-1, -1),
		rotated := false) -> bool:
	if not can_afford(entry, inventory):
		return false
	var price := price_of(entry)
	var paid: Array[InventoryEntry] = []
	for owned in inventory.get_entries().duplicate():
		if paid.size() >= price:
			break
		if owned.data == currency:
			paid.append(owned)
			inventory.remove(owned)
	var bought: InventoryEntry = null
	if origin.x >= 0:
		bought = inventory.store_at(entry.data, origin, entry.durability, rotated)
	if bought == null:
		bought = inventory.store(entry.data, entry.durability)
	if bought == null:
		for flask in paid:
			inventory.store_at(flask.data, flask.origin, flask.durability, flask.rotated)
		return false
	_prices.erase(entry)
	_stock.remove(entry)
	return true
