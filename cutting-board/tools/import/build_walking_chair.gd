extends "res://tools/import/mesh_builder.gd"

## Builds the walking chair, a monster made from a reference sculpture: a pale Windsor
## chair (curved top rail, six spindles, a dished round seat) whose four wooden legs turn,
## halfway down, into long gray clay limbs that walk on big bony hands. Under the front of
## the seat hangs a pale skull face. In this world a face is a mask and a mask is a
## faction, so the skull is carved as a bone mask: the chair has taken a face of its own.
##
## The parts are saved as meshes under assets/meshes/characters/ (one thigh, shin and hand
## shared by all four limbs) and put together in scenes/characters/walking_chair.tscn as a
## chain of pivots per limb: Hip > Knee > Wrist, named per corner (HipFL, KneeFL, WristFL,
## ... F/B front/back, L/R left/right). The pivots, Body and Neck are scene-unique names so
## an animator can turn them as %KneeFL and so on. The chair faces -Z like the game's other
## characters. It is posed in the reference's stance: three hands on the ground, the front
## right arm reaching forward, bent at the elbow, its hand clawing.
##
## Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://tools/import/build_walking_chair.gd

const MESH_DIR := "res://assets/meshes/characters/"
const SCENE_PATH := "res://scenes/characters/walking_chair.tscn"
const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const FLESH_PATH := "res://assets/materials/characters/chair_flesh.tres"
const BONE_PATH := "res://assets/materials/characters/chair_bone_mask.tres"

const FLESH_COLOR := Color("8a8480")
const BONE_COLOR := Color("ebe6da")
const SOCKET_COLOR := Color("2a2220")

## The seat's radius, metres.
const SEAT_RADIUS := 0.26
## Upper limb: wood down to WOOD_END, then the gray sleeve over the knee.
const THIGH := 0.46
const WOOD_END := 0.3
const SHIN := 0.62
## Where the hands' pivots sit above the ground when the fingertips rest on it.
const WRIST_HEIGHT := 0.075

## (corner, hip position under the seat, hip pitch, hip roll, knee pitch, knee roll).
## Positive pitch swings the limb forward (-Z), positive roll swings it to +X (right).
const LIMBS := [
	["FL", Vector3(-0.17, 0.0, -0.15), 0.32, -0.3, -0.25, 0.18],
	["FR", Vector3(0.17, 0.0, -0.15), 0.15, 0.12, 1.35, -0.05],
	["BL", Vector3(-0.17, 0.0, 0.15), -0.32, -0.3, 0.25, 0.18],
	["BR", Vector3(0.17, 0.0, 0.15), -0.32, 0.3, 0.25, -0.18],
]
## The skull face is modelled at a small skull's size and hung a third larger, as big as
## in the reference.
const SKULL_SCALE := 1.3
## The limb that reaches instead of standing.
const REACHING := "FR"

## One step of the test walk (both diagonal pairs swing once), seconds, and its keys.
const WALK_TIME := 1.1
const WALK_KEYS := 8

var _flesh: StandardMaterial3D
var _bone: StandardMaterial3D
var _socket: StandardMaterial3D
var _unique: Array[Node] = []


func _init() -> void:
	uv_scale = 3.0
	_flesh = _matte(FLESH_COLOR, FLESH_PATH)
	_bone = _matte(BONE_COLOR, BONE_PATH)
	_socket = StandardMaterial3D.new()
	_socket.albedo_color = SOCKET_COLOR
	_socket.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var builders := {
		"seat": _seat_mesh, "thigh": _thigh_mesh, "shin": _shin_mesh,
		"hand": _hand_mesh, "skull": _skull_mesh,
	}
	var ok := true
	for key in builders:
		ok = _save_to(builders[key].call(), MESH_DIR + "walking_chair_%s.res" % key) and ok
	ok = ok and _build_scene() == OK
	print("walking chair: ", "saved " + SCENE_PATH if ok else "FAILED")
	quit(0 if ok else 1)


