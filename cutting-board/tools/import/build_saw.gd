extends "res://tools/import/mesh_builder.gd"

const WOOD := preload("res://assets/materials/environment/dark_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")

const HANDLE_OUTER: Array[Vector2] = [
	Vector2(-0.03, -0.10), Vector2(0.035, -0.10), Vector2(0.09, -0.07), Vector2(0.09, 0.06),
	Vector2(0.06, 0.10), Vector2(0.0, 0.115), Vector2(-0.055, 0.10), Vector2(-0.03, 0.04),
]
const HANDLE_HOLE: Array[Vector2] = [
	Vector2(0.0, -0.065), Vector2(0.03, -0.07), Vector2(0.055, -0.045), Vector2(0.055, 0.035),
	Vector2(0.04, 0.06), Vector2(0.012, 0.07), Vector2(0.0, 0.06), Vector2(0.0, 0.03),
]
const GRIP := Vector2(-0.015, -0.02)
const HANDLE_THICKNESS := 0.028

const BLADE_HEEL := 0.07
const BLADE_TOE := 0.58
const SPINE_AT_HEEL := 0.05
const SPINE_AT_TOE := 0.02
const TOOTH_TIPS := -0.062
const TOOTH_DEPTH := 0.014
const TOOTH_COUNT := 16
const TOOTH_RAKE := 0.3
const BLADE_THICKNESS := 0.006

const UV_SCALE := 2.0


func _init() -> void:
	uv_scale = UV_SCALE
	var mesh := ArrayMesh.new()
	_commit(mesh, _build_handle(), WOOD)
	_commit(mesh, _build_blade(), METAL)
	quit(0 if _save(mesh, "saw.res") else 1)


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


func _at(point: Vector2, x: float) -> Vector3:
	return Vector3(x, point.y, -point.x)


func _wall(tool: SurfaceTool, a: Vector2, b: Vector2, half: float) -> void:
	var outward := Vector2(b.y - a.y, a.x - b.x)
	_quad(tool, [_at(a, -half), _at(b, -half), _at(b, half), _at(a, half)], _at(outward, 0.0))


func _quad(tool: SurfaceTool, corners: Array, facing: Vector3) -> void:
	var first: Vector3 = corners[0]
	var normal := (corners[1] - first).cross(corners[2] - first).normalized() as Vector3
	if normal.dot(facing) < 0.0:
		corners.reverse()
		normal = -normal
	for index in [0, 2, 1, 0, 3, 2]:
		var corner: Vector3 = corners[index]
		tool.set_normal(normal)
		tool.set_uv(_uv(corner, normal))
		tool.add_vertex(corner)
	_triangles += 2
