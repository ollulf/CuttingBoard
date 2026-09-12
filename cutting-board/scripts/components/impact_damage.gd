class_name ImpactDamage
extends Node

## Turns physical impacts into damage, in both directions: the object wears itself down
## against whatever it strikes, and a thrown object hurts what it lands on. Impacts
## below the speed threshold — setting an item down, nudging it along the floor — cost
## nothing either way.

## Roughly the speed of a plain drop from hand height, so releasing an item without
## winding up leaves it undamaged while a thrown one does not.
@export var speed_threshold := 6.5
## Durability this object loses per metre-per-second of impact above the threshold.
@export var damage_per_speed := 6.0
## Impact speed at which a hit deals the full Carryable.impact_damage; slower hits scale
## down to nothing at the threshold, which is what makes a charged throw worth charging.
@export var full_damage_speed := 12.0

@onready var _body: RigidBody3D = get_parent()
@onready var _destructible: Destructible = get_parent().get_node_or_null("Destructible")
@onready var _carryable: Carryable = get_parent().get_node_or_null("Carryable")

var _impact_velocity := Vector3.ZERO
## Set when the object is released and cleared by the first victim it finds. One throw
## therefore lands one hit, however many contact points the collision reports.
var _armed := false


func _ready() -> void:
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.body_entered.connect(_on_body_entered)
	if _carryable:
		_carryable.released.connect(_arm)


func _physics_process(_delta: float) -> void:
	# Cached before the step integrates, so it is still the pre-impact velocity by the
	# time a contact signal arrives at the end of that same step.
	_impact_velocity = _body.linear_velocity


func get_impact_velocity() -> Vector3:
	return _impact_velocity


## Re-arms the object to deal damage on its next landing.
func _arm() -> void:
	_armed = true


func _on_body_entered(body: Node) -> void:
	var speed := _relative_speed(body)
	if speed < speed_threshold:
		return
	var excess := speed - speed_threshold
	if _destructible:
		_destructible.damage(int(excess * damage_per_speed))
	_deal_damage_to(body, excess)


## Closing speed, counting the other object's motion so two items thrown at each other
## hit harder than one thrown at a wall.
func _relative_speed(body: Node) -> float:
	var other_velocity := Vector3.ZERO
	var other_impact := body.get_node_or_null("ImpactDamage") as ImpactDamage
	if other_impact:
		other_velocity = other_impact.get_impact_velocity()
	return (_impact_velocity - other_velocity).length()


func _deal_damage_to(body: Node, excess: float) -> void:
	if not _armed or _carryable == null or _carryable.impact_damage <= 0:
		return
	var health := Health.find_in(body)
	if health == null:
		return
	_armed = false
	var span := maxf(full_damage_speed - speed_threshold, 0.01)
	var ratio := clampf(excess / span, 0.0, 1.0)
	var info := DamageInfo.new(roundi(_carryable.impact_damage * ratio), _body)
	info.position = _body.global_position
	info.direction = _impact_velocity.normalized()
	health.apply_damage(info)
