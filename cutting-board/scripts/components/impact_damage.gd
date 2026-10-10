class_name ImpactDamage
extends Node

@export var speed_threshold := 6.5
@export var damage_per_speed := 6.0
@export var full_damage_speed := 12.0
@export var kick_min_speed := 1.0
@export var kick_hit_wear := 0

@export_group("Sounds")
@export var impact_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export var body_hit_sound: SoundBank = preload("res://resources/audio/hit_body.tres")
@export var sound_min_speed := 1.2
@export var sound_full_speed := 9.0
@export_group("")

const SOUND_GAP := 0.09
const SETTLE_TIME := 0.4

@onready var _body: RigidBody3D = get_parent()
@onready var _destructible: Destructible = get_parent().get_node_or_null("Destructible")
@onready var _carryable: Carryable = get_parent().get_node_or_null("Carryable")

var _impact_velocity := Vector3.ZERO
var _armed := false
var _armed_until := INF
var _kick_damage := 0
var _kicked_until := -INF
var _sound_wait := SETTLE_TIME


func _ready() -> void:
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.body_entered.connect(_on_body_entered)
	if _carryable:
		_carryable.released.connect(_on_released)


func _physics_process(delta: float) -> void:
	_impact_velocity = _body.linear_velocity
	_sound_wait -= delta


func get_impact_velocity() -> Vector3:
	return _impact_velocity


func arm(by: Node3D = null, seconds := 1.5, kick_damage := 0) -> void:
	_armed = true
	_kick_damage = kick_damage
	_armed_until = Time.get_ticks_msec() / 1000.0 + seconds if seconds > 0.0 else INF
	_kicked_until = _armed_until if kick_damage > 0 else -INF
	if by:
		_body.set_meta(HandSlot.RELEASED_BY_META, by)
		_body.set_meta(HandSlot.RELEASED_AT_META, Time.get_ticks_msec() / 1000.0)


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
	if speed < speed_threshold or Time.get_ticks_msec() / 1000.0 < _kicked_until:
		return
	var excess := speed - speed_threshold
	if _destructible:
		_destructible.damage(int(excess * damage_per_speed))
	_deal_damage_to(body, excess)


func _play_impact(body: Node, speed: float) -> void:
	if speed < sound_min_speed or _sound_wait > 0.0:
		return
	_sound_wait = SOUND_GAP
	var loudness := clampf(
		inverse_lerp(sound_min_speed, sound_full_speed, speed), 0.12, 1.0
	)
	var health := Health.find_in(body)
	var hit_body := speed >= speed_threshold and health != null and health.is_alive()
	Sfx.play_at(
		body_hit_sound if hit_body else impact_sound, _body.global_position, linear_to_db(loudness)
	)


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
	if _destructible:
		_destructible.damage(kick_hit_wear)


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
	info.knockback = _body.mass * _impact_velocity.length()
	health.apply_damage(info)
