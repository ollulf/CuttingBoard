extends SceneTree

## Builds the player's first-person arms — the forearm and hand of each side, with a bit
## of upper arm behind them — out of the same human_base.obj every human body is made of,
## so the hands the player sees are the hands their character actually has.
##
## Each arm is skinned to three bones, UpperArm > Forearm > Hand, which the
## ArmLeftSkeleton / ArmRightSkeleton nodes in player.tscn carry at the rest positions
## printed here: the upper arm from the cut end, the forearm from the elbow, the hand
## from the wrist. Weights blend over ELBOW_BLEND / WRIST_BLEND either side of each
## joint, so a bent elbow or wrist folds the skin instead of tearing it.
##
## Each arm is cut out of the model's own arm piece and laid down the way ArmLeft /
## ArmRight in player.tscn expect: the forearm pointing forward along -Z, the back of the
## hand up, and the palm at HAND_SLOT, where HandSlotLeft / HandSlotRight sit. The node's
## origin stays where the middle of the old box arm was, which is about at the elbow.
##
## Run it again whenever the model or the tables below change:
##   godot --headless --path cutting-board -s res://tools/import/build_fp_arms.gd

const Body := preload("res://tools/import/build_human_body.gd")

const OUT_MESHES := {
	"Right": "res://assets/meshes/characters/fp_arm_right.res",
	"Left": "res://assets/meshes/characters/fp_arm_left.res",
}

## Where the palm ends up in the arm node's space — the hand slots' position.
const HAND_SLOT := Vector3(0.0, 0.0, -0.3)
## How far up from the fingertips the middle of the palm is, in metres.
const PALM_FROM_FINGERTIPS := 0.11
## How much of the upper arm is kept above the elbow, in metres. The shoulder above it
## is left off: it would only show as a ball floating behind a punch. Long enough that
## the cut end stays below the view while the punch reaches the middle of the screen.
const UPPER_ARM_KEPT := 0.3
## First-person arms are drawn a little larger than life, so they read at the edges of
## a low-resolution screen.
const VIEW_SCALE := 1.15
## How far up from the fingertips the wrist is, in metres: where the Hand bone starts.
const WRIST_FROM_FINGERTIPS := 0.19
## Half the stretch of arm, in the arm node's metres, over which each joint's weights
## blend from one bone to the next.
const ELBOW_BLEND := 0.05
const WRIST_BLEND := 0.03

## The skin's bones by index, in the order the Skeleton3D in player.tscn lists them.
enum Bone { UPPER_ARM, FOREARM, HAND }

var _parent := PackedInt32Array()


func _init() -> void:
	var source := load(Body.SOURCE_MESH) as ArrayMesh
	if source == null:
		push_error("Could not load %s" % Body.SOURCE_MESH)
		quit(1)
		return
	for side: String in OUT_MESHES:
		var mesh := _build_arm(source, side)
		if mesh == null:
			quit(1)
			return
		var error := ResourceSaver.save(mesh, OUT_MESHES[side])
		if error != OK:
			push_error("Could not save %s: %s" % [OUT_MESHES[side], error_string(error)])
			quit(1)
			return
		print("Built %s with %d triangles." % [OUT_MESHES[side], mesh.surface_get_array_index_len(0) / 3])
	quit()


