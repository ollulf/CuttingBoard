extends "res://tools/import/mesh_builder.gd"

## Builds the ten concept meshes for puppet junk: the bits of wooden body a dead villager,
## bandit or chair leaves behind to loot (see docs/concepts/puppet-junk.md):
##
##   finger_joint   two knuckles of a finger, the pin through them, the tip snapped off;
##   string_knot    a snarl of puppet string, three loops round each other;
##   hinge_pin      a knee's iron hinge pin with a leaf of the hinge still on it;
##   sawdust_pouch  a leather pouch of stuffing sawdust, tied, a heap spilled beside it;
##   lacquer_flake  three curls of painted face lacquer, red and white;
##   dowel          a splintered dowel of bone wood, one end clean, one end torn;
##   screw_eye      the screw-eye the strings were tied to, threads and all;
##   eye_bead       a carved eye bead, white with a dark pupil and an ember ring;
##   ember_knot     the heartwood knot, still warm, an ember in its middle;
##   peg_teeth      a strip of jaw with a row of peg teeth in it.
##
## Concept only: nothing in the game uses them yet. Each is a few dozen to a couple of
## hundred flat-shaded triangles, lying on the ground with its bottom at y = 0.
##
##   godot --headless --path cutting-board -s res://tools/import/build_puppet_junk.gd

const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const DARK := preload("res://assets/materials/environment/dark_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")
const LEATHER := preload("res://assets/materials/props/leather.tres")
const TWINE := preload("res://assets/materials/props/waxed_paper.tres")
const EMBER := preload("res://assets/materials/characters/carver_ember.tres")

const UV_SCALE := 4.0
## Laid out at life size, scaled up to the game's larger-than-life hands like the glue.
const SIZE := 1.6

var _lacquer_red := _paint(Color(0.62, 0.16, 0.1))
var _lacquer_white := _paint(Color(0.9, 0.85, 0.74))


func _init() -> void:
	uv_scale = UV_SCALE
	mesh_scale = SIZE
	var ok := (
		_save(_finger_joint(), "junk_finger_joint.res")
		and _save(_string_knot(), "junk_string_knot.res")
		and _save(_hinge_pin(), "junk_hinge_pin.res")
		and _save(_sawdust_pouch(), "junk_sawdust_pouch.res")
		and _save(_lacquer_flake(), "junk_lacquer_flake.res")
		and _save(_dowel(), "junk_dowel.res")
		and _save(_screw_eye(), "junk_screw_eye.res")
		and _save(_eye_bead(), "junk_eye_bead.res")
		and _save(_ember_knot(), "junk_ember_knot.res")
		and _save(_peg_teeth(), "junk_peg_teeth.res")
	)
	quit(0 if ok else 1)


## Two knuckles lying along X with the pin through the joint; the tip has snapped off at an
## angle and the second knuckle is cracked down its back.
func _finger_joint() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var along := Basis(Vector3.FORWARD, deg_to_rad(-90.0))
	var wood := _begin()
	var knuckle: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.009, 0.0), Vector2(0.011, 0.012), Vector2(0.009, 0.03),
		Vector2(0.01, 0.036), Vector2(0.0, 0.036),
	]
	_lathe(wood, knuckle, 6, Transform3D(along, Vector3(0.002, 0.011, 0.0)))
	var tip: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.01, 0.0), Vector2(0.009, 0.018), Vector2(0.006, 0.026),
		Vector2(0.0, 0.03),
	]
	var bent := Basis(Vector3.FORWARD, deg_to_rad(70.0)) * Basis(Vector3.UP, 0.4)
	_lathe(wood, tip, 6, Transform3D(bent, Vector3(0.002, 0.011, 0.0)))
	_commit(mesh, wood, WOOD)
	var dark := _begin()
	_box(dark, Vector3(-0.02, 0.0205, 0.0), Vector3(0.022, 0.0015, 0.0025), Basis(Vector3.UP, 0.15))
	_commit(mesh, dark, DARK)
	var metal := _begin()
	var pin: Array[Vector2] = [
		Vector2(0.0, -0.014), Vector2(0.003, -0.014), Vector2(0.003, 0.014), Vector2(0.0, 0.014),
	]
	_lathe(metal, pin, 5, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.011, 0.0)))
	_commit(mesh, metal, METAL)
	return mesh