func _matte(col: Color, path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ResourceSaver.save(mat, path)
	return load(path)


func _save_to(mesh: ArrayMesh, path: String) -> bool:
	var error := ResourceSaver.save(mesh, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		return false
	print("Built %s with %d triangles." % [path, _triangles])
	_triangles = 0
	return true


# --- meshes ------------------------------------------------------------------------------


## The dished seat, six spindles and the curved top rail. The seat's top is at y 0.05
## above the hips' plane.
func _seat_mesh() -> ArrayMesh:
	var tool := _begin()
	var seat: Array[Vector2] = [
		Vector2(0.0, -0.01), Vector2(SEAT_RADIUS - 0.03, -0.01), Vector2(SEAT_RADIUS, 0.025),
		Vector2(SEAT_RADIUS, 0.045), Vector2(SEAT_RADIUS - 0.03, 0.055), Vector2(0.0, 0.035),
	]
	_lathe(tool, seat, 12, Transform3D(Basis.from_scale(Vector3(1.05, 1.0, 0.92)), Vector3.ZERO))
	# Spindles fan up from the back of the seat to the rail, leaning back a little.
	for i in 6:
		var x := lerpf(-0.16, 0.16, i / 5.0)
		var bottom := Vector3(x * 0.9, 0.04, 0.17 + absf(x) * -0.15)
		var top := Vector3(x * 1.15, 0.6, 0.24 + absf(x) * -0.25)
		_tube(tool, bottom, top, 0.012, 0.01, 5)
	# The top rail: a bent board, wider than the spindles, in short flat pieces.
	var pieces := 6
	for i in pieces:
		var x0 := lerpf(-0.24, 0.24, float(i) / pieces)
		var x1 := lerpf(-0.24, 0.24, float(i + 1) / pieces)
		var z0 := 0.24 - x0 * x0 * 1.3
		var z1 := 0.24 - x1 * x1 * 1.3
		_slab(tool, Vector3(x0, 0.58, z0), Vector3(x1, 0.58, z1), 0.1, 0.025)
	var mesh := ArrayMesh.new()
	_commit(mesh, tool, WOOD)
	return mesh


## The upper limb, hanging down from the hip: a turned wooden leg that ends in a lump of
## gray clay wrapped over the knee.
func _thigh_mesh() -> ArrayMesh:
	var wood := _begin()
	var leg: Array[Vector2] = [
		Vector2(0.0, -WOOD_END - 0.02), Vector2(0.03, -WOOD_END - 0.02), Vector2(0.034, -0.18),
		Vector2(0.04, -0.06), Vector2(0.036, 0.0), Vector2(0.0, 0.0),
	]
	_lathe(wood, leg, 7, Transform3D.IDENTITY)
	var clay := _begin()
	var sleeve: Array[Vector2] = [
		Vector2(0.0, -THIGH - 0.035), Vector2(0.032, -THIGH - 0.02), Vector2(0.042, -THIGH),
		Vector2(0.034, -0.38), Vector2(0.04, -WOOD_END + 0.01), Vector2(0.036, -WOOD_END + 0.04),
		Vector2(0.0, -WOOD_END + 0.045),
	]
	_lathe(clay, sleeve, 7, Transform3D.IDENTITY)
	var mesh := ArrayMesh.new()
	_commit(mesh, wood, WOOD)
	_commit(mesh, clay, _flesh)
	return mesh


## The long thin forearm from the knee to the wrist, a little knobbly.
func _shin_mesh() -> ArrayMesh:
	var tool := _begin()
	var shin: Array[Vector2] = [
		Vector2(0.0, -SHIN - 0.02), Vector2(0.026, -SHIN), Vector2(0.022, -SHIN + 0.05),
		Vector2(0.03, -0.38), Vector2(0.024, -0.2), Vector2(0.034, -0.03), Vector2(0.0, 0.03),
	]
	_lathe(tool, shin, 7, Transform3D.IDENTITY)
	var mesh := ArrayMesh.new()
	_commit(mesh, tool, _flesh)
	return mesh


## A big bony hand lying flat from the wrist toward -Z: a palm, four long jointed fingers
## that arch up and claw down to the ground, and a thumb to the inside (-X).
func _hand_mesh() -> ArrayMesh:
	var tool := _begin()
	_slab(tool, Vector3(0, -0.035, 0.0), Vector3(0, -0.035, -0.12), 0.09, 0.035)
	_tube(tool, Vector3(0, 0.02, 0.0), Vector3(0, -0.03, -0.03), 0.03, 0.035, 6)
	for i in 4:
		var x := lerpf(-0.034, 0.034, i / 3.0)
		var spread := lerpf(-0.22, 0.22, i / 3.0)
		var length := 0.11 if i == 1 or i == 2 else 0.095
		var heading := Vector3(sin(spread), 0.0, -cos(spread))
		var base := Vector3(x, -0.035, -0.115)
		var knuckle := base + heading * length + Vector3(0, 0.035, 0)
		var tip := knuckle + heading * length * 0.6 + Vector3(0, -0.08, 0)
		_tube(tool, base, knuckle, 0.013, 0.011, 5)
		_tube(tool, knuckle, tip, 0.011, 0.005, 5)
	var thumb_base := Vector3(-0.045, -0.035, -0.05)
	var thumb_knuckle := thumb_base + Vector3(-0.07, 0.025, -0.04)
	_tube(tool, thumb_base, thumb_knuckle, 0.013, 0.01, 5)
	_tube(tool, thumb_knuckle, thumb_knuckle + Vector3(-0.03, -0.045, -0.04), 0.01, 0.005, 5)
	var mesh := ArrayMesh.new()
	_commit(mesh, tool, _flesh)
	return mesh


## The skull face, centred on its pivot and looking down -Z: a round bone cranium with a
## narrower jaw, two big dark sockets and a row of teeth.
func _skull_mesh() -> ArrayMesh:
	var bone := _begin()
	_lathe(bone, _ball_profile(0.12, 7), 9, Transform3D(Basis.from_scale(Vector3(1.0, 0.92, 1.0)), Vector3.ZERO))
	var jaw: Array[Vector2] = [
		Vector2(0.0, -0.15), Vector2(0.045, -0.15), Vector2(0.07, -0.11), Vector2(0.08, -0.06),
		Vector2(0.0, -0.04),
	]
	_lathe(bone, jaw, 8, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.85)), Vector3(0, 0, -0.035)))
	var socket := _begin()
	for x in [-0.048, 0.048]:
		var at := Transform3D(Basis.from_scale(Vector3(1.0, 1.1, 0.45)), Vector3(x, -0.005, -0.098))
		_lathe(socket, _ball_profile(0.04, 5), 8, at)
	# Nose hole and teeth.
	_lathe(socket, _ball_profile(0.016, 4), 6, Transform3D(Basis.from_scale(Vector3(1.0, 1.4, 0.5)), Vector3(0, -0.06, -0.106)))
	for i in 5:
		var x := lerpf(-0.03, 0.03, i / 4.0)
		_slab(socket, Vector3(x, -0.105, -0.1), Vector3(x, -0.135, -0.098), 0.004, 0.01)
	var mesh := ArrayMesh.new()
	_commit(mesh, bone, _bone)
	_commit(mesh, socket, _socket)
	return mesh


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
	# For a mostly level slab "up" is its thickness; for a standing one it is its depth.
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


