extends Node

const NUMBER_SCENE := preload("res://scenes/vfx/damage_number.tscn")

const HEALTH_COLOR := Color(1.0, 0.85, 0.35)
const DURABILITY_COLOR := Color(0.7, 0.78, 0.9)

@export var fallback_height := 1.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node is Health:
		_hook((node as Health).damaged, _on_health_damaged.bind(node))
	elif node is Destructible:
		_hook((node as Destructible).damaged, _on_durability_lost)


func _hook(source: Signal, handler: Callable) -> void:
	if not source.is_connected(handler):
		source.connect(handler)


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
	if info.silent:
		return
	show_damage(info.amount, _hit_position(info, health), HEALTH_COLOR)


func _on_durability_lost(amount: int, at: Vector3) -> void:
	show_damage(amount, at, DURABILITY_COLOR)


func _hit_position(info: DamageInfo, health: Health) -> Vector3:
	if not info.position.is_zero_approx():
		return info.position
	var owner_node := health.get_parent() as Node3D
	if owner_node == null:
		return Vector3.ZERO
	return owner_node.global_position + Vector3.UP * fallback_height
