extends SceneTree

const OUT_DIR := "res://assets/meshes/props/"

var uv_scale := 4.0
var mesh_scale := 1.0
var _triangles := 0


func _lathe(tool: SurfaceTool, profile: Array[Vector2], sides: int, at: Transform3D) -> void:
	for k in profile.size() - 1:
		var a := profile[k]
		var b := profile[k + 1]
		var out := Vector2(b.y - a.y, a.x - b.x)
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var mid := (t0 + t1) * 0.5
			var facing := Vector3(cos(mid) * out.x, out.y, sin(mid) * out.x)
			var corners: Array = []
			for point in [[a, t0], [a, t1], [b, t1], [b, t0]]:
				var p: Vector2 = point[0]
				var t: float = point[1]
				var corner := Vector3(cos(t) * p.x, p.y, sin(t) * p.x)
				if p.x < 0.0001 and not corners.is_empty() and corners.back().is_equal_approx(at * corner):
					continue
				corners.append(at * corner)
			_face(tool, corners, at.basis.inverse().transposed() * facing)


func _face(tool: SurfaceTool, corners: Array, facing: Vector3) -> void:
	if corners.size() < 3:
		return
	var first: Vector3 = corners[0]
	var normal := (corners[1] - first).cross(corners[2] - first).normalized() as Vector3
	if normal.is_zero_approx():
		return
	if normal.dot(facing) < 0.0:
		corners.reverse()
		normal = -normal
	var order := [0, 2, 1] if corners.size() == 3 else [0, 2, 1, 0, 3, 2]
	for index in order:
		var corner: Vector3 = corners[index] * mesh_scale
		tool.set_normal(normal)
		tool.set_uv(_uv(corner, normal))
		tool.add_vertex(corner)
	_triangles += order.size() / 3


func _uv(point: Vector3, normal: Vector3) -> Vector2:
	var n := normal.abs()
	if n.x >= n.y and n.x >= n.z:
		return Vector2(point.z, -point.y) * uv_scale
	if n.y >= n.z:
		return Vector2(point.z, point.x) * uv_scale
	return Vector2(point.x, -point.y) * uv_scale


func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


func _commit(mesh: ArrayMesh, tool: SurfaceTool, material: Material) -> void:
	tool.index()
	tool.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func _save(mesh: ArrayMesh, file: String) -> bool:
	var path := OUT_DIR + file
	var error := ResourceSaver.save(mesh, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		return false
	print("Built %s with %d triangles." % [path, _triangles])
	_triangles = 0
	return true
