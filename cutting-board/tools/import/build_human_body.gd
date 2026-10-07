extends SceneTree

## Builds the body every human character shares — res://scenes/characters/human_body.tscn
## — out of the static human_base.obj.
##
## The model comes without a skeleton, so this makes one: it places a chain of joints
## inside the model, skins every vertex to the bones it belongs to, and gives each bone a
## PhysicalBone3D with a collision shape, a mass and joint limits, ready for HumanBody to
## ragdoll. The model is made of separate pieces — head, arms, feet, and one for the
## torso and legs — and each piece is only ever skinned to its own bones, so an arm never
## drags the side of the chest along with it.
##
## Run it again whenever the model or the tables below change:
##   godot --headless --path cutting-board -s res://tools/import/build_human_body.gd
## The generated scene is overwritten, so tune the body here rather than in the editor.
## What HumanBody exports (flinch timing, impulse scale, material) is set per instance
## and survives a rebuild.

const SOURCE_MESH := "res://assets/meshes/characters/human_base.obj"
const OUT_MESH := "res://assets/meshes/characters/human_base_skinned.res"
const OUT_SCENE := "res://scenes/characters/human_body.tscn"
const BODY_SCRIPT := "res://scenes/characters/human_body.gd"

## The model is authored 1.34 m tall facing +Z; characters are 1.7 m and face -Z. Both
## are baked into the mesh so no physics body ever sits under a scaled parent.
const MODEL_SCALE := 1.27

## Joints, in body space: metres, feet at the origin, facing -Z, the character's right
## along +X. Sided joints are given for the right and mirrored for the left.
const PELVIS := Vector3(0.0, 0.787, 0.038)
const WAIST := Vector3(0.0, 1.016, 0.038)
const RIBS := Vector3(0.0, 1.219, 0.038)
const NECK := Vector3(0.0, 1.46, 0.025)
const CROWN := Vector3(0.0, 1.70, 0.0)
const SHOULDER := Vector3(0.21, 1.397, 0.038)
const ELBOW := Vector3(0.267, 1.067, 0.076)
const FINGERTIPS := Vector3(0.298, 0.705, 0.0)
const HIP := Vector3(0.127, 0.762, 0.064)
const KNEE := Vector3(0.14, 0.419, 0.076)
const SOLE := Vector3(0.152, 0.03, 0.07)

## Below this height a vertex of the torso piece belongs to the legs.
const LEG_TOP := 0.838
## Vertices this close to the middle at leg height are the crotch, which stays with the
## hips rather than following either leg.
const CROTCH_HALF_WIDTH := 0.045
## How far past the end of a bone its influence fades out, in metres. Wider is a softer
## bend at the joint.
const BLEND_DISTANCE := 0.075

enum Shape { BOX, CAPSULE, SPHERE }

## Each bone: where it runs, what collides for it and how it may turn against its
## parent. Swing and twist are cone limits in degrees; a hinge bends about the
## character's left-right axis between its lower and upper limits, positive swinging the
## far end backward — a knee bends positive, an elbow negative.
const BONES := [
	{
		"name": "Hips", "parent": "", "head": PELVIS, "tail": WAIST,
		"shape": Shape.BOX, "size": Vector3(0.38, 0.23, 0.27), "mass": 12.0,
	},
	{
		"name": "Spine", "parent": "Hips", "head": WAIST, "tail": RIBS,
		"shape": Shape.BOX, "size": Vector3(0.34, 0.2, 0.26), "mass": 10.0,
		"cone": Vector2(25.0, 15.0),
	},
	{
		"name": "Chest", "parent": "Spine", "head": RIBS, "tail": NECK,
		"shape": Shape.BOX, "size": Vector3(0.38, 0.24, 0.26), "mass": 14.0,
		"cone": Vector2(25.0, 15.0),
	},
	{
		"name": "Head", "parent": "Chest", "head": NECK, "tail": CROWN,
		"shape": Shape.SPHERE, "radius": 0.12, "mass": 5.0,
		"cone": Vector2(40.0, 40.0),
	},
	{
		"name": "UpperArm", "parent": "Chest", "head": SHOULDER, "tail": ELBOW, "sided": true,
		"shape": Shape.CAPSULE, "radius": 0.055, "mass": 2.5,
		"cone": Vector2(80.0, 45.0),
	},
	{
		"name": "Forearm", "parent": "UpperArm", "head": ELBOW, "tail": FINGERTIPS,
		"sided": true, "shape": Shape.CAPSULE, "radius": 0.05, "mass": 2.0,
		"hinge": Vector2(-130.0, 0.0),
	},
	{
		"name": "Thigh", "parent": "Hips", "head": HIP, "tail": KNEE, "sided": true,
		"shape": Shape.CAPSULE, "radius": 0.085, "mass": 8.0,
		"cone": Vector2(50.0, 15.0),
	},
	{
		"name": "Shin", "parent": "Thigh", "head": KNEE, "tail": SOLE, "sided": true,
		"shape": Shape.CAPSULE, "radius": 0.07, "mass": 4.5,
		"hinge": Vector2(0.0, 120.0),
	},
]

