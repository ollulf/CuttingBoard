extends SceneTree

## Builds the three concept meshes for the soul in a bottle (the spirit of a mask, caught
## by the Mask-Monger), so the one picked can be swapped into scenes/items/soul_bottle.tscn
## by changing a single path:
##
##   a  a corked glass vial, round-bellied, a dab of wax sealing the cork;
##   b  a carved wooden flask squeezed flat, a window slot cut in its front with a pane of
##      glow leaking out of it;
##   c  a lantern-like jar, a tin lid with a twine loop to carry it by and twine round
##      the neck.
##
## The wisp itself (a little glowing face) is built once, as soul_bottle_wisp.res and
## soul_bottle_eyes.res, and sits in the scene apart from the bottle so it can bob and
## blink. Every bottle leaves the same hollow round the origin for it.
##
## Built the same way as the wood glue (scripts/import/build_wood_glue.gd): lathed
## profiles, flat shaded, laid out the way a HandSlot holds things.
##
##   godot --headless --path cutting-board -s res://scripts/import/build_soul_bottle.gd

const OUT_DIR := "res://assets/meshes/props/"
const LEATHER := preload("res://assets/materials/props/leather.tres")
const PAPER := preload("res://assets/materials/props/waxed_paper.tres")
const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")

## The colour of a caught soul: a warm mint, like a firefly.
const SOUL := Color(0.62, 1.0, 0.82)

## Profiles are (radius, height) pairs in metres, from the bottom up the outside and back
## down the inside, as on the wood glue. Each bottle is lowered by BELLY so the middle of
## its hollow, where the wisp floats, is at the origin.
const BELLY := 0.05

## a: the vial.
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

## b: the flask, squeezed flat across X, its window on the front (+Z, toward whoever holds it).
const FLASK_SIDES := 8
const FLASK_FLATTEN := 0.7
const FLASK_BODY: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.036, 0.0), Vector2(0.048, 0.02), Vector2(0.05, 0.035),
	Vector2(0.05, 0.065), Vector2(0.047, 0.085), Vector2(0.03, 0.105), Vector2(0.014, 0.112),
	Vector2(0.013, 0.13), Vector2(0.0, 0.13),
]
## The wall's inside, top down, so its faces look inward through the window.
const FLASK_LINING: Array[Vector2] = [
	Vector2(0.0, 0.1), Vector2(0.044, 0.08), Vector2(0.046, 0.065), Vector2(0.046, 0.035),
	Vector2(0.044, 0.02), Vector2(0.0, 0.006),
]
## The window spans these heights on the front face of the flask.
const FLASK_WINDOW := Vector2(0.035, 0.065)
const FLASK_STOPPER: Array[Vector2] = [
	Vector2(0.0, 0.125), Vector2(0.011, 0.125), Vector2(0.013, 0.145), Vector2(0.008, 0.152),
	Vector2(0.0, 0.153),
]

## c: the jar, its tin lid and the twine.
const JAR_SIDES := 10
const JAR_GLASS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.036, 0.0), Vector2(0.044, 0.01), Vector2(0.045, 0.085),
	Vector2(0.036, 0.096), Vector2(0.034, 0.104), Vector2(0.0, 0.104),
]
const JAR_LID: Array[Vector2] = [
	Vector2(0.0, 0.098), Vector2(0.038, 0.098), Vector2(0.038, 0.11), Vector2(0.03, 0.116),
	Vector2(0.0, 0.117),
]
const JAR_TWINE: Array[Vector2] = [
	Vector2(0.0, 0.088), Vector2(0.039, 0.088), Vector2(0.039, 0.096), Vector2(0.0, 0.096),
]
## The carrying loop over the lid: its radius, how thick the twine is, and in how many
## pieces it is laid.
const LOOP_RADIUS := 0.026
const LOOP_THICK := 0.005
const LOOP_SEGMENTS := 10

## The wisp: a soft drop, round below and drawn to a little curl on top.
const WISP_SIDES := 8
const WISP: Array[Vector2] = [
	Vector2(0.0, -0.018), Vector2(0.012, -0.015), Vector2(0.018, -0.005), Vector2(0.017, 0.006),
	Vector2(0.011, 0.014), Vector2(0.004, 0.022), Vector2(0.0, 0.026),
]

## Texture repeats per metre, as on the wood glue.
const UV_SCALE := 4.0
## Scaled up like the wood glue, to sit in the larger-than-life hands at the same size.
const SIZE := 1.6

var _triangles := 0


func _init() -> void:
	var ok := (
		_save(_build_vial(), "soul_bottle_a.res")
		and _save(_build_flask(), "soul_bottle_b.res")
		and _save(_build_jar(), "soul_bottle_c.res")
		and _save(_build_wisp(), "soul_bottle_wisp.res")
		and _save(_build_face(), "soul_bottle_face.res")
	)
	quit(0 if ok else 1)


## a: a corked glass vial, a dab of wax over the cork.
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


