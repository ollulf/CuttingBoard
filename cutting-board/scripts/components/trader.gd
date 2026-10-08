class_name Trader
extends Usable

## Sells its stock for soul flasks, and only sells: the player cannot sell anything back.
## Sits on the trader as its Usable, so the interact key offers "Trade"; the interactor
## then puts the trade screen up (InventoryPanel.open_trade). The stock is a grid of its
## own (an Inventory child named "Stock", not "Inventory", so the interactor never opens
## it as a plain container to loot), and the price of each entry is kept alongside it.
##
## The money is real items: a price of 3 takes three Soul in a Bottle out of the buyer's
## pack. No hidden wallet.

## What the trader takes as money.
@export var currency: ItemData = preload("res://resources/items/soul_bottle.tres")
## What it sells, tuned in the inspector or a .tres per trader.
@export var offers: Array[TradeOffer] = []

@onready var _stock: Inventory = %Stock

## Price per stock entry.
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


## What `entry` of the stock costs, or 0 for something that is not for sale.
func price_of(entry: InventoryEntry) -> int:
	return _prices.get(entry, 0)


## Soul flasks in `inventory`.
func count_currency(inventory: Inventory) -> int:
	var total := 0
	for entry in inventory.get_entries():
		if entry.data == currency:
			total += 1
	return total


## Whether `inventory` holds enough flasks to pay for `entry`.
func can_afford(entry: InventoryEntry, inventory: Inventory) -> bool:
	return inventory != null and _prices.has(entry) and count_currency(inventory) >= price_of(entry)


## Sells `entry` to whoever carries `inventory`: takes its price in flasks out of the pack
## and puts the item in, at `origin` if that is free, else wherever it fits. The flasks
## paid make room too, so a full pack can still swap flasks for a small item. If the
## item does not fit even then, the flasks go back where they were and nothing changes.
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