## Physics settings every bone starts with — the limp body's. HumanBody swaps in its
## own while a flinch plays out.
const FRICTION := 0.8
const LINEAR_DAMP := 0.1
const ANGULAR_DAMP := 2.0

## Union-find links between vertices, for telling the model's pieces apart.
var _parent := PackedInt32Array()


func _init() -> void:
	var bones := _expand_sides()
	var source := load(SOURCE_MESH) as ArrayMesh
	if source == null:
		push_error("Could not load %s" % SOURCE_MESH)
		quit(1)
		return

	var mesh := _build_skinned_mesh(source, bones)
	var error := ResourceSaver.save(mesh, OUT_MESH)
	if error != OK:
		push_error("Could not save %s: %s" % [OUT_MESH, error_string(error)])
		quit(1)
		return
	mesh.take_over_path(OUT_MESH)

	var root := _build_scene(mesh, bones)
	var scene := PackedScene.new()
	scene.pack(root)
	error = ResourceSaver.save(scene, OUT_SCENE)
	root.free()
	if error != OK:
		push_error("Could not save %s: %s" % [OUT_SCENE, error_string(error)])
		quit(1)
		return
	print("Built %s with %d bones." % [OUT_SCENE, bones.size()])
	quit()


## BONES with every sided entry split into a Right and a Left bone, parents renamed to
## match. The unsided bones and the right side come first in table order, then the left,
## so every parent still comes before its children.
func _expand_sides() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side in ["Right", "Left"]:
		for entry: Dictionary in BONES:
			if not entry.get("sided", false):
				if side == "Right":
					out.append(entry.duplicate())
				continue
			var bone := entry.duplicate()
			var mirror := Vector3(1.0 if side == "Right" else -1.0, 1.0, 1.0)
			bone["name"] = side + entry["name"]
			bone["head"] = (entry["head"] as Vector3) * mirror
			bone["tail"] = (entry["tail"] as Vector3) * mirror
			var parent_entry := _find_entry(entry["parent"])
			if parent_entry.get("sided", false):
				bone["parent"] = side + entry["parent"]
			out.append(bone)
	return out


func _find_entry(bone_name: String) -> Dictionary:
	for entry: Dictionary in BONES:
		if entry["name"] == bone_name:
			return entry
	return {}


func _find(i: int) -> int:
	while _parent[i] != i:
		i = _parent[i]
	return i


func _index_of(bones: Array[Dictionary], bone_name: String) -> int:
	for i in bones.size():
		if bones[i]["name"] == bone_name:
			return i
	return -1


# --- Mesh -------------------------------------------------------------------------------


