extends "res://tools/import/mesh_builder.gd"

## Builds the Carver, concept C ("The Mask Orchard") in 3D: a thin demigod sitting cross-
## legged on a huge tree stump, carving masks the whole time. Sixteen arms fan out round him
## like a tool rack, each holding a wooden carving tool or a half-finished mask. His face is
## a huge mask cut from a slice of the trunk: growth rings, a crown of spikes, three ember
## eyes, tear grooves and a sad mouth. Live branches rise from the back of the stump and the
## finished masks hang from them like fruit. Round the stump lie his materials and his
## rejects: stacked and leaning boards, rough blanks and nearly finished masks, shavings,
## a chopping block and a small workbench.
##
## The parts are saved as meshes under assets/meshes/characters/carver_*.res and put
## together in scenes/characters/carver.tscn. Each arm is a chain of pivots, ShoulderN >
## ElbowN > WristN (N = 0..15, counted round the fan from his left), all scene-unique names
## so an animator can turn them as %Elbow3 and so on. carver.gd plays a slow idle on them.
## He faces -Z like the game's other characters. Concept only: not placed in any level.
##
## Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://tools/import/build_carver.gd

const MESH_DIR := "res://assets/meshes/characters/"
const SCENE_PATH := "res://scenes/characters/carver.tscn"
const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const BARK := preload("res://assets/materials/environment/dark_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")
const MAT_DIR := "res://assets/materials/characters/"
const SCRIPT := preload("res://scenes/characters/carver.gd")

const BONE_COLOR := Color("d9cbaa")
const SKIN_COLOR := Color("5e4c3d")
const SHADOW_COLOR := Color("1e1512")
const SHAVING_COLOR := Color("d2a96c")
const EMBER_COLOR := Color("e0502a")

## The stump: its height and radii (top, foot), metres.
const STUMP_H := 2.0
const STUMP_TOP := 1.25
const STUMP_FOOT := 1.55
## The face mask's radius without its spikes, and how far it stands out from his neck.
const MASK_RADIUS := 1.0
## The arms: how many, the angles of the fan (from straight down, round through his
## sides, leaving the top free for the mask), and the bone lengths.
const ARMS := 16
const FAN_FROM := deg_to_rad(-155.0)
const FAN_TO := deg_to_rad(155.0)
const UPPER_ARM := 1.5
const FOREARM := 1.25
## What each arm holds, counted round the fan from his left. "mask" arms hold a work in
## progress, the rest a tool.
const HOLDS := [
	"rasp", "mallet", "chisel", "gouge", "knife", "blank", "gouge_hot", "mask",
	"mask", "knife", "chisel", "blank", "gouge", "mallet", "knife", "rasp",
]

var _bone: StandardMaterial3D
var _skin: StandardMaterial3D
var _shadow: StandardMaterial3D
var _shaving: StandardMaterial3D
var _ember: StandardMaterial3D
var _unique: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	uv_scale = 1.5
	_bone = _matte(BONE_COLOR, "carver_bone.tres")
	_skin = _matte(SKIN_COLOR, "carver_skin.tres")
	_shadow = _matte(SHADOW_COLOR, "carver_shadow.tres")
	_shaving = _matte(SHAVING_COLOR, "carver_shaving.tres")
	_ember = _glow(EMBER_COLOR, "carver_ember.tres")
	var builders := {
		"stump": _stump_mesh, "yard": _yard_mesh, "body": _body_mesh,
		"face": _face_mask.bind(MASK_RADIUS, 3, 15),
		"fruit": _face_mask.bind(0.24, 3, 9),
		"blank_rough": _face_mask.bind(0.3, 0, 0),
		"blank_rings": _face_mask.bind(0.3, 1, 0),
		"blank_spiked": _face_mask.bind(0.3, 2, 7),
		"upper_arm": _upper_arm_mesh, "forearm": _forearm_mesh,
		"rasp": _tool_mesh.bind("rasp"), "mallet": _tool_mesh.bind("mallet"),
		"chisel": _tool_mesh.bind("chisel"), "gouge": _tool_mesh.bind("gouge"),
		"gouge_hot": _tool_mesh.bind("gouge_hot"), "knife": _tool_mesh.bind("knife"),
	}
	var ok := true
	for key in builders:
		_rng.seed = hash(key)
		ok = _save_to(builders[key].call(), MESH_DIR + "carver_%s.res" % key) and ok
	ok = ok and _build_scene() == OK
	print("carver: ", "saved " + SCENE_PATH if ok else "FAILED")
	quit(0 if ok else 1)


