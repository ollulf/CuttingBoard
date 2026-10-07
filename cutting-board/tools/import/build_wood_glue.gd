extends "res://tools/import/mesh_builder.gd"

## Builds the three concept meshes for the wood glue, so the one picked can be swapped
## into scenes/items/wood_glue.tscn by changing a single path:
##
##   a  an earthenware pot of hide glue, a brush left standing in it, glue run down the
##      side from the rim;
##   b  a squeezed leather glue skin, tied at the neck, with a wooden stopper in it and a
##      dribble of glue under it;
##   c  a whittled glue dipper, a gob of glue on its head running down the handle and a
##      cord wound round the grip.
##
## Everything is turned on a lathe of a few sides and flat shaded, kept to a couple of
## hundred triangles like the other props. Each is laid out the way a HandSlot holds
## things: the middle of where the fist closes sits at the origin, the item stands up
## along +Y, and forward is -Z.
##
## Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://tools/import/build_wood_glue.gd

const GLUE := preload("res://assets/materials/props/glue.tres")
const CLAY := preload("res://assets/materials/props/glue_pot_clay.tres")
const LEATHER := preload("res://assets/materials/props/leather.tres")
const PAPER := preload("res://assets/materials/props/waxed_paper.tres")
const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")

## Profiles are (radius, height) pairs in metres, listed from the bottom up the outside
## and, for anything hollow, back down the inside. That order is what turns each face
## outward, so a profile never has to be wound by hand.

## a: the pot, its glue, and the brush standing in it.
const POT_SIDES := 8
const POT_GRIP := 0.05
const POT_WALL: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.038, 0.0), Vector2(0.05, 0.025), Vector2(0.052, 0.065),
	Vector2(0.042, 0.092), Vector2(0.047, 0.1), Vector2(0.043, 0.106), Vector2(0.037, 0.098),
	Vector2(0.036, 0.092),
]
const POT_GLUE: Array[Vector2] = [Vector2(0.036, 0.092), Vector2(0.0, 0.095)]
## Runs of glue down the outside from the rim: (which face of the pot, length).
const POT_RUNS: Array[Vector2] = [Vector2(0, 0.04), Vector2(2, 0.025), Vector2(5, 0.055)]
const BRUSH_SIDES := 5
const BRUSH_HANDLE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.008, 0.0), Vector2(0.007, 0.13), Vector2(0.0, 0.135),
]
const BRUSH_FERRULE: Array[Vector2] = [
	Vector2(0.0, -0.01), Vector2(0.011, -0.01), Vector2(0.011, 0.02), Vector2(0.0, 0.02),
]

## b: the glue skin, squeezed flat across X, its stopper and its tie.
const SKIN_SIDES := 8
const SKIN_GRIP := 0.06
const SKIN_FLATTEN := 0.62
const SKIN_BODY: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.05, 0.028), Vector2(0.05, 0.075),
	Vector2(0.032, 0.108), Vector2(0.013, 0.124), Vector2(0.012, 0.142), Vector2(0.0, 0.142),
]
const SKIN_TIE: Array[Vector2] = [
	Vector2(0.0, 0.124), Vector2(0.017, 0.124), Vector2(0.017, 0.133), Vector2(0.0, 0.133),
]
const STOPPER_SIDES := 6
const STOPPER: Array[Vector2] = [
	Vector2(0.0, 0.132), Vector2(0.009, 0.132), Vector2(0.012, 0.16), Vector2(0.015, 0.165),
	Vector2(0.013, 0.172), Vector2(0.0, 0.174),
]

## c: the dipper's handle with a knob at its foot, the cord on its grip, the gob of glue
## on its head with the wooden tip poking out of the top, and the run down the handle.
const DIPPER_SIDES := 6
const DIPPER_GOB_SIDES := 7
const DIPPER_GRIP := 0.055
const DIPPER_HANDLE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.012, 0.0), Vector2(0.014, 0.01), Vector2(0.009, 0.02),
	Vector2(0.008, 0.11), Vector2(0.0, 0.11),
]
const DIPPER_CORD: Array[Vector2] = [
	Vector2(0.0, 0.03), Vector2(0.0105, 0.03), Vector2(0.0105, 0.075), Vector2(0.0, 0.075),
]
const DIPPER_GOB: Array[Vector2] = [
	Vector2(0.0, 0.1), Vector2(0.016, 0.102), Vector2(0.026, 0.116), Vector2(0.027, 0.138),
	Vector2(0.02, 0.155), Vector2(0.008, 0.163), Vector2(0.0, 0.164),
]
const DIPPER_TIP: Array[Vector2] = [
	Vector2(0.0, 0.16), Vector2(0.0065, 0.16), Vector2(0.0055, 0.174), Vector2(0.0, 0.177),
]
const DIPPER_DRIP: Array[Vector2] = [
	Vector2(0.0, 0.07), Vector2(0.004, 0.077), Vector2(0.0065, 0.088), Vector2(0.007, 0.1),
	Vector2(0.0, 0.106),
]

## Texture repeats per metre, the same on every face, as on the saw.
const UV_SCALE := 4.0
## Every table above is in the size of a real pot of glue; the game's people and tools
## are drawn larger than life (the hammer is most of a metre long), so everything is
## scaled up by this much to sit in their hands at the same proportion.
const SIZE := 1.6


