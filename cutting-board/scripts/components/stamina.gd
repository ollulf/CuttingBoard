class_name Stamina
extends Node

signal changed(current: float, maximum: float)

@export var max_stamina := 100.0
@export var regen_delay := 1.0
@export var regen_rate := 25.0

var _current: float
var _rest := 0.0


func _ready() -> void:
	_current = max_stamina


func _physics_process(delta: float) -> void:
	_rest += delta
	if _rest < regen_delay or _current >= max_stamina:
		return
	_set_current(_current + regen_rate * delta)


func get_current() -> float:
	return _current


func get_ratio() -> float:
	return _current / maxf(max_stamina, 0.001)


func is_full() -> bool:
	return _current >= max_stamina


func can_spend(amount: float) -> bool:
	return _current >= amount


func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_spend(amount)
	return true


func drain(amount: float) -> bool:
	_spend(minf(amount, _current))
	return _current > 0.0


func reset() -> void:
	_rest = regen_delay
	_set_current(max_stamina)


func _spend(amount: float) -> void:
	_rest = 0.0
	if amount > 0.0:
		_set_current(_current - amount)


func _set_current(value: float) -> void:
	value = clampf(value, 0.0, max_stamina)
	if is_equal_approx(value, _current):
		_current = value
		return
	_current = value
	changed.emit(_current, max_stamina)