## A sphere's half outline from its bottom pole to its top pole.
func _ball_profile(r: float, rings: int) -> Array[Vector2]:
	var profile: Array[Vector2] = []
	for i in rings + 1:
		var t := PI * i / rings
		profile.append(Vector2(sin(t) * r, -cos(t) * r))
	return profile


# --- scene -------------------------------------------------------------------------------


func _build_scene() -> Error:
	var root := Node3D.new()
	root.name = "WalkingChair"
	var body := _pivot(root, "Body", Vector3.ZERO, true)
	_part(body, "Seat", "seat")
	var neck := _pivot(body, "Neck", Vector3(0, -0.02, -0.2), true)
	neck.rotation.x = -0.25
	var skull := _part(neck, "Skull", "skull")
	skull.position = Vector3(0, -0.16, -0.06)
	skull.scale = Vector3.ONE * SKULL_SCALE
	var lowest := INF
	for limb in LIMBS:
		var corner: String = limb[0]
		var hip := _pivot(body, "Hip" + corner, limb[1], true)
		hip.rotation = Vector3(limb[2], 0.0, limb[3])
		_part(hip, "Thigh", "thigh")
		var knee := _pivot(hip, "Knee" + corner, Vector3(0, -THIGH, 0), true)
		knee.rotation = Vector3(limb[4], 0.0, limb[5])
		_part(knee, "Shin", "shin")
		var wrist := _pivot(knee, "Wrist" + corner, Vector3(0, -SHIN, 0), true)
		_part(wrist, "Hand", "hand")
		# Lay the hand flat facing forward and a little outward; the reaching one claws down.
		var heading := Basis(Vector3.UP, -0.25 * signf(hip.position.x))
		if corner == REACHING:
			heading = Basis(Vector3.RIGHT, -0.6)
		wrist.basis = _global(knee).basis.inverse() * heading
		if corner != REACHING:
			lowest = minf(lowest, _global(wrist).origin.y)
	body.position.y = WRIST_HEIGHT - lowest
	_add_walk(root, body)
	_own(root, root)
	for n in _unique:
		n.unique_name_in_owner = true
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, SCENE_PATH)
	root.free()
	return error


