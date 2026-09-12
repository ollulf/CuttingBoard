class_name Health
extends Node

## Hit points for anything that can be hurt. It deliberately does not decide what death
## means: it empties, emits died, and stops there. A sibling component or the owner's
## own script picks the consequence — ragdoll, loot, despawn, or, for a training dummy,
## standing back up. That is what keeps this one component usable by every enemy.

signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal changed(current: int, maximum: int)

@export var max_health := 100
@export var invulnerable := false

var _current: int


func _ready() -> void:
	_current = max_health


func get_current() -> int:
	return _current


func is_alive() -> bool:
	return _current > 0


func apply_damage(info: DamageInfo) -> void:
	if info == null or info.amount <= 0 or invulnerable or not is_alive():
		return
	_current = maxi(_current - info.amount, 0)
	changed.emit(_current, max_health)
	damaged.emit(info)
	if _current == 0:
		died.emit(info)


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	_current = mini(_current + amount, max_health)
	changed.emit(_current, max_health)


## Puts the owner back to full, which is how a death behaviour revives it.
func reset() -> void:
	_current = max_health
	changed.emit(_current, max_health)


## Resolves the Health that should receive damage aimed at `node`. Everything that deals
## damage goes through here, so hit locations can be introduced later — a Hurtbox area
## on the head pointing back at the body's Health — without teaching every attacker
## about the new layout.
static func find_in(node: Node) -> Health:
	if node == null or not is_instance_valid(node):
		return null
	var direct := node.get_node_or_null("Health") as Health
	if direct:
		return direct
	for child in node.get_children():
		if child is Health:
			return child
	return null
