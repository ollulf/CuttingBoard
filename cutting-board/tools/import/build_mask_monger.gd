extends SceneTree

const OUT_PATH := "res://scenes/characters/mask_monger_model.tscn"
const VILLAGER_MASK := preload("res://scenes/characters/masks/villager_mask.tscn")
const BANDIT_MASK := preload("res://scenes/characters/masks/bandit_mask.tscn")
const WHITTLER_MASK := preload("res://scenes/characters/masks/whittler_mask.tscn")

const PUTTY := Color("8e7488")
const PUTTY_DARK := Color("64506a")
const SACK := Color("7a6446")
const LEATHER := Color("4a3020")
const ROPE := Color("9a7a50")
const BRASS := Color("b08a3a")
const BARK := Color("3a2818")
const BARK_LIGHT := Color("5e4430")
const IRON := Color("4a4650")
const PLUM := Color("5a3048")
const FLAME := Color("f0a838")

const RACK_MASKS := [
	[-0.24, 0.98, "villager"], [0.0, 0.98, "bandit"], [0.24, 0.98, "whittler"],
	[-0.13, 0.6, "whittler"], [0.13, 0.6, "villager"],
]
const MASK_SCALE := 0.62
const FIGURE_SCALE := 1.18
const BODY_SCRIPT := preload("res://scenes/characters/mask_monger_body.gd")

var _root: Node3D
var _materials := {}
var _unique: Array[Node3D] = []


func _init() -> void:
	_root = Node3D.new()
	_root.name = "MaskMongerModel"
	_root.set_script(BODY_SCRIPT)
	var model := _pivot(_root, "Model", Vector3.ZERO, true)
	model.rotation.y = PI
	model.scale = Vector3.ONE * FIGURE_SCALE
	_build(model)
	_own(_root)
	for n in _unique:
		n.unique_name_in_owner = true
	var scene := PackedScene.new()
	var ok := scene.pack(_root) == OK and ResourceSaver.save(scene, OUT_PATH) == OK
	print("mask monger: ", "saved " + OUT_PATH if ok else "FAILED")
	_root.free()
	quit(0 if ok else 1)