func _init() -> void:
	uv_scale = UV_SCALE
	mesh_scale = SIZE
	var ok := (
		_save(_build_pot(), "wood_glue_a.res")
		and _save(_build_skin(), "wood_glue_b.res")
		and _save(_build_dipper(), "wood_glue_c.res")
	)
	quit(0 if ok else 1)


## a: an earthenware pot, glue to just under the rim, a brush leaning in it and three
## runs of glue down the outside.
func _build_pot() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -POT_GRIP, 0.0))
	var clay := _begin()
	_lathe(clay, POT_WALL, POT_SIDES, down)
	_commit(mesh, clay, CLAY)

	var glue := _begin()
	_lathe(glue, POT_GLUE, POT_SIDES, down)
	for run in POT_RUNS:
		_run(glue, int(run.x), run.y, down)
	_commit(mesh, glue, GLUE)

	# The brush stands in the glue leaning back over the rim, away from the fist.
	var lean := Basis(Vector3.RIGHT, deg_to_rad(-18.0)) * Basis(Vector3.FORWARD, deg_to_rad(8.0))
	var brush := Transform3D(lean, Vector3(0.008, 0.06 - POT_GRIP, 0.01))
	var wood := _begin()
	_lathe(wood, BRUSH_HANDLE, BRUSH_SIDES, brush)
	_commit(mesh, wood, WOOD)
	var metal := _begin()
	_lathe(metal, BRUSH_FERRULE, BRUSH_SIDES, brush)
	_commit(mesh, metal, METAL)
	return mesh


## b: a leather skin squeezed flat, tied at the neck, stoppered with a whittled plug, and
## glue dribbled down the front from the neck.
func _build_skin() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var squeeze := Transform3D(
		Basis.from_scale(Vector3(SKIN_FLATTEN, 1.0, 1.0)), Vector3(0.0, -SKIN_GRIP, 0.0)
	)
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -SKIN_GRIP, 0.0))
	var leather := _begin()
	_lathe(leather, SKIN_BODY, SKIN_SIDES, squeeze)
	_commit(mesh, leather, LEATHER)

	var tie := _begin()
	_lathe(tie, SKIN_TIE, SKIN_SIDES, down)
	_commit(mesh, tie, PAPER)

	var wood := _begin()
	_lathe(wood, STOPPER, STOPPER_SIDES, down)
	_commit(mesh, wood, WOOD)

	var glue := _begin()
	# Down the front of the neck, then a longer run over the shoulder.
	_box(glue, Vector3(0.0, 0.126 - SKIN_GRIP, -0.0125), Vector3(0.007, 0.022, 0.004))
	var shoulder := Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	_box(glue, Vector3(0.0, 0.103 - SKIN_GRIP, -0.034), Vector3(0.008, 0.04, 0.004), shoulder)
	_box(glue, Vector3(0.0, 0.068 - SKIN_GRIP, -0.0505), Vector3(0.007, 0.03, 0.004))
	_commit(mesh, glue, GLUE)
	return mesh


## c: a whittled glue dipper, its head thick with a gob of glue that has begun to run down
## the handle, and a cord wound round the grip.
func _build_dipper() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -DIPPER_GRIP, 0.0))
	var wood := _begin()
	_lathe(wood, DIPPER_HANDLE, DIPPER_SIDES, down)
	_lathe(wood, DIPPER_TIP, DIPPER_SIDES, down)
	_commit(mesh, wood, WOOD)
	var cord := _begin()
	_lathe(cord, DIPPER_CORD, DIPPER_SIDES, down)
	_commit(mesh, cord, LEATHER)
	var glue := _begin()
	_lathe(glue, DIPPER_GOB, DIPPER_GOB_SIDES, down)
	# The run hangs off the gob down the front of the handle.
	var drip := Transform3D(Basis.IDENTITY, down.origin + Vector3(0.0, 0.0, -0.007))
	_lathe(glue, DIPPER_DRIP, DIPPER_SIDES - 1, drip)
	_commit(mesh, glue, GLUE)
	return mesh


## A run of glue down the outside of the pot from the rim: a thin tongue lying on the
## middle of one face of the wall, following its curve, wide at the lip and drawn to a
## point at the bottom.
func _run(tool: SurfaceTool, face: int, length: float, at: Transform3D) -> void:
	var angle := TAU * (face + 0.5) / POT_SIDES
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var across := Vector3(-sin(angle), 0.0, cos(angle))
	var top := POT_WALL[5].y
	var heights := [top, POT_WALL[4].y, lerpf(POT_WALL[4].y, top - length, 0.5), top - length]
	var widths := [0.008, 0.007, 0.005, 0.0]
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for k in heights.size():
		var y: float = heights[k]
		# A flat face is nearer the axis than the profile's corners are.
		var on_face := _pot_radius(y) * cos(PI / POT_SIDES) + 0.0015
		var middle := radial * on_face + Vector3.UP * y
		left.append(at * (middle + across * widths[k]))
		right.append(at * (middle - across * widths[k]))
	for k in heights.size() - 1:
		var corners: Array = [left[k], right[k], right[k + 1]]
		if widths[k + 1] > 0.0:
			corners.append(left[k + 1])
		_face(tool, corners, radial)


## The radius of the pot's outside at height `y`, read off the rising part of its profile.
func _pot_radius(y: float) -> float:
	for k in range(1, 5):
		var a := POT_WALL[k]
		var b := POT_WALL[k + 1]
		if y <= b.y:
			return lerpf(a.x, b.x, inverse_lerp(a.y, b.y, y))
	return POT_WALL[5].x


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
