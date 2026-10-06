extends SceneTree

## Builds the soul in a bottle's mesh (the spirit of a mask, caught by the Mask-Monger):
## a corked glass vial, round-bellied, a dab of red wax sealing the cork. The soul itself
## is not part of the mesh: it is the swirl sphere in scenes/items/soul_bottle.tscn,
## floating in the vial's hollow round the origin.
##
## Built the same way as the wood glue (scripts/import/build_wood_glue.gd): lathed
## profiles, flat shaded, laid out the way a HandSlot holds things.
##
##   godot --headless --path cutting-board -s res://scripts/import/build_soul_bottle.gd

const OUT_DIR := "res://assets/meshes/props/"
const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")

## The glass's faint inner glow.
const SOUL := Color(0.62, 1.0, 0.82)

## Profiles are (radius, height) pairs in metres, from the bottom up the outside and back
## down the inside, as on the wood glue. The vial is lowered by BELLY so the middle of
## its hollow, where the soul floats, is at the origin.
const BELLY := 0.05

const VIAL_SIDES := 9
const VIAL_GLASS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.026, 0.002), Vector2(0.037, 0.022), Vector2(0.039, 0.055),
	Vector2(0.03, 0.085), Vector2(0.015, 0.098), Vector2(0.014, 0.118), Vector2(0.018, 0.122),
	Vector2(0.0, 0.122),
]
const VIAL_CORK: Array[Vector2] = [
	Vector2(0.0, 0.11), Vector2(0.0125, 0.11), Vector2(0.0145, 0.132), Vector2(0.0135, 0.14),
	Vector2(0.0, 0.141),
]
const VIAL_SEAL: Array[Vector2] = [
	Vector2(0.0, 0.112), Vector2(0.02, 0.112), Vector2(0.021, 0.118), Vector2(0.0, 0.119),
]

## Texture repeats per metre, as on the wood glue.
const UV_SCALE := 4.0
## Scaled up like the wood glue, to sit in the larger-than-life hands at the same size.
const SIZE := 1.6

var _triangles := 0


func _init() -> void:
	quit(0 if _save(_build_vial(), "soul_bottle.res") else 1)


## A corked glass vial, a dab of wax over the cork.
func _build_vial() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -BELLY, 0.0))
	var cork := _begin()
	_lathe(cork, VIAL_CORK, 6, down)
	_commit(mesh, cork, WOOD)
	var seal := _begin()
	_lathe(seal, VIAL_SEAL, 7, down)
	_commit(mesh, seal, _wax())
	var glass := _begin()
	_lathe(glass, VIAL_GLASS, VIAL_SIDES, down)
	_commit(mesh, glass, _glass())
	return mesh


func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.72, 0.92, 0.9, 0.25)
	glass.roughness = 0.08
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.emission_enabled = true
	glass.emission = SOUL * 0.12
	return glass


func _wax() -> StandardMaterial3D:
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.62, 0.16, 0.14)
	wax.roughness = 0.5
	return wax


## Turns `profile` round the Y axis in `sides` flat faces and places it with `at`, as on
## the wood glue.
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


## One flat triangle or quad, turned to face `facing`, as on the saw.
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
		var corner: Vector3 = corners[index] * SIZE
		tool.set_normal(normal)
		tool.set_uv(_uv(corner, normal))
		tool.add_vertex(corner)
	_triangles += order.size() / 3


## Projects the texture along whichever axis the face looks down most.
func _uv(point: Vector3, normal: Vector3) -> Vector2:
	var n := normal.abs()
	if n.x >= n.y and n.x >= n.z:
		return Vector2(point.z, -point.y) * UV_SCALE
	if n.y >= n.z:
		return Vector2(point.z, point.x) * UV_SCALE
	return Vector2(point.x, -point.y) * UV_SCALE


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