## A test walk on all four hands, in place: diagonal pairs (FL with BR, FR with BL) swing
## together, each lifting its knee on the way forward, while the seat bobs and rocks. The
## reaching arm walks too, from the front left limb's stance mirrored. The wrists are keyed
## so the hands stay flat to the ground, worked out the same way as the still pose.
func _add_walk(root: Node3D, body: Node3D) -> void:
	var anim := Animation.new()
	anim.length = WALK_TIME
	anim.loop_mode = Animation.LOOP_LINEAR
	var rest_y := body.position.y
	var bob := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bob, "Body:position")
	var rock := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rock, "Body:rotation")
	var tracks := {}
	for limb in LIMBS:
		for joint in ["Hip", "Knee", "Wrist"]:
			var track := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track, "Body/%s%s:rotation" % [joint, limb[0]])
			tracks[joint + limb[0]] = track
	var nodes := {}
	for limb in LIMBS:
		var hip := body.get_node("Hip" + limb[0]) as Node3D
		nodes[limb[0]] = [hip, hip.get_node("Knee" + limb[0]), hip.get_node("Knee%s/Wrist%s" % [limb[0], limb[0]])]
	for step in WALK_KEYS + 1:
		var t := WALK_TIME * step / WALK_KEYS
		var phase := TAU * step / WALK_KEYS
		body.position.y = rest_y + 0.03 * cos(phase * 2.0)
		body.rotation = Vector3(0.0, 0.0, 0.04 * sin(phase))
		anim.track_insert_key(bob, t, body.position)
		anim.track_insert_key(rock, t, body.rotation)
		for limb in LIMBS:
			var corner: String = limb[0]
			var stance: Array = LIMBS[0] if corner == REACHING else limb
			var side := signf(float(limb[1].x))
			var diagonal := corner == "FL" or corner == "BR"
			var swing := phase + (0.0 if diagonal else PI)
			var hip: Node3D = nodes[corner][0]
			var knee: Node3D = nodes[corner][1]
			var wrist: Node3D = nodes[corner][2]
			hip.rotation = Vector3(stance[2] + 0.3 * sin(swing), 0.0, absf(stance[3]) * side)
			# The knee folds only while the limb swings forward (the first half of its turn).
			var lift := maxf(0.0, cos(swing)) * 0.5
			knee.rotation = Vector3(stance[4] - lift * signf(float(limb[1].z) + 0.001), 0.0, -absf(stance[5]) * side)
			wrist.basis = _global(knee).basis.inverse() * Basis(Vector3.UP, -0.25 * side)
			anim.track_insert_key(tracks["Hip" + corner], t, hip.rotation)
			anim.track_insert_key(tracks["Knee" + corner], t, knee.rotation)
			anim.track_insert_key(tracks["Wrist" + corner], t, wrist.rotation)
	# Put the still pose back: the scene opens in the reference's stance.
	body.position.y = rest_y
	body.rotation = Vector3.ZERO
	for limb in LIMBS:
		var hip: Node3D = nodes[limb[0]][0]
		var knee: Node3D = nodes[limb[0]][1]
		hip.rotation = Vector3(limb[2], 0.0, limb[3])
		knee.rotation = Vector3(limb[4], 0.0, limb[5])
	var library := AnimationLibrary.new()
	library.add_animation("walk", anim)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", library)
	root.add_child(player)
	_unique.append(player)
	# The wrists' still pose is re-derived from the restored hips and knees.
	for limb in LIMBS:
		var knee: Node3D = nodes[limb[0]][1]
		var wrist: Node3D = nodes[limb[0]][2]
		var heading := Basis(Vector3.UP, -0.25 * signf(float(limb[1].x)))
		if limb[0] == REACHING:
			heading = Basis(Vector3.RIGHT, -0.6)
		wrist.basis = _global(knee).basis.inverse() * heading


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
	m.mesh = load(MESH_DIR + "walking_chair_%s.res" % mesh_key)
	p.add_child(m)
	return m


## `n`'s transform relative to the scene root, worked out without a tree.
func _global(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p != null:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t


func _own(n: Node, owner_node: Node) -> void:
	for child in n.get_children():
		child.owner = owner_node
		_own(child, owner_node)
