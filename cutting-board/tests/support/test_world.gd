class_name TestWorld
extends RefCounted

const NAV_SOURCE := &"navigation_source"
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")


static func masked_player(scene: PackedScene) -> Node:
	var player := scene.instantiate()
	(player.get_node("%Equipment") as Equipment).starting_items = [PLAYER_MASK]
	return player


static func physics_frames(node: Node, count: int) -> void:
	for i in count:
		await node.get_tree().physics_frame


static func add_slab(parent: Node, size: Vector3, center: Vector3) -> StaticBody3D:
	var slab := StaticBody3D.new()
	slab.add_to_group(NAV_SOURCE)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	slab.add_child(shape)
	parent.add_child(slab)
	return slab


static func add_floor(parent: Node, extent: float) -> StaticBody3D:
	return add_slab(parent, Vector3(extent, 1, extent), Vector3(0, -0.5, 0))


static func add_nav_region(parent: Node) -> NavigationRegion3D:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = NAV_SOURCE
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	parent.add_child(region)
	return region


static func bake(region: NavigationRegion3D) -> void:
	region.bake_navigation_mesh(false)
	var map := region.get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await region.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			break


static func nav_synced(region: NavigationRegion3D, probe: Vector3) -> void:
	var tree := region.get_tree()
	var map := region.get_world_3d().navigation_map
	var deadline := Time.get_ticks_msec() + 20000
	while region.is_baking() and Time.get_ticks_msec() < deadline:
		await tree.physics_frame
	while Time.get_ticks_msec() < deadline:
		await tree.physics_frame
		if not NavigationServer3D.map_get_regions(map).has(region.get_rid()):
			continue
		var snapped := NavigationServer3D.map_get_closest_point(map, probe)
		if Vector2(snapped.x - probe.x, snapped.z - probe.z).length() < 0.1:
			break
	for i in 2:
		var before := NavigationServer3D.map_get_iteration_id(map)
		while NavigationServer3D.map_get_iteration_id(map) == before \
				and Time.get_ticks_msec() < deadline:
			await tree.physics_frame
	await physics_frames(region, 2)
