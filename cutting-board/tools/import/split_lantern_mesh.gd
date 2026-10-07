extends SceneTree

## One-off tool: splits the single "Lantern" mesh of lantern.glb into the fixed bracket arm
## and the hanging lamp body, so only the lamp swings (LampSwing on lantern_post.tscn).
## Triangles are assigned by their centroid (in the glb scene root's space); see BODY_MAX_*.
## Pass "-- --dump" to print the vertex layout instead of writing.
##
##   godot --headless --path cutting-board -s res://tools/import/split_lantern_mesh.gd

const SOURCE := "res://assets/meshes/props/lantern.glb"
const ARM_OUT := "res://assets/meshes/props/lantern_arm.res"
const BODY_OUT := "res://assets/meshes/props/lantern_body.res"
## Lamp body: everything hanging below the arm tip (z < BODY_MAX_Z) and under the hook (y < BODY_MAX_Y).
const BODY_MAX_Z := -0.75
const BODY_MAX_Y := -0.1


func _init() -> void:
	var scene := (load(SOURCE) as PackedScene).instantiate() as Node3D
	# The glb imports as a single MeshInstance3D root (lantern.tscn overrides its materials).
	var mi := scene as MeshInstance3D
	if mi == null:
		mi = scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var xf := _xform_to_root(mi, scene)
	print("root xf ", scene.transform, "  mesh node ", mi.name, " xf ", xf)
	var mesh := mi.mesh
	var dump := "--dump" in OS.get_cmdline_user_args()
	var arm := ArrayMesh.new()
	var body := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if dump:
			var rows := {}
			for v in verts:
				var p := xf * v
				var k := snappedf(p.y, 0.05)
				if not rows.has(k):
					rows[k] = [0, INF, -INF, 0.0]
				var r: Array = rows[k]
				r[0] += 1
				r[1] = minf(r[1], p.z)
				r[2] = maxf(r[2], p.z)
				r[3] = maxf(r[3], absf(p.x))
			var keys := rows.keys()
			keys.sort()
			for k in keys:
				var r: Array = rows[k]
				print("surf %d y=%.2f n=%d z %.2f..%.2f |x|<=%.2f" % [s, k, r[0], r[1], r[2], r[3]])
			continue
		var parts := [PackedInt32Array(), PackedInt32Array()]
		for t in range(0, idx.size(), 3):
			var c := (verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0
			var pc := xf * c
			var part := 1 if pc.z < BODY_MAX_Z and pc.y < BODY_MAX_Y else 0
			for j in 3:
				parts[part].append(idx[t + j])
		for p in 2:
			if parts[p].is_empty():
				continue
			var a := arrays.duplicate()
			a[Mesh.ARRAY_INDEX] = parts[p]
			var target: ArrayMesh = arm if p == 0 else body
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			target.surface_set_material(target.get_surface_count() - 1, mesh.surface_get_material(s))
			print("surface %d -> %s: %d tris" % [s, "arm" if p == 0 else "body", parts[p].size() / 3])
	if not dump:
		print("arm aabb ", xf * arm.get_aabb(), "  body aabb ", xf * body.get_aabb())
		ResourceSaver.save(arm, ARM_OUT)
		ResourceSaver.save(body, BODY_OUT)
	scene.free()
	quit()


func _xform_to_root(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
