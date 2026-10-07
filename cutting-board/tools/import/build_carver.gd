extends "res://tools/import/mesh_builder.gd"

## Builds the Carver, concept C ("The Mask Orchard") in 3D: a thin demigod sitting cross-
## legged on a huge tree stump, carving masks the whole time. Sixteen arms fan out round him
## like a tool rack from his long, hunched torso, each holding a wooden carving tool or a
## half-finished mask. His face is a huge tall mask after the user's sketch: a jagged star
## outline, longest at the top, a ragged beard, three ember eyes (one on the brow) and a sad
## mouth. Live branches rise from the back of the stump and the finished masks hang from
## them like fruit, between lanterns. Round the stump lie his materials and his rejects:
## stacked and leaning boards, rough blanks and nearly finished masks, shavings, a chopping
## block and a small workbench, lit by candles and a brazier.
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
## The eyes and coals: unshaded, so this is the colour on screen; kept bright enough to
## stay ember-red through the PSX grade.
const EMBER_COLOR := Color("ff6a2c")
const FLAME_COLOR := Color("ffd27a")
const LAMP_LIGHT := Color("ffae5c")
const FLICKER := preload("res://scripts/components/light_flicker.gd")

## The stump: its height and radii (top, foot), metres.
const STUMP_H := 2.0
const STUMP_TOP := 1.25
const STUMP_FOOT := 1.55
## The face mask's size (its body is 0.72 of this wide and 1.15 tall each way from the
## middle, before the spikes).
const MASK_RADIUS := 1.0
## His spine, pelvis up (he faces -Z, so +Z is his back): long, bowing back into a round
## hunch and then forward to the neck. SPINE_R is how thick he is at each point.
const SPINE := [
	Vector3(0, 0.3, 0.02), Vector3(0, 1.0, 0.2), Vector3(0, 1.75, 0.42),
	Vector3(0, 2.45, 0.42), Vector3(0, 2.95, 0.12), Vector3(0, 3.2, -0.25),
]
const SPINE_R := [0.16, 0.2, 0.26, 0.28, 0.24, 0.17]
const NECK_END := Vector3(0, 3.3, -0.7)
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
var _flame: StandardMaterial3D
var _unique: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	uv_scale = 1.5
	_bone = _matte(BONE_COLOR, "carver_bone.tres")
	_skin = _matte(SKIN_COLOR, "carver_skin.tres")
	_shadow = _matte(SHADOW_COLOR, "carver_shadow.tres")
	_shaving = _matte(SHAVING_COLOR, "carver_shaving.tres")
	_ember = _glow(EMBER_COLOR, "carver_ember.tres")
	_flame = _glow(FLAME_COLOR, "carver_flame.tres")
	var builders := {
		"lantern": _lantern_mesh, "candle": _candle_mesh, "brazier": _brazier_mesh,
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


## His body: crossed legs on the stump, a long thin torso whose back rounds into a hunch,
## the ribs showing on the chest, and a neck reaching forward and down out of the hunch.
## The pelvis sits at the origin (the scene puts it on the stump); the neck ends at NECK_END.
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
	# The torso: a chain of tubes up the curved spine, swelling at the hunch. Balls at the
	# joints keep the curve round.
	for k in SPINE.size() - 1:
		_tube(t[_skin], SPINE[k], SPINE[k + 1], SPINE_R[k], SPINE_R[k + 1], 8)
		if k > 0:
			_ball(t[_skin], SPINE[k], SPINE_R[k])
	# Ribs on the chest only (nothing sticks out of his back): pale bars under the hunch.
	for i in 5:
		var y := 1.45 + i * 0.17
		var c := _spine_at(y)
		var w := 0.2 + i * 0.012
		_slab(t[_bone], c + Vector3(-w, 0, -w * 0.9), c + Vector3(w, -0.04, -w * 0.9), 0.04, 0.035)
	# The neck, out of the front of the hunch, reaching forward to the mask.
	_tube(t[_skin], SPINE[SPINE.size() - 1], NECK_END, 0.14, 0.09, 6)
	return _finish(t)


## A rough ball of radius `r` at `c`, to round off the joints between tubes.
func _ball(tool: SurfaceTool, c: Vector3, r: float) -> void:
	var profile: Array[Vector2] = []
	for k in 5:
		var a := lerpf(-PI * 0.5, PI * 0.5, k / 4.0)
		profile.append(Vector2(cos(a) * r, r + sin(a) * r))
	_lathe(tool, profile, 8, Transform3D(Basis.IDENTITY, c + Vector3.DOWN * r))


## The point on his spine at height `y` (straight lines between the SPINE points).
func _spine_at(y: float) -> Vector3:
	for k in SPINE.size() - 1:
		var a: Vector3 = SPINE[k]
		var b: Vector3 = SPINE[k + 1]
		if y <= b.y or k == SPINE.size() - 2:
			return a.lerp(b, clampf((y - a.y) / (b.y - a.y), 0.0, 1.0))
	return SPINE[0]


## A mask, taller than wide, facing -Z and centred on the origin, after the user's sketch:
## a jagged star of an outline with its longest points at the top and a ragged beard below
## the mouth, a face that bulges a little, faint growth rings in the grain. `stage` is how
## far the carving has got: 0 a rough oval, 1 grain rings cut in, 2 eyes and mouth marked
## out, 3 finished (glowing eyes). `spikes` is how many points the outline has (0: none).
func _face_mask(radius: float, stage: int, spikes: int) -> ArrayMesh:
	var t := _surfaces([WOOD, BARK, _shadow, _ember])
	var rx := radius * 0.72
	var ry := radius * 1.15
	var depth := radius * 0.22
	# The outline, round from the top: a tip then a notch for each spike.
	var outline: Array[Vector2] = []
	var count := spikes if spikes > 0 else 14
	for i in count:
		for half in 2:
			var a := PI * 0.5 + TAU * (i + half * 0.5) / count + _rng.randf_range(-0.08, 0.08)
			var e := Vector2(cos(a) * rx, sin(a) * ry)
			var grow := 0.0
			if spikes > 0 and half == 0:
				var up := sin(a)
				if up > 0.45:
					grow = 0.75 * up * (1.0 if i % 2 == 0 else 0.55)
				elif up < -0.5:
					grow = 0.3 + 0.2 * (i % 2)
				else:
					grow = 0.22
				grow *= _rng.randf_range(0.8, 1.2)
			elif spikes > 0:
				grow = -0.1
			else:
				grow = _rng.randf_range(-0.04, 0.04)
			outline.append(e * (1.0 + grow))
	# Front: a low cone from the edge to the bulge in the middle; back: flat-ish; the edge
	# between them is bark.
	var front_middle := Vector3(0, 0, -depth)
	var back_middle := Vector3(0, 0, depth * 0.5)
	for k in outline.size():
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		var pf := Vector3(p.x, p.y, -depth * 0.3)
		var qf := Vector3(q.x, q.y, -depth * 0.3)
		var pb := Vector3(p.x, p.y, depth * 0.3)
		var qb := Vector3(q.x, q.y, depth * 0.3)
		_face(t[WOOD], [front_middle, pf, qf], Vector3.FORWARD)
		_face(t[BARK], [back_middle, pb, qb], Vector3.BACK)
		_face(t[BARK], [pf, qf, qb, pb], Vector3((p.x + q.x) * 0.5, (p.y + q.y) * 0.5, 0.0))
	if stage >= 1:
		# Grain: faint oval rings standing just proud of the face.
		for s in [0.78, 0.55, 0.32]:
			var prev := Vector3.ZERO
			for k in 15:
				var a := TAU * k / 14.0
				var p := Vector3(cos(a) * rx * s, sin(a) * ry * s, _front_z(depth, s) - radius * 0.012)
				if k > 0:
					_tube(t[BARK], prev, p, radius * 0.014, radius * 0.014, 4)
				prev = p
	if stage < 2:
		return _finish(t)
	# Three eyes: one high on the brow, two below it. Sockets cut dark, the ember glow
	# standing out of them once finished.
	for eye in [Vector2(0.0, 0.5), Vector2(-0.3, 0.08), Vector2(0.3, 0.08)]:
		var c := Vector3(eye.x * radius, eye.y * radius, 0.0)
		c.z = _front_z(depth, Vector2(c.x / rx, c.y / ry).length())
		var socket: Array[Vector2] = [Vector2(0, 0), Vector2(radius * 0.15, 0), Vector2(radius * 0.13, depth * 0.3), Vector2(0, depth * 0.3)]
		_lathe(t[_shadow], socket, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3(0.85, 1.0, 1.0)), c))
		if stage >= 3:
			var glow: Array[Vector2] = [Vector2(0, 0), Vector2(radius * 0.1, 0), Vector2(radius * 0.06, depth * 0.3), Vector2(0, depth * 0.4)]
			_lathe(t[_ember], glow, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), c + Vector3(0, 0, -depth * 0.25)))
	# The sad mouth: an arch whose corners hang down low.
	var prev := Vector3.ZERO
	for k in 9:
		var u := lerpf(-1.0, 1.0, k / 8.0)
		var p := Vector3(u * radius * 0.36, -radius * (0.38 + 0.32 * u * u), 0.0)
		p.z = _front_z(depth, Vector2(p.x / rx, p.y / ry).length()) - radius * 0.02
		if k > 0:
			_tube(t[_shadow], prev, p, radius * 0.055, radius * 0.055, 5)
		prev = p
	return _finish(t)