func _matte(col: Color, file: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ResourceSaver.save(mat, MAT_DIR + file)
	return load(MAT_DIR + file)


func _glow(col: Color, file: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(mat, MAT_DIR + file)
	return load(MAT_DIR + file)


func _save_to(mesh: ArrayMesh, path: String) -> bool:
	var error := ResourceSaver.save(mesh, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		return false
	print("Built %s with %d triangles." % [path, _triangles])
	_triangles = 0
	return true


## One SurfaceTool per material, so a part can mix wood, bark and bone and still be one
## mesh with a surface for each.
func _surfaces(materials: Array) -> Dictionary:
	var tools := {}
	for mat in materials:
		tools[mat] = _begin()
	return tools


func _finish(tools: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in tools:
		# A material nothing was drawn in gets no surface (committing it empty would hand
		# its material to the surface before it).
		var tool: SurfaceTool = tools[mat]
		var arrays := tool.commit_to_arrays()
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		if vertices == null or vertices.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


# --- meshes ------------------------------------------------------------------------------


## The stump with its roots and the live branches rising from its back, the masks that
## hang from them like fruit left out (they are instances of the "fruit" mesh, placed by
## the scene). The stump's cut top is at y STUMP_H.
func _stump_mesh() -> ArrayMesh:
	var t := _surfaces([BARK, WOOD, _shadow])
	var trunk: Array[Vector2] = [
		Vector2(0.0, -0.05), Vector2(STUMP_FOOT + 0.25, -0.05), Vector2(STUMP_FOOT, 0.35),
		Vector2(STUMP_TOP + 0.1, 1.0), Vector2(STUMP_TOP, STUMP_H - 0.05), Vector2(0.0, STUMP_H - 0.05),
	]
	_lathe(t[BARK], trunk, 14, Transform3D.IDENTITY)
	# The cut face: a pale slice with stepped growth rings, a bit ragged at the bark.
	var cut: Array[Vector2] = [Vector2(STUMP_TOP + 0.04, STUMP_H - 0.06)]
	for ring in 5:
		var r := STUMP_TOP * (1.0 - ring * 0.19)
		cut.append(Vector2(r, STUMP_H + 0.02 * (ring % 2)))
		cut.append(Vector2(r - 0.06, STUMP_H + 0.02 * (ring % 2)))
	cut.append(Vector2(0.0, STUMP_H + 0.01))
	cut.reverse()
	_lathe(t[WOOD], cut, 14, Transform3D.IDENTITY)
	# Roots: thick at the trunk, bending down into the ground.
	for i in 9:
		var a := TAU * i / 9.0 + _rng.randf_range(-0.15, 0.15)
		var out := Vector3(cos(a), 0.0, sin(a))
		var start := out * (STUMP_FOOT - 0.2) + Vector3.UP * 0.7
		var knee := out * (STUMP_FOOT + 0.6 + _rng.randf() * 0.3) + Vector3.UP * 0.2
		var tip := out * (STUMP_FOOT + 1.4 + _rng.randf() * 0.8) + Vector3.DOWN * 0.1
		_tube(t[BARK], start, knee, 0.3, 0.2, 6)
		_tube(t[BARK], knee, tip, 0.2, 0.05, 5)
	# The branches: from the back of the stump, two bends each, forking near the top.
	for b in _branches():
		var points: Array = b
		for k in points.size() - 1:
			var r0 := lerpf(0.22, 0.05, float(k) / (points.size() - 1))
			var r1 := lerpf(0.22, 0.05, float(k + 1) / (points.size() - 1))
			_tube(t[BARK], points[k], points[k + 1], r0, r1, 6)
	return _finish(t)


## The branches' bend points, back of the stump to the twig tips, shared with the scene so
## the hanging masks land on them.
func _branches() -> Array:
	var list := []
	var spread := [-1.0, -0.55, -0.15, 0.25, 0.65, 1.0]
	for i in spread.size():
		var s: float = spread[i]
		var base := Vector3(s * 0.9, STUMP_H - 0.3, 0.8)
		var tall := 6.6 + (1.0 - absf(s)) * 2.0 + (i % 2) * 0.6
		list.append([
			base,
			base + Vector3(s * 0.8, 2.0, 0.5),
			base + Vector3(s * 2.0, tall * 0.55, 0.9),
			base + Vector3(s * 3.0, tall * 0.8, 0.7),
			base + Vector3(s * 3.6 + 0.4, tall, 0.4),
		])
		# A side twig from the middle bend.
		list.append([
			base + Vector3(s * 2.0, tall * 0.55, 0.9),
			base + Vector3(s * 2.0 + signf(s + 0.01) * 1.4, tall * 0.62, 0.5),
		])
	return list


## Where the finished masks hang (the string's top), along the branches.
func _fruit_spots() -> Array:
	var spots := []
	var branches := _branches()
	for i in branches.size():
		var points: Array = branches[i]
		for k in range(1, points.size()):
			if (i + k) % 2 == 0 or k == points.size() - 1:
				var a: Vector3 = points[k - 1]
				var b: Vector3 = points[k]
				spots.append(a.lerp(b, 0.6))
	return spots


## The yard round the stump: board stacks and leaning boards, shaving heaps and curls, a
## chopping block, and a low workbench. The loose masks are instances placed by the scene.
func _yard_mesh() -> ArrayMesh:
	var t := _surfaces([WOOD, BARK, _shaving, _shadow, METAL])
	# A stack of planks, front left, each a little askew.
	for i in 6:
		var y := 0.04 + i * 0.07
		var turn := _rng.randf_range(-0.12, 0.12)
		var dir := Vector3(cos(turn), 0, sin(turn)) * 1.1
		var at := Vector3(-3.1, y, -1.4) + Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1))
		_slab(t[WOOD], at - dir, at + dir, 0.36, 0.06)
	# Two crosswise spacers under the stack.
	for x in [-3.8, -2.4]:
		_slab(t[BARK], Vector3(x, 0.02, -1.85), Vector3(x, 0.02, -0.95), 0.12, 0.05)
	# Boards leaning against the stump's flank and against the stack.
	var leaning := [
		[Vector3(1.9, 0.0, -0.9), Vector3(1.35, 1.9, -0.55), 0.32],
		[Vector3(2.3, 0.0, -0.4), Vector3(1.55, 1.7, -0.1), 0.28],
		[Vector3(2.1, 0.0, 0.35), Vector3(1.45, 1.55, 0.3), 0.36],
		[Vector3(-1.9, 0.0, 0.8), Vector3(-1.35, 1.8, 0.45), 0.3],
		[Vector3(-4.0, 0.0, -0.5), Vector3(-3.6, 1.3, -1.2), 0.26],
	]
	for board in leaning:
		_slab(t[WOOD], board[0], board[1], board[2], 0.05)
	# Heaps of shavings round the foot of the stump, under the working arms.
	for heap in [[Vector3(0.6, 0, -1.9), 0.9], [Vector3(-0.9, 0, -2.1), 0.7], [Vector3(-2.6, 0, -2.3), 0.5], [Vector3(2.0, 0, -1.7), 0.55]]:
		var r: float = heap[1]
		var mound: Array[Vector2] = [
			Vector2(0.0, 0.0), Vector2(r, 0.0), Vector2(r * 0.7, r * 0.18),
			Vector2(r * 0.3, r * 0.3), Vector2(0.0, r * 0.33),
		]
		_lathe(t[_shaving], mound, 9, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), heap[0]))
	# Loose curls of shaving: little helices scattered over the ground and the heaps.
	for i in 70:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(1.6, 3.6)
		var at := Vector3(cos(a) * d, 0.04, sin(a) * d * 0.8 - 0.9)
		_curl(t[_shaving], at, _rng.randf() * TAU, _rng.randf_range(0.05, 0.11))
	# The chopping block, front right, with an axe bitten into it.
	var block: Array[Vector2] = [Vector2(0, 0), Vector2(0.42, 0), Vector2(0.4, 0.55), Vector2(0, 0.55)]
	_lathe(t[BARK], block, 10, Transform3D(Basis.IDENTITY, Vector3(2.9, 0, -2.2)))
	var cut: Array[Vector2] = [Vector2(0, 0.56), Vector2(0.38, 0.56), Vector2(0.38, 0.555), Vector2(0, 0.555)]
	cut.reverse()
	_lathe(t[WOOD], cut, 10, Transform3D(Basis.IDENTITY, Vector3(2.9, 0, -2.2)))
	_tube(t[WOOD], Vector3(2.95, 0.58, -2.2), Vector3(3.45, 1.15, -2.45), 0.03, 0.025, 5)
	_slab(t[METAL], Vector3(2.85, 0.56, -2.15), Vector3(3.05, 0.72, -2.25), 0.2, 0.03)
	# The workbench, back right: a thick top on four splayed legs, a vice block at one end.
	var bench := Vector3(3.3, 0.0, 1.2)
	_slab(t[WOOD], bench + Vector3(-1.0, 0.8, 0.0), bench + Vector3(1.0, 0.8, 0.0), 0.7, 0.1)
	for leg in [Vector3(-0.85, 0, -0.25), Vector3(0.85, 0, -0.25), Vector3(-0.85, 0, 0.25), Vector3(0.85, 0, 0.25)]:
		_tube(t[BARK], bench + leg * 1.1, bench + leg + Vector3(0, 0.76, 0), 0.05, 0.05, 5)
	_slab(t[BARK], bench + Vector3(0.75, 0.86, -0.36), bench + Vector3(0.75, 1.0, -0.36), 0.2, 0.18)
	return _finish(t)