## Three loops of string through one another, lying flat-ish, two loose ends trailing.
func _string_knot() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var twine := _begin()
	var loops := [
		[Vector3(0.0, 0.012, 0.0), Basis(Vector3.RIGHT, 0.35)],
		[Vector3(0.012, 0.014, 0.006), Basis(Vector3.FORWARD, 1.1) * Basis(Vector3.UP, 0.6)],
		[Vector3(-0.008, 0.015, 0.01), Basis(Vector3.RIGHT, 1.3) * Basis(Vector3.UP, -0.5)],
	]
	for loop in loops:
		_lathe(twine, _ring(0.022, 0.0028, 6), 9, Transform3D(loop[1], loop[0]))
	_box(twine, Vector3(0.035, 0.003, -0.012), Vector3(0.05, 0.004, 0.004), Basis(Vector3.UP, 0.5))
	_box(twine, Vector3(-0.034, 0.003, 0.02), Vector3(0.035, 0.004, 0.004), Basis(Vector3.UP, -0.3))
	_commit(mesh, twine, TWINE)
	return mesh


## The knee's iron hinge pin, its head and a bent leaf of the hinge still round it, two
## screw heads in the leaf, lying on its side.
func _hinge_pin() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var lying := Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var metal := _begin()
	var pin: Array[Vector2] = [
		Vector2(0.0, -0.035), Vector2(0.004, -0.035), Vector2(0.004, 0.03), Vector2(0.008, 0.03),
		Vector2(0.008, 0.036), Vector2(0.0, 0.038),
	]
	_lathe(metal, pin, 6, Transform3D(lying, Vector3(0.0, 0.008, 0.0)))
	var knuckle: Array[Vector2] = [
		Vector2(0.0, -0.012), Vector2(0.0065, -0.012), Vector2(0.0065, 0.012), Vector2(0.0, 0.012),
	]
	_lathe(metal, knuckle, 6, Transform3D(lying, Vector3(0.006, 0.008, 0.0)))
	_box(metal, Vector3(0.006, 0.0025, 0.017), Vector3(0.024, 0.0025, 0.026), Basis(Vector3.RIGHT, 0.2))
	_commit(mesh, metal, METAL)
	var dark := _begin()
	for x in [-0.001, 0.013]:
		_box(dark, Vector3(x, 0.0055, 0.021), Vector3(0.005, 0.0015, 0.005), Basis(Vector3.RIGHT, 0.2))
	_commit(mesh, dark, DARK)
	return mesh


## A leather pouch of the sawdust a puppet is stuffed with, tied at the neck with string,
## and a little heap of it spilled out beside it.
func _sawdust_pouch() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var leather := _begin()
	var body: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.034, 0.018), Vector2(0.03, 0.038),
		Vector2(0.012, 0.05), Vector2(0.01, 0.054), Vector2(0.018, 0.066), Vector2(0.0, 0.06),
	]
	_lathe(leather, body, 7, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3.ZERO))
	_commit(mesh, leather, LEATHER)
	var twine := _begin()
	_lathe(twine, _ring(0.012, 0.002, 5), 7, Transform3D(Basis(Vector3.RIGHT, -0.25), Basis(Vector3.RIGHT, -0.25) * Vector3(0.0, 0.051, 0.0)))
	_commit(mesh, twine, TWINE)
	var dust := _begin()
	var heap: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.012, 0.007), Vector2(0.0, 0.01),
	]
	_lathe(dust, heap, 7, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.7)), Vector3(0.04, 0.0, -0.022)))
	for k in 5:
		var angle := k * 1.3
		_box(dust, Vector3(0.04 + cos(angle) * 0.03, 0.001, -0.022 + sin(angle) * 0.022), Vector3(0.004, 0.002, 0.004), Basis(Vector3.UP, angle))
	_commit(mesh, dust, WOOD)
	return mesh


