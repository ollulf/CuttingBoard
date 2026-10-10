extends Node3D

const TREES := [
	"tree_1_large", "tree_1_slim", "tree_1_strange", "tree_2_large",
	"tree_2_slim", "tree_3_large", "tree_3_slim", "tree_4_large",
]
const SPACING := 30.0
const WALKER_RADIUS := 0.4

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var nav_region := _build_floor()
	var trees: Array[Node3D] = []
	for i in TREES.size():
		var tree: Node3D = load("res://scenes/environment/foliage/trees/%s.tscn" % TREES[i]).instantiate()
		add_child(tree)
		tree.transform = Transform3D(Basis(Vector3.UP, 0.7 * i).scaled(Vector3.ONE * 0.9), Vector3(i * SPACING, 0, 0))
		trees.append(tree)
	await _physics_frames(3)

	for tree in trees:
		var shapes := tree.find_children("*", "CollisionShape3D", true, false)
		_check("%s has exactly one primitive trunk shape" % tree.name,
			shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is CylinderShape3D)

	for tree in trees:
		var trunk := _trunk_of(tree)
		var walker := _walker(trunk.center + Vector3(trunk.radius + 6.0, 0, 0))
		await _walk(walker, Vector3.LEFT, 3.0)
		var gap := _flat(walker.global_position - trunk.center).length()
		_check("%s stops a walker at the bark (centre %.2f m away, trunk %.2f m)" % [tree.name, gap, trunk.radius],
			gap > trunk.radius + WALKER_RADIUS - 0.05 and walker.global_position.x > trunk.center.x)
		walker.free()

		var hit := _ray(trunk.center + Vector3(trunk.radius + 2.0, 1.2, 0), trunk.center + Vector3(0, 1.2, 0))
		_check("%s is hit by a melee-height ray" % tree.name,
			not hit.is_empty() and (hit.collider as Node).get_parent() == tree)

	var hidden := trees[1]
	hidden.process_mode = Node.PROCESS_MODE_DISABLED
	await _physics_frames(2)
	var hidden_trunk := _trunk_of(hidden)
	var walker := _walker(hidden_trunk.center + Vector3(hidden_trunk.radius + 4.0, 0, 0))
	await _walk(walker, Vector3.LEFT, 2.0)
	_check("a switched-off (off-screen) tree still blocks",
		walker.global_position.x > hidden_trunk.center.x + hidden_trunk.radius)
	walker.free()
	hidden.process_mode = Node.PROCESS_MODE_INHERIT

	var big := _trunk_of(trees[3])
	var ball := RigidBody3D.new()
	var ball_shape := CollisionShape3D.new()
	ball_shape.shape = SphereShape3D.new()
	(ball_shape.shape as SphereShape3D).radius = 0.15
	ball.add_child(ball_shape)
	add_child(ball)
	ball.global_position = big.center + Vector3(big.radius + 3.0, 1.2, 0)
	ball.linear_velocity = Vector3(-12, 1, 0)
	await _wait(0.8)
	_check("a thrown ball bounces off the trunk",
		ball.global_position.x > big.center.x + big.radius - 0.05)

	nav_region.bake_navigation_mesh(false)
	await TestWorld.nav_synced(nav_region, Vector3(-5, 0, 0))
	var map := get_world_3d().navigation_map
	for tree in trees:
		var trunk := _trunk_of(tree)
		var nearest := NavigationServer3D.map_get_closest_point(map, trunk.center)
		var gap := _flat(nearest - trunk.center).length()
		_check("%s cuts a hole in the baked navmesh (nearest walkable %.2f m from centre)" % [tree.name, gap],
			gap > trunk.radius + 0.2)
	var path := NavigationServer3D.map_get_path(map, Vector3(-5, 0, 0), Vector3((TREES.size() - 1) * SPACING + 5, 0, 0), true)
	_check("a path along the row of trees exists (%d points)" % path.size(), path.size() > 2)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _build_floor() -> NavigationRegion3D:
	var floor_body := StaticBody3D.new()
	floor_body.add_to_group(&"navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 60)
	shape.shape = box
	shape.position = Vector3(100, -0.5, 0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 60)
	mesh.mesh = plane
	mesh.position = Vector3(100, 0, 0)
	floor_body.add_child(mesh)
	add_child(floor_body)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.3
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)
	return region


func _trunk_of(tree: Node3D) -> Dictionary:
	var shape: CollisionShape3D = tree.find_children("*", "CollisionShape3D", true, false)[0]
	var cylinder := shape.shape as CylinderShape3D
	var scale := shape.global_basis.get_scale().x
	var center := shape.global_position
	center.y = tree.global_position.y
	return {center = center, radius = cylinder.radius * scale}


func _walker(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = WALKER_RADIUS
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	add_child(body)
	body.global_position = at + Vector3.UP * 0.05
	return body


func _walk(body: CharacterBody3D, direction: Vector3, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		body.velocity = direction * 5.0 + Vector3.DOWN * 2.0
		body.move_and_slide()
		left -= delta


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