## One curl of shaving: a thin ribbon wound round a short helix.
func _curl(tool: SurfaceTool, at: Vector3, turn: float, r: float) -> void:
	var steps := 7
	var prev := Vector3.ZERO
	for s in steps + 1:
		var a := s * 0.9
		var p := at + Basis(Vector3.UP, turn) * Vector3(cos(a) * r, r + sin(a) * r, s * r * 0.35)
		if s > 0:
			_slab(tool, prev, p, 0.05, 0.008)
		prev = p


## His body: crossed legs on the stump, a thin long torso with the ribs showing, a neck.
## The pelvis sits at the origin (the scene puts it on the stump), the neck ends at y 2.0.
func _body_mesh() -> ArrayMesh:
	var t := _surfaces([_skin, _bone])
	# Crossed legs: thighs out and forward, shins folded back across.
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.18, 0.12, 0.0)
		var knee := Vector3(side * 0.85, 0.15, -0.55)
		var ankle := Vector3(-side * 0.25, 0.1, -0.75 + side * 0.08)
		_tube(t[_skin], hip, knee, 0.13, 0.09, 6)
		_tube(t[_skin], knee, ankle, 0.09, 0.06, 6)
		_tube(t[_skin], ankle, ankle + Vector3(-side * 0.25, -0.02, -0.08), 0.06, 0.04, 5)
	_tube(t[_skin], Vector3(0, 0.0, 0.0), Vector3(0, 0.35, 0.02), 0.26, 0.17, 7)
	# The torso: long, thin, leaning forward over the work.
	_tube(t[_skin], Vector3(0, 0.3, 0.02), Vector3(0, 1.05, -0.05), 0.15, 0.22, 7)
	_tube(t[_skin], Vector3(0, 1.05, -0.05), Vector3(0, 1.55, -0.02), 0.22, 0.26, 7)
	# Ribs: pale bars across the chest and the back.
	for i in 5:
		var y := 0.95 + i * 0.12
		var w := 0.2 + i * 0.012
		for z in [-1.0, 1.0]:
			_slab(t[_bone], Vector3(-w, y, z * (w * 0.85) - 0.04), Vector3(w, y - 0.04, z * (w * 0.85) - 0.04), 0.04, 0.035)
	# The spine's knobs down his back.
	for i in 8:
		var y := 0.4 + i * 0.15
		_tube(t[_bone], Vector3(0, y, 0.14 + 0.06 * sin(i)), Vector3(0, y + 0.07, 0.16), 0.045, 0.02, 4)
	# The neck, bowed, up to where the mask hangs.
	_tube(t[_skin], Vector3(0, 1.5, -0.02), Vector3(0, 2.0, -0.12), 0.09, 0.07, 6)
	return _finish(t)