## How far forward the mask's face stands at `d` of the way out from its middle (0..1).
func _front_z(depth: float, d: float) -> float:
	return lerpf(-depth, -depth * 0.3, clampf(d, 0.0, 1.0))


## The lamps round him. A lantern: a small iron box with a flame showing through, hung by
## its ring at the origin.
func _lantern_mesh() -> ArrayMesh:
	var t := _surfaces([METAL, _flame])
	var body: Array[Vector2] = [Vector2(0, -0.42), Vector2(0.12, -0.42), Vector2(0.14, -0.38), Vector2(0.14, -0.12), Vector2(0.06, -0.04), Vector2(0, -0.04)]
	_lathe(t[METAL], body, 4, Transform3D.IDENTITY)
	_tube(t[METAL], Vector3(0, -0.05, 0), Vector3(0, 0.0, 0), 0.03, 0.03, 4)
	var flame: Array[Vector2] = [Vector2(0, -0.39), Vector2(0.155, -0.36), Vector2(0.155, -0.16), Vector2(0, -0.13)]
	_lathe(t[_flame], flame, 4, Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3.ZERO))
	return _finish(t)


## A fat candle with its flame, standing at the origin.
func _candle_mesh() -> ArrayMesh:
	var t := _surfaces([_shaving, _flame])
	_tube(t[_shaving], Vector3.ZERO, Vector3(0, 0.22, 0), 0.07, 0.065, 6)
	var flame: Array[Vector2] = [Vector2(0, 0.22), Vector2(0.035, 0.27), Vector2(0, 0.36)]
	_lathe(t[_flame], flame, 5, Transform3D.IDENTITY)
	return _finish(t)


