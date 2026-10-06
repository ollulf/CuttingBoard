class_name Stamina
extends Node

## Breath for anything that runs, jumps and swings. Actions pay for themselves with
## try_spend() (all or nothing) or drain() (a little every frame, for a sprint); after a
## short rest since the last spend it fills back up on its own. It only keeps the
## count: what an empty pool means — no sprint, no jump, no blow — is up to the owner.
## Runs on game time, so a paused game does not refill it.

signal changed(current: float, maximum: float)

@export var max_stamina := 100.0
## Seconds after the latest spend before it starts filling again.
@export var regen_delay := 1.0
## Stamina regained per second once it fills again.
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


## What is left as a fraction of the maximum, 0..1.
func get_ratio() -> float:
	return _current / maxf(max_stamina, 0.001)


func is_full() -> bool:
	return _current >= max_stamina


func can_spend(amount: float) -> bool:
	return _current >= amount


## Pays `amount` if there is that much, and refuses (touching nothing) if there is not.
func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_spend(amount)
	return true


## Takes up to `amount`, as much as is left, for something paid by the frame. Returns
## false once the pool is empty, which is the owner's cue to stop.
func drain(amount: float) -> bool:
	_spend(minf(amount, _current))
	return _current > 0.0


## Puts it back to full, e.g. on a respawn.
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
