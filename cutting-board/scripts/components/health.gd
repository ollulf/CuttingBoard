class_name Health
extends Node

signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal changed(current: int, maximum: int)
signal emptied(info: DamageInfo)

@export var max_health := 100
@export var invulnerable := false
@export var invincible := false

var _current: int


func _ready() -> void:
	_current = max_health


func get_current() -> int:
	return _current


func is_alive() -> bool:
	return _current > 0


func get_ratio() -> float:
	return float(_current) / maxf(float(max_health), 1.0)


func apply_damage(info: DamageInfo) -> void:
	if info == null or info.amount <= 0 or invulnerable or not is_alive():
		return
	_current = maxi(_current - info.amount, 0)
	changed.emit(_current, max_health)
	if _current == 0 and not invincible:
		emptied.emit(info)
	damaged.emit(info)
	if invincible:
		reset()
		return
	if _current == 0:
		died.emit(info)


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	_current = mini(_current + amount, max_health)
	changed.emit(_current, max_health)


func set_pool(current: int, maximum: int) -> void:
	maximum = maxi(maximum, 1)
	current = clampi(current, 0, maximum)
	if current == _current and maximum == max_health:
		return
	max_health = maximum
	_current = current
	changed.emit(_current, max_health)


func reset() -> void:
	_current = max_health
	changed.emit(_current, max_health)


static func find_in(node: Node) -> Health:
	if node == null or not is_instance_valid(node):
		return null
	node = HumanBody.actor_of(node)
	var direct := node.get_node_or_null("Health") as Health
	if direct:
		return direct
	for child in node.get_children():
		if child is Health:
			return child
	return null


static func is_node_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var health := find_in(node)
	return health == null or health.is_alive()