func _build(g: Node3D) -> void:
	var barrel := _pivot(g, "Barrel", Vector3(0, 0.72, -0.25), true)
	_cyl(barrel, "Sack", 0.27, 0.24, 0.8, SACK, Vector3.ZERO, 7).rotation.x = PI / 2
	for z in [-0.25, 0.2]:
		_cyl(barrel, "Hoop", 0.28, 0.28, 0.04, ROPE, Vector3(0, 0, z), 7).rotation.x = PI / 2
	_box(barrel, "Patch", Vector3(0.4, 0.3, 0.02), PLUM, Vector3(0.27, -0.04, 0)).rotation.y = PI / 2

	for s in [1, -1]:
		_leg(g, "Leg" + _side(s), Vector3(0.17 * s, 0.68, -0.5), 0.06)

	for s in [1, -1]:
		var arm := _pivot(g, "KnuckleArm" + _side(s), Vector3(0.22 * s, 0.78, 0.08), true)
		_euler(arm, -0.15, 0, 0.12 * s)
		var elbow := _limb(arm, "KnuckleElbow" + _side(s), 0.36, 0.055, 0.05, PUTTY, true)
		elbow.rotation.x = 0.35
		_ball(elbow, "Joint", 0.05, PUTTY)
		_box(elbow, "Cuff", Vector3(0.12, 0.12, 0.12), BRASS, Vector3(0, -0.08, 0))
		var knuckle := _limb(elbow, "Knuckle" + _side(s), 0.36, 0.05, 0.045, PUTTY)
		_ball(knuckle, "Fist", 0.07, PUTTY_DARK, Vector3(0, -0.01, 0.02), Vector3(1, 0.7, 1.2))

	var body := _pivot(g, "Torso", Vector3(0, 0.84, 0.12), true)
	_cyl(body, "Coat", 0.2, 0.24, 0.46, LEATHER, Vector3(0, 0.22, 0), 7)
	_cyl(body, "Muffler", 0.13, 0.15, 0.1, FLAME, Vector3(0, 0.5, 0), 7)
	var head := _pivot(body, "Head", Vector3(0, 0.58, 0), true)
	_ball(head, "Egg", 0.13, PUTTY, Vector3(0, 0.12, 0), Vector3(0.95, 1.22, 1))
	_cyl(head, "HatBrim", 0.32, 0.32, 0.03, BARK, Vector3(0, 0.24, 0), 8)
	_cyl(head, "HatCrown", 0.13, 0.15, 0.16, BARK, Vector3(0, 0.33, 0), 7)
	_cyl(head, "HatBand", 0.155, 0.155, 0.03, FLAME, Vector3(0, 0.27, 0), 7)

	var lantern_arm := _arm(body, "Lantern", Vector3(0.25, 0.38, 0), 0.26, 0.26, 0.045)
	_euler(lantern_arm, -0.3, 0, 0.5)
	lantern_arm.get_node("ElbowLantern").rotation.x = -1.3
	var hook := _pivot(lantern_arm.get_node("ElbowLantern/HandLantern"), "LanternHook",
			Vector3(0, -0.04, 0))
	var lantern := _pivot(hook, "Lantern", Vector3.ZERO, true)
	_cyl(lantern, "Bail", 0.004, 0.004, 0.1, IRON, Vector3(0, -0.05, 0), 3)
	_box(lantern, "Cage", Vector3(0.1, 0.13, 0.1), IRON, Vector3(0, -0.16, 0))
	_box(lantern, "Flame", Vector3(0.07, 0.1, 0.105), FLAME, Vector3(0, -0.16, 0), true)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = FLAME
	lamp.light_energy = 0.9
	lamp.omni_range = 3.0
	lamp.position = Vector3(0, -0.16, 0.1)
	lantern.add_child(lamp)

	var puppet_arm := _arm(body, "Puppet", Vector3(-0.25, 0.38, 0), 0.26, 0.24, 0.045)
	_euler(puppet_arm, -1.0, 0, -0.3)
	puppet_arm.get_node("ElbowPuppet").rotation.x = -0.6
	var puppet := _pivot(puppet_arm.get_node("ElbowPuppet/HandPuppet"), "Puppet",
			Vector3(0, -0.06, 0), true)
	puppet.rotation.x = 1.55 + PI / 2
	_cyl(puppet, "Sleeve", 0.07, 0.06, 0.12, PLUM, Vector3.ZERO, 6)
	var face := _mask(puppet, "Face", "whittler", Vector3(0, 0.075, 0))
	face.rotation.x = -PI / 2
	var jaw := _pivot(puppet, "Jaw", Vector3(0, -0.06, 0.05), true)
	_box(jaw, "Chin", Vector3(0.11, 0.02, 0.1), PUTTY_DARK, Vector3.ZERO)

	var rack := _pivot(g, "Rack", Vector3(0, 0.9, -0.35), true)
	for s in [1, -1]:
		_cyl(rack, "Post", 0.02, 0.02, 1.0, BARK_LIGHT, Vector3(0.34 * s, 0.5, 0), 4)
	for y in [0.98, 0.6]:
		_cyl(rack, "Bar", 0.018, 0.018, 0.76, BARK_LIGHT, Vector3(0, y, 0), 4).rotation.z = PI / 2
	for i in RACK_MASKS.size():
		var entry: Array = RACK_MASKS[i]
		var hanger := _pivot(rack, "Hook%d" % (i + 1), Vector3(entry[0], entry[1], 0.03), true)
		_cyl(hanger, "String", 0.003, 0.003, 0.08, ROPE, Vector3(0, -0.04, 0), 3)
		_mask(hanger, "Mask", entry[2], Vector3(0, -0.17, 0))

	_ball(g, "Bag", 0.1, LEATHER, Vector3(-0.3, 0.55, -0.15), Vector3(1, 1.2, 1))


