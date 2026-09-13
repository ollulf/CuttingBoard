class_name Destructible
extends Node

## Durability that depletes as the object takes damage. Author durability per item; the
## intended scale is roughly 500 for a hand-sized rock and 50 for a pot. Flip
## indestructible rather than authoring a huge value: it pins durability at the maximum
## and skips the bookkeeping entirely.

signal destroyed
## Durability actually lost, and where the object was when it lost it. Health reports
## its own hits through DamageInfo; this is the same event for things that wear down
## instead of dying, which is what lets both feed the same damage numbers.
signal damaged(amount: int, at: Vector3)

const MAX_DURABILITY := 9999

@export var indestructible := false
@export_range(0, 9999) var durability := 100


func _ready() -> void:
	# Applied here rather than in a setter on indestructible, because exported values
	# are restored in no guaranteed order while a scene loads.
	if indestructible:
		durability = MAX_DURABILITY


## What a world object has left, or -1 when it tracks no durability at all. Items carry
## their wear in and out of inventories through this pair, so a battered hammer is still
## battered when it comes back out of a bag.
static func read(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	var component := node.get_node_or_null("Destructible") as Destructible
	return component.durability if component else -1


## Sets what a freshly spawned object has left. A value of -1 means "as authored", which
## is what a record with no wear stored on it reports.
static func write(node: Node, durability: int) -> void:
	if durability < 0 or node == null or not is_instance_valid(node):
		return
	var component := node.get_node_or_null("Destructible") as Destructible
	if component and not component.indestructible:
		component.durability = durability


func damage(amount: int) -> void:
	if indestructible or amount <= 0:
		return
	# Report what was really lost, not what was asked for: a hit that overkills a
	# nearly broken object should read as the durability it had left.
	var lost := mini(amount, durability)
	durability = clampi(durability - amount, 0, MAX_DURABILITY)
	var node := get_parent() as Node3D
	damaged.emit(lost, node.global_position if node else Vector3.ZERO)
	if durability == 0:
		destroyed.emit()
		get_parent().queue_free()