## An iron brazier on three legs, heaped with embers.
func _brazier_mesh() -> ArrayMesh:
	var t := _surfaces([METAL, _ember, _flame])
	var bowl: Array[Vector2] = [Vector2(0, 0.55), Vector2(0.2, 0.55), Vector2(0.45, 0.8), Vector2(0.42, 0.82), Vector2(0, 0.62)]
	_lathe(t[METAL], bowl, 8, Transform3D.IDENTITY)
	for k in 3:
		var a := TAU * k / 3.0
		_tube(t[METAL], Vector3(cos(a) * 0.3, 0.7, sin(a) * 0.3), Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), 0.03, 0.03, 4)
	for k in 7:
		var a := TAU * k / 7.0
		var at := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.08, 0.3) + Vector3.UP * 0.7
		_tube(t[_ember], at, at + Vector3(_rng.randf_range(-0.1, 0.1), 0.08, _rng.randf_range(-0.1, 0.1)), 0.07, 0.05, 5)
	var flame: Array[Vector2] = [Vector2(0, 0.72), Vector2(0.18, 0.8), Vector2(0, 1.15)]
	_lathe(t[_flame], flame, 5, Transform3D.IDENTITY)
	return _finish(t)


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
	# Lights round him: lanterns hung from the branches, candles on the stump, the roots
	# and the workbench, and a brazier of embers out front. Most of them flicker.
	var lights := _pivot(root, "Lights", Vector3.ZERO)
	var branches := _branches()
	for i in [0, 2, 4, 6, 8, 10]:
		var points: Array = branches[i]
		var p: Vector3 = (points[1] as Vector3).lerp(points[2], 0.5 + 0.15 * (i % 3))
		var hang := _pivot(lights, "Lantern%d" % (i / 2), p)
		var drop: float = 0.4 + 0.15 * (i % 3)
		var cord := MeshInstance3D.new()
		cord.name = "String"
		var line := CylinderMesh.new()
		line.top_radius = 0.01
		line.bottom_radius = 0.01
		line.height = drop
		line.radial_segments = 4
		line.material = _shadow
		cord.mesh = line
		cord.position = Vector3(0, -drop * 0.5, 0)
		hang.add_child(cord)
		_part(hang, "Lantern", "lantern").position = Vector3(0, -drop, 0)
		_lamp(hang, "Light", Vector3(0, -drop - 0.25, 0), LAMP_LIGHT, 1.4, 4.5, true)
	var candles := [
		# On the stump's cut top, round the front edge.
		Vector3(-0.95, STUMP_H, -0.7), Vector3(-0.55, STUMP_H, -1.05), Vector3(0.75, STUMP_H, -0.9),
		Vector3(1.05, STUMP_H, -0.45),
		# On the roots.
		Vector3(-2.2, 0.3, -1.6), Vector3(2.0, 0.3, -2.05), Vector3(-2.5, 0.25, 1.4),
		# On the workbench.
		Vector3(2.6, 0.85, 1.0), Vector3(2.85, 0.85, 1.3),
	]
	for i in candles.size():
		var spot := _pivot(lights, "Candle%d" % i, candles[i])
		_part(spot, "Candle", "candle")
		# One light per little group of candles is enough.
		if i in [0, 3, 4, 5, 6, 7]:
			_lamp(spot, "Light", Vector3(0, 0.5, 0), LAMP_LIGHT, 0.9, 3.0, true)
	var brazier := _pivot(lights, "Brazier", Vector3(-1.1, 0, -3.1))
	_part(brazier, "Brazier", "brazier")
	_lamp(brazier, "Light", Vector3(0, 1.3, 0), Color("ff8a3c"), 2.2, 6.5, true)
	# Him: the pelvis on the stump, the mask on his bowed neck.
	var body := _pivot(root, "Body", Vector3(0, STUMP_H + 0.05, 0.1), true)
	_part(body, "Torso", "body")
	var head := _pivot(body, "Head", NECK_END + Vector3(0, 0.25, -0.25), true)
	head.rotation.x = 0.15
	_part(head, "Mask", "face")
	# A dim ember light just in front of the mask, so the eyes cast a glow on it.
	_lamp(head, "EyeGlow", Vector3(0, 0.2, -0.6), Color("ff6a2c"), 0.8, 2.2)
	# The arms, fanned round his chest, elbows bending forward so the hands meet in front.
	# Along the long torso: the arms that hang low grow from low on it, the raised ones
	# from up under the hunch.
	for i in ARMS:
		var u := float(i) / (ARMS - 1)
		var angle := lerpf(FAN_FROM, FAN_TO, u)
		var out := Vector3(sin(angle), -cos(angle), 0.0)
		var low := 1.0 - absf(angle) / PI
		var root_at := _spine_at(lerpf(2.7, 1.5, low)) + Vector3(out.x * 0.24, 0.0, -0.06)
		var shoulder := _pivot(body, "Shoulder%d" % i, root_at, true)
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


## A warm point light, flickering like a flame when `flicker` is set.
func _lamp(p: Node3D, node_name: String, at: Vector3, col: Color, energy: float, reach: float, flicker := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = col
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.2
	if flicker:
		light.set_script(FLICKER)
	p.add_child(light)
	return light


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
