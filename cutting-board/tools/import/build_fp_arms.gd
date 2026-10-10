extends SceneTree

const Body := preload("res://tools/import/build_human_body.gd")

const OUT_MESHES := {
	"Right": "res://assets/meshes/characters/fp_arm_right.res",
	"Left": "res://assets/meshes/characters/fp_arm_left.res",
}

const HAND_SLOT := Vector3(0.0, 0.0, -0.3)
const PALM_FROM_FINGERTIPS := 0.11
const UPPER_ARM_KEPT := 0.3
const VIEW_SCALE := 1.15
const WRIST_FROM_FINGERTIPS := 0.19
const ELBOW_BLEND := 0.05
const WRIST_BLEND := 0.03

enum Bone { UPPER_ARM, FOREARM, HAND }

var _parent := PackedInt32Array()


func _init() -> void:
	var source := load(Body.SOURCE_MESH) as ArrayMesh
	if source == null:
		push_error("Could not load %s" % Body.SOURCE_MESH)
		quit(1)
		return
	for side: String in OUT_MESHES:
		var mesh := _build_arm(source, side)
		if mesh == null:
			quit(1)
			return
		var error := ResourceSaver.save(mesh, OUT_MESHES[side])
		if error != OK:
			push_error("Could not save %s: %s" % [OUT_MESHES[side], error_string(error)])
			quit(1)
			return
		print("Built %s with %d triangles." % [OUT_MESHES[side], mesh.surface_get_array_index_len(0) / 3])
	quit()


func _build_arm(source: ArrayMesh, side: String) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var mirror := Vector3(1.0 if side == "Right" else -1.0, 1.0, 1.0)
	var elbow := Body.ELBOW * mirror
	var fingertips := Body.FINGERTIPS * mirror

	var turn := Basis(Vector3.UP, PI)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in vertices.size():
		vertices[i] = turn * vertices[i] * Body.MODEL_SCALE
		normals[i] = turn * normals[i]

	var down := (fingertips - elbow).normalized()
	var front := (Vector3.FORWARD - down * Vector3.FORWARD.dot(down)).normalized()
	var to_view := Basis(down.cross(front), front, -down).inverse()
	var palm := fingertips - down * PALM_FROM_FINGERTIPS
	var to_arm := Transform3D(Basis.from_scale(Vector3.ONE * VIEW_SCALE), HAND_SLOT) \
			* Transform3D(to_view, Vector3.ZERO) * Transform3D(Basis(), -palm)

	var elbow_at := to_arm * elbow
	var wrist_at := to_arm * (fingertips - down * WRIST_FROM_FINGERTIPS)
	var shoulder_at := to_arm * (elbow - down * UPPER_ARM_KEPT)
	print("%s bones: UpperArm %s, Forearm %s, Hand %s" % [side, shoulder_at, elbow_at, wrist_at])

	var arm_root := _arm_piece(vertices, indices, side)
	if arm_root < 0:
		push_error("No %s arm piece found in %s" % [side.to_lower(), Body.SOURCE_MESH])
		return null

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[PackedVector3Array] = []
	for t in range(0, indices.size(), 3):
		if _find(indices[t]) != arm_root:
			continue
		var points: Array[Vector3] = []
		var point_normals: Array[Vector3] = []
		var cut_from := -1
		for k in 3:
			var i := indices[t + k]
			var j := indices[t + (k + 1) % 3]
			var here := _kept_depth(vertices[i], elbow, down)
			var next := _kept_depth(vertices[j], elbow, down)
			if here >= 0.0:
				points.append(vertices[i])
				point_normals.append(normals[i])
			if (here >= 0.0) != (next >= 0.0):
				var w := here / (here - next)
				if here >= 0.0:
					cut_from = points.size()
				points.append(vertices[i].lerp(vertices[j], w))
				point_normals.append(normals[i].lerp(normals[j], w).normalized())
		if points.size() < 3:
			continue
		if cut_from >= 0:
			rim.append(PackedVector3Array([points[cut_from], points[(cut_from + 1) % points.size()]]))
		for k in range(1, points.size() - 1):
			for index in [0, k, k + 1]:
				var at: Vector3 = to_arm * points[index]
				_set_skin(tool, at, elbow_at, wrist_at)
				tool.set_normal((to_view * point_normals[index]).normalized())
				tool.add_vertex(at)

	var centre := Vector3.ZERO
	for edge in rim:
		centre += edge[0]
	centre /= maxf(rim.size(), 1.0)
	var cap_normal := (to_view * -down).normalized()
	for edge in rim:
		for point in [edge[1], edge[0], centre]:
			var at: Vector3 = to_arm * point
			_set_skin(tool, at, elbow_at, wrist_at)
			tool.set_normal(cap_normal)
			tool.add_vertex(at)
	tool.index()
	return tool.commit()


func _set_skin(tool: SurfaceTool, at: Vector3, elbow_at: Vector3, wrist_at: Vector3) -> void:
	var past_elbow := smoothstep(elbow_at.z + ELBOW_BLEND, elbow_at.z - ELBOW_BLEND, at.z)
	var past_wrist := smoothstep(wrist_at.z + WRIST_BLEND, wrist_at.z - WRIST_BLEND, at.z)
	tool.set_bones(PackedInt32Array([Bone.UPPER_ARM, Bone.FOREARM, Bone.HAND, 0]))
	tool.set_weights(PackedFloat32Array([
		1.0 - past_elbow, past_elbow * (1.0 - past_wrist), past_elbow * past_wrist, 0.0]))


func _kept_depth(point: Vector3, elbow: Vector3, down: Vector3) -> float:
	return (point - elbow).dot(down) + UPPER_ARM_KEPT


func _arm_piece(vertices: PackedVector3Array, indices: PackedInt32Array, side: String) -> int:
	_parent.resize(vertices.size())
	for i in vertices.size():
		_parent[i] = i
	var at_position := {}
	for i in vertices.size():
		var key := vertices[i].snappedf(0.0001)
		if at_position.has(key):
			_parent[_find(i)] = _find(at_position[key])
		else:
			at_position[key] = i
	for t in range(0, indices.size(), 3):
		_parent[_find(indices[t])] = _find(indices[t + 1])
		_parent[_find(indices[t + 1])] = _find(indices[t + 2])

	var sums := {}
	var counts := {}
	for i in vertices.size():
		var root := _find(i)
		sums[root] = sums.get(root, Vector3.ZERO) + vertices[i]
		counts[root] = counts.get(root, 0) + 1
	var sign := 1.0 if side == "Right" else -1.0
	for root: int in sums:
		var centre: Vector3 = sums[root] / counts[root]
		if centre.x * sign > 0.15 and centre.y > Body.LEG_TOP:
			return root
	return -1


func _find(i: int) -> int:
	while _parent[i] != i:
		i = _parent[i]
	return i
