extends Node

## Floating damage numbers for the whole game.
##
## Nothing has to opt in: this watches the scene tree and hooks every Health and every
## Destructible as it appears, so a new enemy or a new breakable prop shows numbers the
## moment it is placed, with no wiring in its scene. Damage numbers are presentation,
## and keeping that decision here is what keeps the components themselves free of it.

const NUMBER_SCENE := preload("res://scenes/vfx/damage_number.tscn")

## Hits on something that can die, and wear on an object that can break. Two colours
## because the two mean different things: one is progress, the other is your barrel
## coming apart in your hands.
const HEALTH_COLOR := Color(1.0, 0.85, 0.35)
const DURABILITY_COLOR := Color(0.7, 0.78, 0.9)

## How far above a victim's own origin a number appears when the hit itself did not say
## where it landed.
@export var fallback_height := 1.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Health:
		(node as Health).damaged.connect(_on_health_damaged.bind(node))
	elif node is Destructible:
		(node as Destructible).damaged.connect(_on_durability_lost)


## Spawns a number into the running scene rather than onto the victim, so it keeps
## rising after a barrel that just shattered is gone.
func show_damage(amount: int, at: Vector3, color: Color) -> void:
	if amount <= 0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var number := NUMBER_SCENE.instantiate() as DamageNumber
	scene.add_child(number)
	number.pop(amount, at, color)


func _on_health_damaged(info: DamageInfo, health: Health) -> void:
	show_damage(info.amount, _hit_position(info, health), HEALTH_COLOR)


func _on_durability_lost(amount: int, at: Vector3) -> void:
	show_damage(amount, at, DURABILITY_COLOR)


## Where the number belongs: the impact point if the hit recorded one, otherwise a
## guess above the victim, since a Health component itself has no position.
func _hit_position(info: DamageInfo, health: Health) -> Vector3:
	if not info.position.is_zero_approx():
		return info.position
	var owner_node := health.get_parent() as Node3D
	if owner_node == null:
		return Vector3.ZERO
	return owner_node.global_position + Vector3.UP * fallback_height
