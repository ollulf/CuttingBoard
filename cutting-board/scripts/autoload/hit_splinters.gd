extends Node

## Wood splinters off every creature that takes a hit, since every creature is wood.
##
## Like DamageNumbers, nothing has to opt in: this watches the scene tree and hooks every
## Health as it appears. The spray itself is a small BreakBurst, the same debris the break
## effect uses, set up from the hit instead of from a whole object coming apart.

const BURST_SCENE := preload("res://scenes/vfx/break_burst.tscn")

## How far above a victim's own origin the spray starts when the hit did not say where
## it landed.
@export var fallback_height := 1.2


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# See DamageNumbers: the starting level was added before this was listening.
	_hook_tree(get_tree().root)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node is Health:
		var handler := _on_health_damaged.bind(node)
		if not (node as Health).damaged.is_connected(handler):
			(node as Health).damaged.connect(handler)


func _on_health_damaged(info: DamageInfo, health: Health) -> void:
	if info.amount <= 0:
		return
	var body := health.get_parent() as Node3D
	var scene := get_tree().current_scene
	if body == null or scene == null:
		return
	# Not on whoever the camera looks out of: in first person the spray would fill the view.
	var camera := get_viewport().get_camera_3d()
	if camera != null and body.is_ancestor_of(camera):
		return
	var at := info.position
	if at.is_zero_approx():
		at = body.global_position + Vector3.UP * fallback_height
	var burst := BURST_SCENE.instantiate() as BreakBurst
	burst.setup_hit(body, at, info.direction, info.amount)
	scene.add_child(burst)