## A mask cut from a slice of trunk, facing -Z, centred on the origin. `stage` is how far
## the carving has got: 0 a rough disc, 1 growth rings cut in, 2 eyes and mouth marked out,
## 3 finished (ember eyes, tear grooves). `spikes` is how many points crown its rim.
func _face_mask(radius: float, stage: int, spikes: int) -> ArrayMesh:
	var t := _surfaces([WOOD, BARK, _shadow, _ember])
	var depth := radius * 0.22
	var face_on := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	var plate: Array[Vector2] = [Vector2(0.0, -depth * 0.3), Vector2(radius, -depth * 0.3)]
	if stage == 0:
		plate.append_array([Vector2(radius, depth * 0.4), Vector2(0.0, depth * 0.5)])
	else:
		for ring in 5:
			var r := radius * (1.0 - ring * 0.18)
			var h := depth * (0.35 + ring * 0.12)
			plate.append(Vector2(r, h))
			plate.append(Vector2(r - radius * 0.05, h + depth * 0.06 * (ring % 2 * 2 - 1)))
		plate.append(Vector2(0.0, depth * 0.95))
	_lathe(t[WOOD], plate, 16 if stage > 0 else 9, face_on)
	# The bark rim, a thin dark band round the slice.
	var rim: Array[Vector2] = [
		Vector2(radius * 0.97, -depth * 0.35), Vector2(radius * 1.04, -depth * 0.3),
		Vector2(radius * 1.04, depth * 0.3), Vector2(radius * 0.97, depth * 0.36),
	]
	_lathe(t[BARK], rim, 16 if stage > 0 else 9, face_on)
	# The crown: spikes round the rim, longest at the top, thinning down the sides.
	for i in spikes:
		var a := PI * 0.5 + lerpf(-PI * 0.85, PI * 0.85, (i + 0.5) / spikes)
		var top := cos(a - PI * 0.5)
		var length := radius * (0.25 + 0.45 * maxf(top, 0.0)) * (1.0 if i % 2 == 0 else 0.7)
		_spike(t[BARK] if i % 3 == 1 else t[WOOD], a, radius * 0.95, radius * 0.11, depth * 0.5, length)
	if stage < 2:
		return _finish(t)
	var front := -depth * 0.95
	# Three eyes: two wide-set under one on the brow. Sockets cut dark, ember inside once
	# finished.
	for eye in [Vector2(-0.36, 0.12), Vector2(0.36, 0.12), Vector2(0.0, 0.47)]:
		var c := Vector3(eye.x * radius, eye.y * radius, front)
		var socket: Array[Vector2] = [Vector2(0, 0), Vector2(radius * 0.15, 0), Vector2(radius * 0.13, depth * 0.25), Vector2(0, depth * 0.25)]
		_lathe(t[_shadow], socket, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3(1.0, 0.7, 1.0)), c))
		if stage >= 3:
			var glow: Array[Vector2] = [Vector2(0, 0), Vector2(radius * 0.07, 0), Vector2(0, depth * 0.3)]
			_lathe(t[_ember], glow, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), c + Vector3(0, 0, -depth * 0.2)))
		# Tear grooves down from the outer eyes.
		if eye.y < 0.3 and stage >= 3:
			for k in 3:
				var x: float = eye.x * radius + (k - 1) * radius * 0.05
				_slab(t[_shadow], Vector3(x, eye.y * radius - radius * 0.14, front * 0.9),
					Vector3(x + eye.x * 0.06, eye.y * radius - radius * (0.4 + 0.08 * (k % 2)), front * 0.85),
					radius * 0.03, radius * 0.025)
	# The sad mouth: an arc whose corners droop.
	var prev := Vector3.ZERO
	for k in 9:
		var u := lerpf(-1.0, 1.0, k / 8.0)
		var p := Vector3(u * radius * 0.42, -radius * (0.42 + 0.2 * u * u), front * 0.92)
		if k > 0:
			_slab(t[_shadow], prev, p, radius * 0.04, radius * 0.07)
		prev = p
	return _finish(t)


