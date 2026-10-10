extends Node3D

const LANTERN_POST := preload("res://scenes/environment/decoration/lantern_post.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var post := LANTERN_POST.instantiate()
	add_child(post)
	var swing := post.get_node("%Swing") as LampSwing
	_check("lantern post has a LampSwing pivot", swing != null)
	if swing == null:
		_finish()
		return
	var lantern := swing.get_node("LampBody") as Node3D
	var aabb := _mesh_aabb(lantern)
	print("lantern AABB (post space): ", aabb)
	var arm_start: Transform3D = post.get_node("Arm").global_transform
	var post_mesh_start: Transform3D = post.get_node("Post").global_transform
	var light_start: Vector3 = (swing.get_node("Light") as Node3D).global_position
	var min_a := INF
	var max_a := 0.0
	var light_moved := 0.0
	for i in 240:
		await get_tree().process_frame
		var a := swing.current_angle()
		min_a = minf(min_a, a)
		max_a = maxf(max_a, a)
		light_moved = maxf(light_moved, (swing.get_node("Light") as Node3D).global_position.distance_to(light_start))
	print("angle range over 4 s: %.2f..%.2f deg, light moved up to %.3f m" % [min_a, max_a, light_moved])
	_check("pivot rotation changes over time", max_a - min_a > 1.0)
	_check("swing stays within the limit", max_a <= swing.max_angle * 1.1 + 0.01)
	_check("light swings along, but only a little", light_moved > 0.005 and light_moved < 0.25)
	_check("post stays still", post.get_node("Post").global_transform.is_equal_approx(post_mesh_start))
	_check("bracket arm stays still", post.get_node("Arm").global_transform.is_equal_approx(arm_start))
	_finish()


func _mesh_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for n in [root] + root.find_children("*", "MeshInstance3D", true, false):
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		var b := (get_child(0) as Node3D).global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _finish() -> void:
	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)