## Three curled flakes of face lacquer, red paint over a white ground, peeled off a mask
## or a painted cheek; each a strip of bent slats.
func _lacquer_flake() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var red := _begin()
	var white := _begin()
	var flakes := [
		[Vector3(0.0, 0.0, 0.0), 0.0, 0.034, 0.022],
		[Vector3(0.03, 0.0, 0.018), 1.9, 0.026, 0.017],
		[Vector3(-0.022, 0.0, 0.024), -1.2, 0.022, 0.014],
	]
	for flake in flakes:
		var turn := Basis(Vector3.UP, flake[1])
		var length: float = flake[2]
		var width: float = flake[3]
		# The curl: four slats, each tipped up further than the last.
		var segments := 4
		var point := Vector3(-length * 0.5, 0.002, 0.0)
		for k in segments:
			var tilt := -0.25 + k * 0.32
			var step := Vector3(cos(tilt), sin(tilt), 0.0) * (length / segments)
			var middle: Vector3 = flake[0] + turn * (point + step * 0.5)
			var lay := turn * Basis(Vector3.BACK, tilt)
			_box(red, middle + lay * Vector3(0.0, 0.0012, 0.0), Vector3(length / segments + 0.001, 0.0012, width), lay)
			_box(white, middle, Vector3(length / segments + 0.001, 0.0012, width * 0.92), lay)
			point += step
	_commit(mesh, red, _lacquer_red)
	_commit(mesh, white, _lacquer_white)
	return mesh


## A dowel of the pale bone wood limbs are pegged with, lying down: one end sawn clean,
## the other torn into long splinters.
func _dowel() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var lying := Basis(Vector3.FORWARD, deg_to_rad(90.0)) * Basis(Vector3.UP, 0.3)
	var at := Vector3(0.03, 0.009, 0.0)
	var wood := _begin()
	var shaft: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.009, 0.0), Vector2(0.009, 0.075), Vector2(0.0, 0.075),
	]
	_lathe(wood, shaft, 7, Transform3D(lying, at))
	# The torn end: splinters around the rim, each a long thin wedge, longer on one side.
	for k in 6:
		var angle := TAU * k / 6.0
		var length := 0.012 + 0.018 * absf(sin(angle * 0.5 + 0.4))
		var rim := Vector3(cos(angle) * 0.0055, 0.075 + length * 0.5, sin(angle) * 0.0055)
		var lean := Basis(Vector3(-sin(angle), 0.0, cos(angle)), 0.18)
		_box(wood, at + lying * rim, Vector3(0.004, length, 0.003) * Vector3(1, 1, 1), lying * Basis(Vector3.UP, -angle) * lean)
	_commit(mesh, wood, WOOD)
	return mesh


## The screw-eye a puppet's string was tied off on: a ring of iron on a threaded shank,
## lying on its side with a frayed end of string still knotted through the eye.
func _screw_eye() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var lying := Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var at := Vector3(0.0, 0.009, 0.0)
	var metal := _begin()
	var shank: Array[Vector2] = [Vector2(0.0, -0.045), Vector2(0.0025, -0.04)]
	# The thread: the radius steps in and out up the shank.
	for k in 7:
		var y := -0.04 + k * 0.005
		shank.append(Vector2(0.0045, y + 0.0025))
		shank.append(Vector2(0.003, y + 0.005))
	shank.append(Vector2(0.0035, -0.004))
	shank.append(Vector2(0.0, -0.004))
	_lathe(metal, shank, 6, Transform3D(lying, at))
	var eye := Basis(Vector3.RIGHT, deg_to_rad(90.0)) * Basis(Vector3.FORWARD, 0.0)
	_lathe(metal, _ring(0.009, 0.0028, 5), 9, Transform3D(lying * eye, at + lying * Vector3(0.0, 0.0065, 0.0)))
	_commit(mesh, metal, METAL)
	var twine := _begin()
	_box(twine, at + Vector3(-0.024, -0.003, 0.012), Vector3(0.03, 0.003, 0.003), Basis(Vector3.UP, -0.6))
	_box(twine, at + Vector3(-0.024, -0.003, -0.01), Vector3(0.026, 0.003, 0.003), Basis(Vector3.UP, 0.5))
	_commit(mesh, twine, TWINE)
	return mesh