## One spike of the crown: a flat pyramid from the rim at angle `a` outwards.
func _spike(tool: SurfaceTool, a: float, from: float, half_width: float, thick: float, length: float) -> void:
	var out := Vector3(cos(a), sin(a), 0.0)
	var across := Vector3(-sin(a), cos(a), 0.0) * half_width
	var base := out * from
	var tip := out * (from + length) + Vector3(0, 0, -thick * 0.3)
	var c := [base - across + Vector3(0, 0, -thick), base + across + Vector3(0, 0, -thick),
		base + across + Vector3(0, 0, thick * 0.5), base - across + Vector3(0, 0, thick * 0.5)]
	var middle := base + out * length * 0.3
	for k in 4:
		var face := [c[k], c[(k + 1) % 4], tip]
		_face(tool, face, (c[k] + c[(k + 1) % 4] + tip) / 3.0 - middle)


## The upper arm, along +X from the shoulder: long, thin, knobbed at the elbow.
func _upper_arm_mesh() -> ArrayMesh:
	var t := _surfaces([_skin, _bone])
	_tube(t[_skin], Vector3.ZERO, Vector3(UPPER_ARM, 0, 0), 0.1, 0.075, 6)
	_tube(t[_bone], Vector3(UPPER_ARM - 0.06, 0, 0), Vector3(UPPER_ARM + 0.06, 0, 0), 0.105, 0.08, 6)
	return _finish(t)


