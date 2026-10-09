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
## Slowest closing speed at which a kicked object still hurts what it rolls into: a kick
## sends a heavy prop far slower than a throw.
@export var kick_min_speed := 1.0

@export_group("Sounds")
## The object knocking into the ground or another object. Unlike damage, this is heard
## from a much gentler bump, and the harder the impact the louder it is.
@export var impact_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
## Played instead when the object strikes something with Health — a thrown rock finding
## a head.
@export var body_hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
## Slowest impact that makes any sound, and the speed at which it is at full volume, in
## metres per second.
@export var sound_min_speed := 1.2
@export var sound_full_speed := 9.0
@export_group("")

## Shortest gap between two impact sounds from this object, so one tumble reporting many
## contacts is heard as a few knocks rather than a rattle.
const SOUND_GAP := 0.09
## Seconds after entering the tree before impacts are heard, so a level's props settling
## onto the ground at load make no sound.
const SETTLE_TIME := 0.4

@onready var _body: RigidBody3D = get_parent()
@onready var _destructible: Destructible = get_parent().get_node_or_null("Destructible")
@onready var _carryable: Carryable = get_parent().get_node_or_null("Carryable")

var _impact_velocity := Vector3.ZERO
## Set when the object is released and cleared by the first victim it finds. One throw
## therefore lands one hit, however many contact points the collision reports.
var _armed := false
## When an arm() with a time limit runs out, in seconds of Time.get_ticks_msec.
var _armed_until := INF
## Set while armed by a kick: the fixed damage its first living victim takes.
var _kick_damage := 0
## Counts down to the next impact this object may be heard making.
var _sound_wait := SETTLE_TIME


func _ready() -> void:
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.body_entered.connect(_on_body_entered)
	if _carryable:
		_carryable.released.connect(_on_released)


func _physics_process(delta: float) -> void:
	# Cached before the step integrates, so it is still the pre-impact velocity by the
	# time a contact signal arrives at the end of that same step.
	_impact_velocity = _body.linear_velocity
	_sound_wait -= delta


func get_impact_velocity() -> Vector3:
	return _impact_velocity


## Arms the object to deal damage on its next landing, credited to `by` (the thrower or
## kicker) through the same marks HandSlot leaves on what it lets go of. `seconds` > 0
## disarms it again after that long. `kick_damage` > 0 is a kick: too slow to clear the
## throw threshold, so it hurts whatever living thing it reaches above kick_min_speed,
## by that fixed amount.
func arm(by: Node3D = null, seconds := 1.5, kick_damage := 0) -> void:
	_armed = true
	_kick_damage = kick_damage
	_armed_until = Time.get_ticks_msec() / 1000.0 + seconds if seconds > 0.0 else INF
	if by:
		_body.set_meta(HandSlot.RELEASED_BY_META, by)
		_body.set_meta(HandSlot.RELEASED_AT_META, Time.get_ticks_msec() / 1000.0)


## A throw stays armed until it lands, however long it flies.
func _on_released() -> void:
	arm(null, 0.0)


func _on_body_entered(body: Node) -> void:
	var speed := _relative_speed(body)
	_play_impact(body, speed)
	if _armed and Time.get_ticks_msec() / 1000.0 > _armed_until:
		_armed = false
		_kick_damage = 0
	if _kick_damage > 0:
		_deal_kick_damage_to(body, speed)
		return
	if speed < speed_threshold:
		return
	var excess := speed - speed_threshold
	if _destructible:
		_destructible.damage(int(excess * damage_per_speed))
	_deal_damage_to(body, excess)


## Heard before any damage is dealt, while the object is certainly still in the tree:
## an impact that breaks it frees it at the end of the frame.
func _play_impact(body: Node, speed: float) -> void:
	if speed < sound_min_speed or _sound_wait > 0.0:
		return
	_sound_wait = SOUND_GAP
	var loudness := clampf(
		inverse_lerp(sound_min_speed, sound_full_speed, speed), 0.12, 1.0
	)
	# A living target is only struck as a body by a real throw; brushing past someone
	# while being carried about is an ordinary knock.
	var health := Health.find_in(body)
	var hit_body := speed >= speed_threshold and health != null and health.is_alive()
	Sfx.play_at(
		body_hit_sound if hit_body else impact_sound, _body.global_position, linear_to_db(loudness)
	)


## Closing speed, counting the other object's motion so two items thrown at each other
## hit harder than one thrown at a wall.
func _relative_speed(body: Node) -> float:
	var other_velocity := Vector3.ZERO
	var other_impact := body.get_node_or_null("ImpactDamage") as ImpactDamage
	if other_impact:
		other_velocity = other_impact.get_impact_velocity()
	return (_impact_velocity - other_velocity).length()


func _deal_kick_damage_to(body: Node, speed: float) -> void:
	if speed < kick_min_speed:
		return
	var health := Health.find_in(body)
	if health == null or not health.is_alive():
		return
	var info := DamageInfo.new(_kick_damage, _body)
	_armed = false
	_kick_damage = 0
	info.position = _body.global_position
	info.direction = _impact_velocity.normalized()
	info.knockback = _body.mass * _impact_velocity.length()
	health.apply_damage(info)


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
	# The thrown object's momentum, which is what it shoves its victim with.
	info.knockback = _body.mass * _impact_velocity.length()
	health.apply_damage(info)
