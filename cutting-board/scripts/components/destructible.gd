class_name Destructible
extends Node

signal destroyed
signal damaged(amount: int, at: Vector3)

const MAX_DURABILITY := 9999

@export var indestructible := false
@export_range(0, 9999) var durability := 100
@export var break_sound: SoundBank = preload("res://resources/audio/break_wood.tres")
@export var break_effect: PackedScene = preload("res://scenes/vfx/break_burst.tscn")


func _ready() -> void:
	if indestructible:
		durability = MAX_DURABILITY


static func read(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	var component := node.get_node_or_null("Destructible") as Destructible
	return component.durability if component else -1


static func write(node: Node, durability: int) -> void:
	if durability < 0 or node == null or not is_instance_valid(node):
		return
	var component := node.get_node_or_null("Destructible") as Destructible
	if component and not component.indestructible:
		component.durability = durability


func damage(amount: int, quiet := false) -> void:
	if indestructible or amount <= 0 or durability == 0:
		return
	var lost := mini(amount, durability)
	durability = clampi(durability - amount, 0, MAX_DURABILITY)
	var node := get_parent() as Node3D
	if not quiet:
		damaged.emit(lost, node.global_position if node else Vector3.ZERO)
	if durability == 0:
		if node:
			Sfx.play_at(break_sound, node.global_position)
			_spawn_break_effect(node)
		destroyed.emit()
		get_parent().queue_free()


func _spawn_break_effect(node: Node3D) -> void:
	if break_effect == null or not node.is_inside_tree():
		return
	var effect := break_effect.instantiate() as Node3D
	effect.top_level = true
	if effect is BreakBurst:
		effect.setup(node)
	else:
		effect.position = node.global_position
	var tree := node.get_tree()
	(tree.current_scene if tree.current_scene else tree.root).add_child(effect)