## The forearm and its hand, along +X from the elbow: three long fingers closing round
## whatever the wrist holds.
func _forearm_mesh() -> ArrayMesh:
	var t := _surfaces([_skin])
	_tube(t[_skin], Vector3.ZERO, Vector3(FOREARM, 0, 0), 0.075, 0.055, 6)
	for f in 3:
		var spread := (f - 1) * 0.5
		var knuckle := Vector3(FOREARM + 0.12, 0.0, 0.0) + Vector3(0, sin(spread), cos(spread)) * 0.06
		_tube(t[_skin], Vector3(FOREARM, 0, 0), knuckle, 0.045, 0.03, 4)
		_tube(t[_skin], knuckle, knuckle + Vector3(0.05, -0.1, sin(spread) * 0.06), 0.03, 0.018, 4)
	return _finish(t)


## A carving tool, gripped at the origin, its business end along +X.
func _tool_mesh(kind: String) -> ArrayMesh:
	var t := _surfaces([WOOD, METAL, _ember])
	var handle := 0.32 if kind != "mallet" else 0.42
	_tube(t[WOOD], Vector3(-0.12, 0, 0), Vector3(handle, 0, 0), 0.035, 0.03, 6)
	match kind:
		"mallet":
			_tube(t[WOOD], Vector3(handle, -0.14, 0), Vector3(handle, 0.14, 0), 0.1, 0.1, 8)
		"chisel":
			_slab(t[METAL], Vector3(handle, 0, 0), Vector3(handle + 0.28, 0, 0), 0.07, 0.012)
		"gouge":
			_tube(t[METAL], Vector3(handle, 0, 0), Vector3(handle + 0.3, 0, 0), 0.02, 0.035, 5)
		"gouge_hot":
			_tube(t[METAL], Vector3(handle, 0, 0), Vector3(handle + 0.2, 0, 0), 0.02, 0.03, 5)
			_tube(t[_ember], Vector3(handle + 0.2, 0, 0), Vector3(handle + 0.3, 0, 0), 0.03, 0.035, 5)
		"knife":
			_face(t[METAL], [Vector3(handle, -0.03, 0), Vector3(handle, 0.03, 0), Vector3(handle + 0.3, 0.01, 0)], Vector3(0, 0, -1))
			_face(t[METAL], [Vector3(handle, -0.03, 0), Vector3(handle, 0.03, 0), Vector3(handle + 0.3, 0.01, 0)], Vector3(0, 0, 1))
		"rasp":
			_slab(t[METAL], Vector3(handle, 0, 0), Vector3(handle + 0.45, 0, 0), 0.06, 0.03)
	return _finish(t)


