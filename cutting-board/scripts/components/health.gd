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


## What is left as a fraction of the maximum, 0..1.
func get_ratio() -> float:
	return float(_current) / maxf(float(max_health), 1.0)


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
	# A body part — a flinching or fallen character's physical bone — is hit on behalf of
	# the character it belongs to.
	node = HumanBody.actor_of(node)
	var direct := node.get_node_or_null("Health") as Health
	if direct:
		return direct
	for child in node.get_children():
		if child is Health:
			return child
	return null


## Whether `node` is still standing. Something with no Health cannot die, so it counts as
## alive for as long as it exists.
static func is_node_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var health := find_in(node)
	return health == null or health.is_alive()
