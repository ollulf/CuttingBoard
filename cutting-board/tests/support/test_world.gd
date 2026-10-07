class_name TestWorld
extends RefCounted

## Shared set-up for the headless checks that need ground to stand on and a navmesh to
## walk it: solid slabs, a navigation region baked from them, and the waits that let the
## navigation map catch up with a bake. Every check used to carry its own copy of these.

## The group the slabs join, and that the region bakes its navmesh from.
const NAV_SOURCE := &"navigation_source"


## Waits `count` physics frames of the tree `node` is in.
static func physics_frames(node: Node, count: int) -> void:
	for i in count:
		await node.get_tree().physics_frame


## A solid box of `size` centred on `center`, added under `parent` and taken into the
## navmesh bake.
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


## A flat floor `extent` metres square whose top is at y = 0.
static func add_floor(parent: Node, extent: float) -> StaticBody3D:
	return add_slab(parent, Vector3(extent, 1, extent), Vector3(0, -0.5, 0))


## A navigation region, sized for the NPCs, that bakes from every slab. Not baked yet.
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


## Bakes `region` on the spot and waits until the navigation map has moved on from it,
## or 120 physics frames.
static func bake(region: NavigationRegion3D) -> void:
	region.bake_navigation_mesh(false)
	var map := region.get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await region.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			break


## Waits until the navigation map has really picked up the freshly baked region: the
## bake is done, the region is on the map, `probe` snaps onto its navmesh, and the map
## has synced twice more after that. Under CPU load (parallel test runs) the map sync
## lags behind the physics frames, so this polls real conditions with a wall-time limit.
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
