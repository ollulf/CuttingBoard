class_name ImpactDamage
extends Node

## Turns physical impacts into durability loss. Impacts below the speed threshold —
## setting an item down, nudging it along the floor — cost nothing.

## Roughly the speed of a plain drop from hand height, so releasing an item without
## winding up leaves it undamaged while a thrown one does not.
@export var speed_threshold := 6.5
## Durability lost per metre-per-second of impact above the threshold.
@export var damage_per_speed := 6.0

@onready var _body: RigidBody3D = get_parent()
@onready var _destructible: Destructible = get_parent().get_node_or_null("Destructible")

var _impact_velocity := Vector3.ZERO


func _ready() -> void:
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# Cached before the step integrates, so it is still the pre-impact velocity by the
	# time a contact signal arrives at the end of that same step.
	_impact_velocity = _body.linear_velocity


func get_impact_velocity() -> Vector3:
	return _impact_velocity


func _on_body_entered(body: Node) -> void:
	if _destructible == null:
		return
	var other_velocity := Vector3.ZERO
	var other_impact := body.get_node_or_null("ImpactDamage") as ImpactDamage
	if other_impact:
		other_velocity = other_impact.get_impact_velocity()
	var speed := (_impact_velocity - other_velocity).length()
	if speed < speed_threshold:
		return
	_destructible.damage(int((speed - speed_threshold) * damage_per_speed))