func _leg(p: Node3D, leg_name: String, at: Vector3, r: float) -> Node3D:
	var k := (at.y - 0.05) / 0.831
	var s := leg_name.right(1)
	var hip := _pivot(p, leg_name, at, true)
	hip.rotation.x = -0.5
	var knee := _limb(hip, "Knee" + s, 0.36 * k, r * 1.25, r, PUTTY, true)
	knee.rotation.x = 1.2
	_ball(knee, "Joint", r * 1.05, PUTTY)
	var ankle := _limb(knee, "Ankle" + s, 0.34 * k, r, r * 0.7, PUTTY, true)
	ankle.rotation.x = -0.9
	var toe := _limb(ankle, "Toe" + s, 0.26 * k, r * 0.7, r * 0.55, PUTTY)
	var foot := _pivot(toe, "Foot" + s)
	foot.rotation.x = 0.2
	_box(foot, "Sole", Vector3(r * 2.2, 0.05, r * 3.6), PUTTY_DARK, Vector3(0, -0.02, r * 1.2))
	return hip


func _arm(p: Node3D, what: String, at: Vector3, upper: float, fore: float, r: float) -> Node3D:
	var shoulder := _pivot(p, what + "Arm", at, true)
	var elbow := _limb(shoulder, "Elbow" + what, upper, r, r * 0.85, PUTTY, true)
	_ball(elbow, "Joint", r * 0.95, PUTTY)
	var hand := _limb(elbow, "Hand" + what, fore, r * 0.85, r * 0.75, PUTTY)
	_ball(hand, "Palm", r * 1.15, PUTTY_DARK, Vector3(0, -r * 0.6, 0), Vector3(1, 1.3, 0.8))
	return shoulder


func _limb(p: Node3D, joint_name: String, length: float, r0: float, r1: float, col: Color,
		unique := false) -> Node3D:
	_cyl(p, "Bone", r1, r0, length, col, Vector3(0, -length / 2, 0), 5)
	return _pivot(p, joint_name, Vector3(0, -length, 0), unique)


func _mask(p: Node3D, mask_name: String, kind: String, at: Vector3) -> Node3D:
	var holder := _pivot(p, mask_name, at)
	holder.scale = Vector3.ONE * MASK_SCALE
	var scene: PackedScene = {
		"villager": VILLAGER_MASK, "bandit": BANDIT_MASK, "whittler": WHITTLER_MASK,
	}[kind]
	var instance: Node3D = scene.instantiate()
	instance.rotation.y = PI
	holder.add_child(instance)
	return holder


func _pivot(p: Node3D, node_name: String, at := Vector3.ZERO, unique := false) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = at
	p.add_child(n)
	if unique:
		_unique.append(n)
	return n


func _cyl(p: Node3D, node_name: String, top: float, bottom: float, height: float, col: Color,
		at: Vector3, sides: int) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 0
	return _mesh(p, node_name, m, col, at)


func _box(p: Node3D, node_name: String, size: Vector3, col: Color, at: Vector3,
		glow := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(p, node_name, m, col, at, glow)


func _ball(p: Node3D, node_name: String, r: float, col: Color, at := Vector3.ZERO,
		squash := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 7
	m.rings = 4
	var inst := _mesh(p, node_name, m, col, at)
	inst.scale = squash
	return inst


func _mesh(p: Node3D, node_name: String, m: PrimitiveMesh, col: Color, at: Vector3,
		glow := false) -> MeshInstance3D:
	m.material = _material(col, glow)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = m
	inst.position = at
	p.add_child(inst)
	return inst


func _material(col: Color, glow: bool) -> StandardMaterial3D:
	var key := col.to_html() + ("g" if glow else "")
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if glow:
			mat.emission_enabled = true
			mat.emission = col
		_materials[key] = mat
	return _materials[key]


func _euler(n: Node3D, x: float, y: float, z: float) -> void:
	n.basis = Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y) * Basis(Vector3.BACK, z)


func _side(s: int) -> String:
	return "L" if s > 0 else "R"


func _own(n: Node) -> void:
	for child in n.get_children():
		child.owner = _root
		if child.scene_file_path.is_empty():
			_own(child)