## b: a wooden flask with a window slot in its front; the soul's light shows through a
## pane of glow in the slot and on the lining inside.
func _build_flask() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var squeeze := Transform3D(
		Basis.from_scale(Vector3(FLASK_FLATTEN, 1.0, 1.0)), Vector3(0.0, -BELLY, 0.0)
	)
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -BELLY, 0.0))
	var wood := _begin()
	_lathe(wood, FLASK_BODY, FLASK_SIDES, squeeze, true)
	_lathe(wood, FLASK_STOPPER, 6, down)
	_commit(mesh, wood, WOOD)
	var lining := _begin()
	_lathe(lining, FLASK_LINING, FLASK_SIDES, squeeze)
	_commit(mesh, lining, LEATHER)
	var pane := _begin()
	var front := 0.05 * cos(PI / FLASK_SIDES) - 0.003
	var window := FLASK_WINDOW - Vector2(BELLY, BELLY)
	_box(pane, Vector3(0.0, (window.x + window.y) * 0.5, front), Vector3(0.024, window.y - window.x, 0.0015))
	_commit(mesh, pane, _glow_pane())
	return mesh


## c: a glass jar, a tin lid, twine round its neck and a twine loop to carry it by.
func _build_jar() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -BELLY, 0.0))
	var metal := _begin()
	_lathe(metal, JAR_LID, JAR_SIDES, down)
	_commit(mesh, metal, METAL)
	var twine := _begin()
	_lathe(twine, JAR_TWINE, JAR_SIDES, down)
	# The loop stands up over the lid, a ring of short pieces in the XY plane.
	var middle := JAR_LID[3].y - BELLY + LOOP_RADIUS - 0.003
	var length := TAU * LOOP_RADIUS / LOOP_SEGMENTS + 0.002
	for k in LOOP_SEGMENTS:
		var angle := TAU * (k + 0.5) / LOOP_SEGMENTS
		var at := Vector3(cos(angle) * LOOP_RADIUS * 0.8, middle + sin(angle) * LOOP_RADIUS, 0.0)
		_box(twine, at, Vector3(LOOP_THICK, length, LOOP_THICK), Basis(Vector3.BACK, angle))
	_commit(mesh, twine, PAPER)
	var glass := _begin()
	_lathe(glass, JAR_GLASS, JAR_SIDES, down)
	_commit(mesh, glass, _glass())
	return mesh


## The wisp's body, centred on its own origin; the scene bobs it.
func _build_wisp() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var body := _begin()
	_lathe(body, WISP, WISP_SIDES, Transform3D.IDENTITY)
	_commit(mesh, body, _soul())
	return mesh


## Two eyes and a small smile on the front of the wisp; the scene squashes it to blink.
func _build_face() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var face := _begin()
	var z := 0.0178
	_box(face, Vector3(-0.0055, 0.002, z), Vector3(0.0035, 0.0055, 0.002))
	_box(face, Vector3(0.0055, 0.002, z), Vector3(0.0035, 0.0055, 0.002))
	_box(face, Vector3(0.0, -0.0055, z - 0.0004), Vector3(0.005, 0.0016, 0.002))
	_box(face, Vector3(-0.0033, -0.0046, z - 0.0004), Vector3(0.0018, 0.0018, 0.002))
	_box(face, Vector3(0.0033, -0.0046, z - 0.0004), Vector3(0.0018, 0.0018, 0.002))
	_commit(mesh, face, _ink())
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


func _soul() -> StandardMaterial3D:
	var soul := StandardMaterial3D.new()
	soul.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soul.albedo_color = SOUL
	return soul


func _glow_pane() -> StandardMaterial3D:
	var pane := StandardMaterial3D.new()
	pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.albedo_color = Color(SOUL, 0.5)
	return pane


func _ink() -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.12, 0.2, 0.22)
	return ink


func _wax() -> StandardMaterial3D:
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.62, 0.16, 0.14)
	wax.roughness = 0.5
	return wax


## Turns `profile` round the Y axis in `sides` flat faces and places it with `at`, as on
## the wood glue. With `window`, the face looking down +Z (toward whoever holds it) is left open between the
## heights in FLASK_WINDOW, for the flask's slot.
func _lathe(tool: SurfaceTool, profile: Array[Vector2], sides: int, at: Transform3D, window := false) -> void:
	for k in profile.size() - 1:
		var a := profile[k]
		var b := profile[k + 1]
		# The profile's tangent turned a quarter clockwise points out of the surface.
		var out := Vector2(b.y - a.y, a.x - b.x)
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var mid := (t0 + t1) * 0.5
			var in_slot := a.y >= FLASK_WINDOW.x - 0.001 and b.y <= FLASK_WINDOW.y + 0.001
			if window and in_slot and sin(mid) > 0.9:
				continue
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


## An axis-aligned box of `size` centred on `centre`, optionally turned by `basis`.
func _box(tool: SurfaceTool, centre: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var half := size * 0.5
	for axis in 3:
		for side in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = half[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = half[(axis + 2) % 3]
			var middle := normal * half[axis]
			var corners: Array = []
			for corner in [middle - u - v, middle + u - v, middle + u + v, middle - u + v]:
				corners.append(centre + basis * corner)
			_face(tool, corners, basis * normal)


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