## A carved eye bead: a turned ball of wood, its front painted white, a dark pupil in an
## ember ring, the stub of the peg it sat on behind it. Lies looking up and a little towards +Z.
func _eye_bead() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var look := Basis(Vector3.RIGHT, deg_to_rad(60.0))
	var at := Vector3(0.0, 0.016, 0.0)
	var r := 0.016
	var wood := _begin()
	var back: Array[Vector2] = [Vector2(0.0, -r), Vector2(r * 0.7, -r * 0.7), Vector2(r, 0.0), Vector2(r * 0.94, 0.003)]
	_lathe(wood, back, 8, Transform3D(look, at))
	var peg: Array[Vector2] = [Vector2(0.0, -0.026), Vector2(0.004, -0.026), Vector2(0.004, -0.014), Vector2(0.0, -0.014)]
	_lathe(wood, peg, 5, Transform3D(look, at))
	_commit(mesh, wood, WOOD)
	var white := _begin()
	_lathe(white, [Vector2(r * 0.94, 0.003), Vector2(r * 0.78, 0.0085), Vector2(0.0092, 0.0128)] as Array[Vector2], 8, Transform3D(look, at))
	_commit(mesh, white, _lacquer_white)
	var ember := _begin()
	_lathe(ember, [Vector2(0.0092, 0.0128), Vector2(0.0058, 0.0148)] as Array[Vector2], 8, Transform3D(look, at))
	_commit(mesh, ember, EMBER)
	var pupil := _begin()
	_lathe(pupil, [Vector2(0.0058, 0.0148), Vector2(0.0, 0.0162)] as Array[Vector2], 8, Transform3D(look, at))
	_commit(mesh, pupil, DARK)
	return mesh


## The heartwood knot from a puppet's chest: a gnarled lump of dark wood, split open on
## top, the ember that kept it walking still glowing in the crack.
func _ember_knot() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var dark := _begin()
	var lump: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.018, 0.0), Vector2(0.028, 0.012), Vector2(0.026, 0.026),
		Vector2(0.03, 0.034), Vector2(0.016, 0.04), Vector2(0.0, 0.036),
	]
	var squash := Basis.from_scale(Vector3(1.0, 1.0, 0.8)) * Basis(Vector3.UP, 0.3)
	_lathe(dark, lump, 7, Transform3D(squash, Vector3.ZERO))
	# Burls bulging out of its sides.
	for k in 3:
		var angle := TAU * k / 3.0 + 0.5
		var burl: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.009, 0.003), Vector2(0.007, 0.01), Vector2(0.0, 0.012)]
		var out := Basis(Vector3(-sin(angle), 0.0, cos(angle)), deg_to_rad(80.0))
		_lathe(dark, burl, 5, Transform3D(out, Vector3(cos(angle) * 0.02, 0.016 + k * 0.004, sin(angle) * 0.016)))
	_commit(mesh, dark, DARK)
	var ember := _begin()
	var core: Array[Vector2] = [Vector2(0.0, 0.026), Vector2(0.011, 0.03), Vector2(0.009, 0.043), Vector2(0.0, 0.047)]
	_lathe(ember, core, 6, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), Vector3.ZERO))
	_commit(mesh, ember, EMBER)
	return mesh


## A broken strip of jaw with a row of whittled peg teeth still in it, one tooth missing,
## one knocked crooked.
func _peg_teeth() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var bend := 0.5
	var wood := _begin()
	var teeth := _begin()
	for k in 6:
		var t := (k - 2.5) / 2.5
		var angle := t * bend
		var middle := Vector3(sin(angle) * 0.06, 0.006, (1.0 - cos(angle)) * 0.06)
		var turn := Basis(Vector3.UP, -angle)
		_box(wood, middle, Vector3(0.013, 0.012, 0.014), turn)
		if k == 4:
			continue
		var lean := Basis(Vector3.BACK, 0.45) if k == 1 else Basis.IDENTITY
		var tooth: Array[Vector2] = [
			Vector2(0.0, 0.0), Vector2(0.0045, 0.0), Vector2(0.004, 0.011), Vector2(0.0, 0.014),
		]
		_lathe(teeth, tooth, 5, Transform3D(turn * lean, middle + Vector3(0.0, 0.006, 0.0)))
	_commit(mesh, wood, WOOD)
	_commit(mesh, teeth, _lacquer_white)
	return mesh


## The profile of a ring of `radius` round the axis, its cross-section a circle of `thick`
## in `steps` sides, wound bottom, up the outside, back down the inside like the others.
func _ring(radius: float, thick: float, steps: int) -> Array[Vector2]:
	var profile: Array[Vector2] = []
	for k in steps + 1:
		var angle := -PI * 0.5 + TAU * k / steps
		profile.append(Vector2(radius + cos(angle) * thick, sin(angle) * thick))
	return profile


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


## A flat painted lacquer, embedded in the meshes that use it.
func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	return material