# --- scene -------------------------------------------------------------------------------


func _build_scene() -> Error:
	var root := Node3D.new()
	root.name = "Carver"
	root.set_script(SCRIPT)
	_part(root, "Stump", "stump")
	_part(root, "Yard", "yard")
	# The finished masks hanging from the branches on short strings.
	var fruit := _pivot(root, "Fruit", Vector3.ZERO)
	var spots := _fruit_spots()
	for i in spots.size():
		var top: Vector3 = spots[i]
		var drop := 0.35 + 0.25 * (i % 3)
		var hang := _pivot(fruit, "Hang%d" % i, top)
		hang.rotation.y = (i % 5 - 2) * 0.25
		var string := MeshInstance3D.new()
		string.name = "String"
		var line := CylinderMesh.new()
		line.top_radius = 0.008
		line.bottom_radius = 0.008
		line.height = drop
		line.radial_segments = 4
		line.material = _shadow
		string.mesh = line
		string.position = Vector3(0, -drop * 0.5, 0)
		hang.add_child(string)
		_part(hang, "Mask", "fruit").position = Vector3(0, -drop - 0.22, 0)
	# Unfinished masks lying about: blanks, half-cut, nearly done.
	var loose := _pivot(root, "LooseMasks", Vector3.ZERO)
	var placed := [
		["blank_rough", Vector3(-2.9, 0.48, -1.45), Vector3(-1.45, 0.3, 0)],
		["blank_rough", Vector3(-1.7, 0.08, -2.6), Vector3(-1.5, 0.0, 0.2)],
		["blank_rings", Vector3(-1.75, 0.35, 0.7), Vector3(-0.2, 1.3, 0)],
		["blank_rings", Vector3(1.0, 0.08, -2.7), Vector3(-1.5, -0.4, 0)],
		["blank_spiked", Vector3(2.1, 0.32, -1.1), Vector3(-0.25, -1.0, 0.1)],
		["blank_spiked", Vector3(3.0, 1.03, 1.05), Vector3(-0.5, -0.3, 0)],
		["fruit", Vector3(3.7, 1.0, 1.3), Vector3(-0.9, 0.4, 0)],
		["blank_rings", Vector3(2.65, 0.95, 1.4), Vector3(-1.4, 0.0, 0)],
		["blank_rough", Vector3(-3.4, 0.25, 0.3), Vector3(-0.3, 0.6, 0.2)],
		["fruit", Vector3(0.1, 0.2, -2.4), Vector3(-1.2, 0.1, 0)],
	]
	for i in placed.size():
		var item: Array = placed[i]
		var mask := _part(loose, "Mask%d" % i, item[0])
		mask.position = item[1]
		mask.rotation = item[2]
	# Him: the pelvis on the stump, the mask on his bowed neck.
	var body := _pivot(root, "Body", Vector3(0, STUMP_H + 0.05, 0.1), true)
	_part(body, "Torso", "body")
	var head := _pivot(body, "Head", Vector3(0, 2.25, -0.35), true)
	head.rotation.x = 0.12
	_part(head, "Mask", "face")
	# The arms, fanned round his chest, elbows bending forward so the hands meet in front.
	for i in ARMS:
		var u := float(i) / (ARMS - 1)
		var angle := lerpf(FAN_FROM, FAN_TO, u)
		var out := Vector3(sin(angle), -cos(angle), 0.0)
		var shoulder := _pivot(body, "Shoulder%d" % i, Vector3(0, 1.25, 0.05) + out * 0.18, true)
		var low := 1.0 - absf(angle) / PI
		shoulder.basis = Basis(Vector3.BACK, angle - PI * 0.5) * Basis(Vector3.UP, 0.12 + 0.25 * low)
		_part(shoulder, "UpperArm", "upper_arm")
		var elbow := _pivot(shoulder, "Elbow%d" % i, Vector3(UPPER_ARM, 0, 0), true)
		elbow.basis = Basis(Vector3.UP, 0.65 + 0.7 * low + 0.15 * (i % 2)) * Basis(Vector3.BACK, (0.5 - u) * 0.6)
		_part(elbow, "Forearm", "forearm")
		var wrist := _pivot(elbow, "Wrist%d" % i, Vector3(FOREARM + 0.06, 0, 0), true)
		var hold: String = HOLDS[i]
		if hold == "mask" or hold == "blank":
			# A mask held up to work on, its face turned to the arm that carves it.
			wrist.basis = Basis(Vector3.UP, -0.6)
			var work := _part(wrist, "Work", "blank_spiked" if hold == "mask" else "blank_rings")
			work.position = Vector3(0.15, 0.0, -0.08)
			work.scale = Vector3.ONE * 1.5
			work.rotation = Vector3(0, PI * 0.5 + (0.5 if i < ARMS / 2 else -0.5), 0)
		else:
			wrist.basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.4 * (i % 3 - 1))
			_part(wrist, "Tool", hold).scale = Vector3.ONE * 1.8
	for n in _unique:
		n.unique_name_in_owner = true
	_own(root, root)
	for n in _unique:
		n.owner = root
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE_PATH)
	root.free()
	return error