func _build_arm(source: ArrayMesh, side: String) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var mirror := Vector3(1.0 if side == "Right" else -1.0, 1.0, 1.0)
	var elbow := Body.ELBOW * mirror
	var fingertips := Body.FINGERTIPS * mirror

	# Body space, as build_human_body.gd lays the model out: scaled, facing -Z.
	var turn := Basis(Vector3.UP, PI)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in vertices.size():
		vertices[i] = turn * vertices[i] * Body.MODEL_SCALE
		normals[i] = turn * normals[i]

	# The forearm's direction becomes -Z, the body's front (the back of a hanging hand
	# faces outward, its thumb forward) becomes +Y.
	var down := (fingertips - elbow).normalized()
	var front := (Vector3.FORWARD - down * Vector3.FORWARD.dot(down)).normalized()
	var to_view := Basis(down.cross(front), front, -down).inverse()
	var palm := fingertips - down * PALM_FROM_FINGERTIPS
	var to_arm := Transform3D(Basis.from_scale(Vector3.ONE * VIEW_SCALE), HAND_SLOT) \
			* Transform3D(to_view, Vector3.ZERO) * Transform3D(Basis(), -palm)

	# The joints in the arm node's space. The upper arm bone starts at the cut end, so
	# turning it swings the whole arm from the shoulder side.
	var elbow_at := to_arm * elbow
	var wrist_at := to_arm * (fingertips - down * WRIST_FROM_FINGERTIPS)
	var shoulder_at := to_arm * (elbow - down * UPPER_ARM_KEPT)
	print("%s bones: UpperArm %s, Forearm %s, Hand %s" % [side, shoulder_at, elbow_at, wrist_at])

	var arm_root := _arm_piece(vertices, indices, side)
	if arm_root < 0:
		push_error("No %s arm piece found in %s" % [side.to_lower(), Body.SOURCE_MESH])
		return null

	# The upper arm is sliced through square to the forearm, UPPER_ARM_KEPT above the
	# elbow: each triangle is clipped to the kept side, and every edge the slice opens
	# is remembered for the cap.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[PackedVector3Array] = []
	for t in range(0, indices.size(), 3):
		if _find(indices[t]) != arm_root:
			continue
		var points: Array[Vector3] = []
		var point_normals: Array[Vector3] = []
		var cut_from := -1
		for k in 3:
			var i := indices[t + k]
			var j := indices[t + (k + 1) % 3]
			var here := _kept_depth(vertices[i], elbow, down)
			var next := _kept_depth(vertices[j], elbow, down)
			if here >= 0.0:
				points.append(vertices[i])
				point_normals.append(normals[i])
			if (here >= 0.0) != (next >= 0.0):
				var w := here / (here - next)
				if here >= 0.0:
					cut_from = points.size()
				points.append(vertices[i].lerp(vertices[j], w))
				point_normals.append(normals[i].lerp(normals[j], w).normalized())
		if points.size() < 3:
			continue
		if cut_from >= 0:
			# Leaving the kept side, then coming back: the edge between is the slice.
			rim.append(PackedVector3Array([points[cut_from], points[(cut_from + 1) % points.size()]]))
		for k in range(1, points.size() - 1):
			for index in [0, k, k + 1]:
				var at: Vector3 = to_arm * points[index]
				_set_skin(tool, at, elbow_at, wrist_at)
				tool.set_normal((to_view * point_normals[index]).normalized())
				tool.add_vertex(at)

	# A fan of flat triangles closes the slice, so a punch that carries the arm forward
	# shows a solid end rather than a hollow sleeve.
	var centre := Vector3.ZERO
	for edge in rim:
		centre += edge[0]
	centre /= maxf(rim.size(), 1.0)
	var cap_normal := (to_view * -down).normalized()
	for edge in rim:
		# Wound against the edge's own triangle, so the cap faces out of the arm.
		for point in [edge[1], edge[0], centre]:
			var at: Vector3 = to_arm * point
			_set_skin(tool, at, elbow_at, wrist_at)
			tool.set_normal(cap_normal)
			tool.add_vertex(at)
	tool.index()
	return tool.commit()


## Weights a vertex by how far along the arm it is: all upper arm behind the elbow, all
## hand past the wrist, and shared smoothly across each joint.
func _set_skin(tool: SurfaceTool, at: Vector3, elbow_at: Vector3, wrist_at: Vector3) -> void:
	var past_elbow := smoothstep(elbow_at.z + ELBOW_BLEND, elbow_at.z - ELBOW_BLEND, at.z)
	var past_wrist := smoothstep(wrist_at.z + WRIST_BLEND, wrist_at.z - WRIST_BLEND, at.z)
	tool.set_bones(PackedInt32Array([Bone.UPPER_ARM, Bone.FOREARM, Bone.HAND, 0]))
	tool.set_weights(PackedFloat32Array([
		1.0 - past_elbow, past_elbow * (1.0 - past_wrist), past_elbow * past_wrist, 0.0]))


## How far a body-space point is on the kept side of the slice; negative is cut away.
func _kept_depth(point: Vector3, elbow: Vector3, down: Vector3) -> float:
	return (point - elbow).dot(down) + UPPER_ARM_KEPT


## The union-find root of the model's arm piece on this side, the same piece
## build_human_body.gd skins to the arm bones, or -1 if there is none.
func _arm_piece(vertices: PackedVector3Array, indices: PackedInt32Array, side: String) -> int:
	_parent.resize(vertices.size())
	for i in vertices.size():
		_parent[i] = i
	var at_position := {}
	for i in vertices.size():
		var key := vertices[i].snappedf(0.0001)
		if at_position.has(key):
			_parent[_find(i)] = _find(at_position[key])
		else:
			at_position[key] = i
	for t in range(0, indices.size(), 3):
		_parent[_find(indices[t])] = _find(indices[t + 1])
		_parent[_find(indices[t + 1])] = _find(indices[t + 2])

	var sums := {}
	var counts := {}
	for i in vertices.size():
		var root := _find(i)
		sums[root] = sums.get(root, Vector3.ZERO) + vertices[i]
		counts[root] = counts.get(root, 0) + 1
	var sign := 1.0 if side == "Right" else -1.0
	for root: int in sums:
		var centre: Vector3 = sums[root] / counts[root]
		if centre.x * sign > 0.15 and centre.y > Body.LEG_TOP:
			return root
	return -1


func _find(i: int) -> int:
	while _parent[i] != i:
		i = _parent[i]
	return i
