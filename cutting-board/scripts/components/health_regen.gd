class_name HealthRegen
extends Node

@export var delay := 7.0
@export var rate := 2.5

var _health: Health
var _quiet := 0.0
var _pending := 0.0


func _ready() -> void:
	_health = Health.find_in(get_parent())
	if _health:
		_health.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	if _health == null or not _health.is_alive():
		return
	if _in_combat():
		_interrupt()
		return
	_quiet += delta
	if _quiet < delay or _health.get_current() >= _health.max_health:
		_pending = 0.0
		return
	_pending += rate * delta
	var whole := int(_pending)
	if whole > 0:
		_pending -= whole
		_health.heal(whole)


func is_regenerating() -> bool:
	return (_health != null and _health.is_alive() and _quiet >= delay
			and _health.get_current() < _health.max_health and not _in_combat())


func _in_combat() -> bool:
	var owner_node := get_parent()
	return owner_node != null and owner_node.has_method("is_in_combat") and owner_node.is_in_combat()


func _interrupt() -> void:
	_quiet = 0.0
	_pending = 0.0


func _on_damaged(_info: DamageInfo) -> void:
	_interrupt()