func _build_skinned_mesh(source: ArrayMesh, bones: Array[Dictionary]) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var turn := Basis(Vector3.UP, PI)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = turn * vertices[i] * MODEL_SCALE
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = turn * normals[i]
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var t := turn * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
			tangents[i] = t.x
			tangents[i + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tangents

	var pieces := _pieces(vertices, arrays[Mesh.ARRAY_INDEX])
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	bone_ids.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	for i in vertices.size():
		var candidates := _candidates_for(vertices[i], pieces[i], bones)
		var skin := _weigh(vertices[i], candidates, bones)
		for k in 4:
			bone_ids[i * 4 + k] = int(skin[k].x)
			weights[i * 4 + k] = skin[k].y
	arrays[Mesh.ARRAY_BONES] = bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = weights

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh


## Which piece of the model each vertex is part of, as a label per vertex: "head",
## "arm", "foot" or "torso". Pieces are the model's connected parts, with vertices that
## share a position counted as joined.
func _pieces(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedStringArray:
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
		var root: int = _find(i)
		sums[root] = sums.get(root, Vector3.ZERO) + vertices[i]
		counts[root] = counts.get(root, 0) + 1
	var kinds := {}
	for root in sums:
		var center: Vector3 = sums[root] / counts[root]
		if center.y > NECK.y - 0.05 and absf(center.x) < 0.1:
			kinds[root] = "head"
		elif absf(center.x) > 0.15 and center.y > LEG_TOP:
			kinds[root] = "arm"
		elif center.y < KNEE.y * 0.5:
			kinds[root] = "foot"
		else:
			kinds[root] = "torso"
	var out := PackedStringArray()
	out.resize(vertices.size())
	for i in vertices.size():
		out[i] = kinds[_find(i)]
	return out


## The bones a vertex may be skinned to, by the piece it is on and where it sits.
func _candidates_for(vertex: Vector3, piece: String, bones: Array[Dictionary]) -> PackedInt32Array:
	var side := "Right" if vertex.x >= 0.0 else "Left"
	var names: PackedStringArray
	match piece:
		"head":
			names = ["Head"]
		"arm":
			names = [side + "UpperArm", side + "Forearm"]
		"foot":
			names = [side + "Shin"]
		_:
			if vertex.y >= LEG_TOP:
				names = ["Hips", "Spine", "Chest"]
			elif absf(vertex.x) < CROTCH_HALF_WIDTH:
				names = ["Hips"]
			else:
				names = ["Hips", side + "Thigh", side + "Shin"]
	var out := PackedInt32Array()
	for bone_name in names:
		out.append(_index_of(bones, bone_name))
	return out


## Up to four (bone, weight) pairs for a vertex. Each candidate bone counts fully along
## its own length and fades out over BLEND_DISTANCE past either end, so a vertex in the
## middle of a bone follows that bone alone and one at a joint is shared by both sides.
func _weigh(vertex: Vector3, candidates: PackedInt32Array, bones: Array[Dictionary]) -> Array[Vector2]:
	var scored: Array[Vector2] = []
	var nearest := candidates[0]
	var nearest_outside := INF
	for index in candidates:
		var head: Vector3 = bones[index]["head"]
		var tail: Vector3 = bones[index]["tail"]
		var axis := tail - head
		var t := (vertex - head).dot(axis) / axis.length_squared()
		var outside := maxf(-t, t - 1.0) * axis.length()
		outside = maxf(outside, 0.0)
		if outside < nearest_outside:
			nearest = index
			nearest_outside = outside
		var weight := 1.0 - outside / BLEND_DISTANCE
		if weight > 0.0:
			scored.append(Vector2(index, weight))
	if scored.is_empty():
		scored.append(Vector2(nearest, 1.0))
	scored.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	scored.resize(mini(scored.size(), 4))
	var total := 0.0
	for pair in scored:
		total += pair.y
	var out: Array[Vector2] = []
	for k in 4:
		out.append(Vector2(scored[k].x, scored[k].y / total) if k < scored.size() else Vector2.ZERO)
	return out


# --- Scene ------------------------------------------------------------------------------


func _build_scene(mesh: ArrayMesh, bones: Array[Dictionary]) -> Node3D:
	var root := Node3D.new()
	root.name = "HumanBody"
	root.set_script(load(BODY_SCRIPT))

	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	_add(root, skeleton, root)
	for bone in bones:
		var index := skeleton.add_bone(bone["name"])
		var parent := _index_of(bones, bone["parent"])
		var origin: Vector3 = bone["head"]
		if parent >= 0:
			skeleton.set_bone_parent(index, parent)
			origin -= bones[parent]["head"]
		skeleton.set_bone_rest(index, Transform3D(Basis(), origin))
	skeleton.reset_bone_poses()

	var skin := Skin.new()
	for i in bones.size():
		skin.add_named_bind(bones[i]["name"], Transform3D(Basis(), bones[i]["head"]).affine_inverse())
	var model := MeshInstance3D.new()
	model.name = "Mesh"
	model.mesh = mesh
	model.skin = skin
	model.skeleton = NodePath("..")
	_add(skeleton, model, root)

	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "PhysicalBones"
	_add(skeleton, simulator, root)
	for bone in bones:
		_add_physical_bone(simulator, bone, root)
	return root


func _add_physical_bone(simulator: PhysicalBoneSimulator3D, bone: Dictionary, root: Node) -> void:
	var head: Vector3 = bone["head"]
	var tail: Vector3 = bone["tail"]
	var length := head.distance_to(tail)
	# The body's Y runs down the bone, which is the axis a capsule lies along; X stays the
	# character's left-right, which is what knees and elbows hinge about.
	var y := (tail - head).normalized()
	var z := Vector3.RIGHT.cross(y).normalized()
	var x := y.cross(z)
	var body_basis := Basis(x, y, z)

	var physical := PhysicalBone3D.new()
	physical.name = bone["name"]
	physical.bone_name = bone["name"]
	physical.mass = bone["mass"]
	physical.friction = FRICTION
	physical.linear_damp = LINEAR_DAMP
	physical.angular_damp = ANGULAR_DAMP
	# Bones carry no rotation of their own, so bone space is body space moved to the head.
	physical.body_offset = Transform3D(body_basis, (tail - head) * 0.5)
	physical.transform = Transform3D(body_basis, (head + tail) * 0.5)

	# The joint sits at the bone's head. A cone twists about its frame's X, so X is laid
	# along the bone; a hinge turns about its frame's Z, so Z is laid across the body.
	var joint_origin := Vector3(0.0, -length * 0.5, 0.0)
	if bone.has("cone"):
		var limits: Vector2 = bone["cone"]
		physical.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		physical.joint_offset = Transform3D(
			Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), joint_origin
		)
		physical.set("joint_constraints/swing_span", limits.x)
		physical.set("joint_constraints/twist_span", limits.y)
	elif bone.has("hinge"):
		var limits: Vector2 = bone["hinge"]
		physical.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		physical.joint_offset = Transform3D(
			Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), joint_origin
		)
		physical.set("joint_constraints/angular_limit_enabled", true)
		physical.set("joint_constraints/angular_limit_lower", limits.x)
		physical.set("joint_constraints/angular_limit_upper", limits.y)
	_add(simulator, physical, root)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	match bone["shape"]:
		Shape.BOX:
			var box := BoxShape3D.new()
			box.size = bone["size"]
			collision.shape = box
		Shape.SPHERE:
			var sphere := SphereShape3D.new()
			sphere.radius = bone["radius"]
			collision.shape = sphere
		_:
			var capsule := CapsuleShape3D.new()
			capsule.radius = bone["radius"]
			# Reaching a radius past each end would have neighbouring limbs overlap at
			# every joint; half a radius keeps the gap closed without that.
			capsule.height = maxf(length + capsule.radius, capsule.radius * 2.0 + 0.01)
			collision.shape = capsule
	_add(physical, collision, root)


func _add(parent: Node, child: Node, root: Node) -> void:
	parent.add_child(child)
	child.owner = root
	if child is Skeleton3D or child is PhysicalBoneSimulator3D or child.name == "Mesh":
		child.unique_name_in_owner = true
