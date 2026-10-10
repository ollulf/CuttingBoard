class_name Kickable
extends Node

@export_range(0.0, 4.0, 0.05) var force_multiplier := 1.0
@export var kick_wears := true


static func find_in(node: Node) -> Kickable:
	return node.get_node_or_null("Kickable") as Kickable if node else null