func _pivot(p: Node3D, node_name: String, at: Vector3, unique := false) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = at
	p.add_child(n)
	if unique:
		_unique.append(n)
	return n


func _part(p: Node3D, node_name: String, mesh_key: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = load(MESH_DIR + "carver_%s.res" % mesh_key)
	p.add_child(m)
	return m


func _own(n: Node, owner_node: Node) -> void:
	for child in n.get_children():
		child.owner = owner_node
		_own(child, owner_node)


## A round tube from `a` to `b`, `ra` and `rb` thick at its ends, capped both ends.
func _tube(tool: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int) -> void:
	var dir := b - a
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(ra, 0.0), Vector2(rb, dir.length()), Vector2(0.0, dir.length()),
	]
	var basis := Basis(Quaternion(Vector3.UP, dir.normalized()))
	_lathe(tool, profile, sides, Transform3D(basis, a))


## A flat board of `width` (across, level) and `thickness` (up) running from `a` to `b`.
func _slab(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, thickness: float) -> void:
	var along := b - a
	var side := along.cross(Vector3.UP).normalized() * width * 0.5
	if side.is_zero_approx():
		side = Vector3(width * 0.5, 0, 0)
	var up := side.cross(along).normalized() * thickness * 0.5
	if up.dot(Vector3.UP) < 0.0 and absf(up.y) > 0.001:
		up = -up
	var c := [
		a - side - up, a + side - up, b + side - up, b - side - up,
		a - side + up, a + side + up, b + side + up, b - side + up,
	]
	var middle := (a + b) * 0.5
	for quad in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]]:
		var corners: Array = []
		var centre := Vector3.ZERO
		for k in quad:
			corners.append(c[k])
			centre += c[k] / 4.0
		_face(tool, corners, centre - middle)
