extends SceneTree

## Builds the hand saw's mesh: a flat steel blade with a row of real teeth along its
## lower edge, set into a wooden handle with a hole for the fingers. Everything is flat
## shaded and kept to a couple of hundred triangles, like the other props.
##
## The saw is laid out the way a HandSlot holds things: the middle of the handle's grip
## bar sits at the origin and runs along +Y, so the fist closes round it the way it does
## round the hammer's shaft. The blade points forward along -Z, teeth down, and is flat
## in the YZ plane, its thickness along X.
##
## Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://scripts/import/build_saw.gd

const OUT_MESH := "res://assets/meshes/props/saw.res"
const WOOD := preload("res://assets/materials/environment/dark_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")

## The outline of the handle and of the hole through it, as (forward, up) pairs in
## metres, point for point: each outer point is joined to the hole point beside it, so
## the two lists must be the same length and go round the same way. The back edge, from
## the last point to the first, is the grip bar.
const HANDLE_OUTER: Array[Vector2] = [
	Vector2(-0.03, -0.10), Vector2(0.035, -0.10), Vector2(0.09, -0.07), Vector2(0.09, 0.06),
	Vector2(0.06, 0.10), Vector2(0.0, 0.115), Vector2(-0.055, 0.10), Vector2(-0.03, 0.04),
]
const HANDLE_HOLE: Array[Vector2] = [
	Vector2(0.0, -0.065), Vector2(0.03, -0.07), Vector2(0.055, -0.045), Vector2(0.055, 0.035),
	Vector2(0.04, 0.06), Vector2(0.012, 0.07), Vector2(0.0, 0.06), Vector2(0.0, 0.03),
]
## Where the middle of the grip bar is in the outline above; it becomes the origin.
const GRIP := Vector2(-0.015, -0.02)
const HANDLE_THICKNESS := 0.028

## The blade runs from its heel, hidden inside the handle, out to its toe. Its spine
## drops toward the toe, so the blade tapers; the teeth run along a straight line.
const BLADE_HEEL := 0.07
const BLADE_TOE := 0.58
const SPINE_AT_HEEL := 0.05
const SPINE_AT_TOE := 0.02
const TOOTH_TIPS := -0.062
const TOOTH_DEPTH := 0.014
const TOOTH_COUNT := 16
## How far each tip leans toward the toe, as a share of one tooth: a saw cuts on the push.
const TOOTH_RAKE := 0.3
const BLADE_THICKNESS := 0.006

## Texture repeats per metre, the same on every face so the grain and the scratches in
## the metal keep one size across the whole saw.
const UV_SCALE := 2.0

var _triangles := 0


func _init() -> void:
	var mesh := ArrayMesh.new()
	_commit(mesh, _build_handle(), WOOD)
	_commit(mesh, _build_blade(), METAL)
	var error := ResourceSaver.save(mesh, OUT_MESH)
	if error != OK:
		push_error("Could not save %s: %s" % [OUT_MESH, error_string(error)])
		quit(1)
		return
	print("Built %s with %d triangles." % [OUT_MESH, _triangles])
	quit()


## A slab between the outline and the hole: both faces, the outside rim and the inside
## of the hole.
func _build_handle() -> SurfaceTool:
	var tool := _begin()
	var half := HANDLE_THICKNESS * 0.5
	var count := HANDLE_OUTER.size()
	for i in count:
		var j := (i + 1) % count
		var outer_a := HANDLE_OUTER[i] - GRIP
		var outer_b := HANDLE_OUTER[j] - GRIP
		var hole_a := HANDLE_HOLE[i] - GRIP
		var hole_b := HANDLE_HOLE[j] - GRIP
		for side in [-1.0, 1.0]:
			_quad(tool, [_at(outer_a, side * half), _at(outer_b, side * half),
					_at(hole_b, side * half), _at(hole_a, side * half)], Vector3(side, 0.0, 0.0))
		_wall(tool, outer_a, outer_b, half)
		_wall(tool, hole_b, hole_a, half)
	return tool


## The blade: a strip of quads from each tooth point up to the spine above it, on both
## faces, closed by the spine, the toe and the zig-zag of the teeth themselves.
func _build_blade() -> SurfaceTool:
	var tool := _begin()
	var half := BLADE_THICKNESS * 0.5
	var pitch := (BLADE_TOE - BLADE_HEEL) / TOOTH_COUNT
	var edge: Array[Vector2] = []
	var spine: Array[Vector2] = []
	for k in TOOTH_COUNT * 2 + 1:
		var along := BLADE_HEEL + pitch * k * 0.5
		var tip := k % 2 == 1
		if tip:
			along += pitch * TOOTH_RAKE * 0.5
		var height := TOOTH_TIPS if tip else TOOTH_TIPS + TOOTH_DEPTH
		edge.append(Vector2(along, height) - GRIP)
		var t := (along - BLADE_HEEL) / (BLADE_TOE - BLADE_HEEL)
		spine.append(Vector2(along, lerpf(SPINE_AT_HEEL, SPINE_AT_TOE, t)) - GRIP)
	for k in edge.size() - 1:
		for side in [-1.0, 1.0]:
			_quad(tool, [_at(edge[k], side * half), _at(edge[k + 1], side * half),
					_at(spine[k + 1], side * half), _at(spine[k], side * half)], Vector3(side, 0.0, 0.0))
		_wall(tool, edge[k], edge[k + 1], half)
	_wall(tool, spine[spine.size() - 1], spine[0], half)
	_wall(tool, edge[edge.size() - 1], spine[spine.size() - 1], half)
	_wall(tool, spine[0], edge[0], half)
	return tool


## A point of the outline at depth `x`: forward is -Z, up is +Y.
func _at(point: Vector2, x: float) -> Vector3:
	return Vector3(x, point.y, -point.x)


## The side wall along one edge of an outline, through the thickness. It faces to the
## right of a→b, which is outward for an outline that goes round anticlockwise.
func _wall(tool: SurfaceTool, a: Vector2, b: Vector2, half: float) -> void:
	var outward := Vector2(b.y - a.y, a.x - b.x)
	_quad(tool, [_at(a, -half), _at(b, -half), _at(b, half), _at(a, half)], _at(outward, 0.0))


## One flat quad, turned to face `facing`, so the outlines above only need to be listed
## in a consistent order rather than each quad wound by hand.
func _quad(tool: SurfaceTool, corners: Array, facing: Vector3) -> void:
	var first: Vector3 = corners[0]
	var normal := (corners[1] - first).cross(corners[2] - first).normalized() as Vector3
	if normal.dot(facing) < 0.0:
		corners.reverse()
		normal = -normal
	# Godot draws clockwise triangles as front faces.
	for index in [0, 2, 1, 0, 3, 2]:
		var corner: Vector3 = corners[index]
		tool.set_normal(normal)
		tool.set_uv(_uv(corner, normal))
		tool.add_vertex(corner)
	_triangles += 2


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
