extends SceneTree

## What the prop mesh builders share (build_wood_glue.gd, build_soul_bottle.gd and
## build_saw.gd extend this): flat-shaded faces with box-projected UVs, a lathe that turns
## a profile into a solid, and saving the finished ArrayMesh. Each builder sets the scale
## and texture density it wants in its _init before building.

const OUT_DIR := "res://assets/meshes/props/"

## How many times a texture repeats per metre of surface.
var uv_scale := 4.0
## Every corner is multiplied by this as it is written, so a builder can lay its tables
## out at life size and still sit right in the larger-than-life hands.
var mesh_scale := 1.0
## Triangles written since the last save, for the log line.
var _triangles := 0


## Turns `profile` round the Y axis in `sides` flat faces and places it with `at`.
## A point on the axis closes that end with a fan instead of a ring of slivers.
func _lathe(tool: SurfaceTool, profile: Array[Vector2], sides: int, at: Transform3D) -> void:
	for k in profile.size() - 1:
		var a := profile[k]
		var b := profile[k + 1]
		# The profile's tangent turned a quarter clockwise points out of the surface.
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


## One flat triangle or quad, turned to face `facing`, so a shape only needs its corners
## listed in a consistent order rather than each face wound by hand.
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
	# Godot draws clockwise triangles as front faces.
	var order := [0, 2, 1] if corners.size() == 3 else [0, 2, 1, 0, 3, 2]
	for index in order:
		var corner: Vector3 = corners[index] * mesh_scale
		tool.set_normal(normal)
		tool.set_uv(_uv(corner, normal))
		tool.add_vertex(corner)
	_triangles += order.size() / 3


## Projects the texture along whichever axis the face looks down most.
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


## Saves `mesh` as OUT_DIR + `file` and logs its triangle count. False when it could not.
func _save(mesh: ArrayMesh, file: String) -> bool:
	var path := OUT_DIR + file
	var error := ResourceSaver.save(mesh, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		return false
	print("Built %s with %d triangles." % [path, _triangles])
	_triangles = 0
	return true
