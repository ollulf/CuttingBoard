class_name Cheats
extends RefCounted

static var infinite_health := false
static var no_aggro := false

static var _player: WeakRef


static func register_player(player: Node3D) -> void:
	_player = weakref(player)


static func get_player() -> Node3D:
	return _player.get_ref() as Node3D if _player else null


static func is_player(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var player := get_player()
	return player != null and node == player


static func shields_from_damage(node: Node) -> bool:
	return infinite_health and is_player(node)


static func hides_from_enemies(node: Node) -> bool:
	return no_aggro and is_player(node)


static func set_no_aggro(on: bool, tree: SceneTree) -> void:
	no_aggro = on
	if on and tree:
		calm_enemies(tree)


static func calm_enemies(tree: SceneTree) -> void:
	var player := get_player()
	if player == null:
		return
	for actor in tree.get_nodes_in_group(Faction.GROUP):
		if actor != player and actor.has_method("forget_target"):
			actor.forget_target(player)
