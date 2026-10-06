extends SceneTree

## Builds the Mask-Monger's model, scenes/characters/mask_monger_model.tscn, from the
## creature concept (docs/concepts/creature-concepts.html, "Mask-Monger"): a Whittler
## merchant about 1.95 m tall that walks on two backward-kneed legs and two knuckle-arms,
## holds a lantern in one upper hand and talks through a hand puppet on the other, and
## carries a rack of five masks for sale on its back.
##
## Only the mesh: no rig and no animation yet. Every limb is built as a chain of named
## Node3D pivots (hip > knee > ankle > toe, shoulder > elbow > hand, rack > hook), the same
## joints the concept animates, so a later rig can turn them without rebuilding anything.
##
## The concept is drawn facing +Z; it is copied here unchanged under a "Model" node that
## is turned half round, so the finished monger faces -Z like the game's other characters.
## Its rotations are three.js Euler angles (X, then Y, then Z, applied in that order).
##
## Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://scripts/import/build_mask_monger.gd

const OUT_PATH := "res://scenes/characters/mask_monger_model.tscn"
const VILLAGER_MASK := preload("res://scenes/characters/masks/villager_mask.tscn")
const BANDIT_MASK := preload("res://scenes/characters/masks/bandit_mask.tscn")
const WHITTLER_MASK := preload("res://scenes/characters/masks/whittler_mask.tscn")

## The concept's palette.
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

## The masks hung on the rack: (x, y, which mask), along the top bar then the lower one.
const RACK_MASKS := [
	[-0.24, 0.98, "villager"], [0.0, 0.98, "bandit"], [0.24, 0.98, "whittler"],
	[-0.13, 0.6, "whittler"], [0.13, 0.6, "villager"],
]
## The masks are drawn smaller than a worn one, as in the concept.
const MASK_SCALE := 0.62
## The whole figure is scaled up from the concept (about 2.3 m tall).
const FIGURE_SCALE := 1.18

var _root: Node3D
var _materials := {}


func _init() -> void:
	_root = Node3D.new()
	_root.name = "MaskMongerModel"
	var model := _pivot(_root, "Model")
	model.rotation.y = PI
	model.scale = Vector3.ONE * FIGURE_SCALE
	_build(model)
	_own(_root)
	var scene := PackedScene.new()
	var ok := scene.pack(_root) == OK and ResourceSaver.save(scene, OUT_PATH) == OK
	print("mask monger: ", "saved " + OUT_PATH if ok else "FAILED")
	_root.free()
	quit(0 if ok else 1)


func _build(g: Node3D) -> void:
	# The barrel of a body it walks on, lying along Z, with two rope hoops and a plum patch.
	var barrel := _pivot(g, "Barrel", Vector3(0, 0.72, -0.25))
	_cyl(barrel, "Sack", 0.27, 0.24, 0.8, SACK, Vector3.ZERO, 7).rotation.x = PI / 2
	for z in [-0.25, 0.2]:
		_cyl(barrel, "Hoop", 0.28, 0.28, 0.04, ROPE, Vector3(0, 0, z), 7).rotation.x = PI / 2
	_box(barrel, "Patch", Vector3(0.4, 0.3, 0.02), PLUM, Vector3(0.27, -0.04, 0)).rotation.y = PI / 2

	# Hind legs, set back under the barrel.
	for s in [1, -1]:
		_leg(g, "Leg" + _side(s), Vector3(0.17 * s, 0.68, -0.5), 0.06)

	# Front legs: its lower arms, walking on brass-cuffed knuckles.
	for s in [1, -1]:
		var arm := _pivot(g, "KnuckleArm" + _side(s), Vector3(0.22 * s, 0.78, 0.08))
		_euler(arm, -0.15, 0, 0.12 * s)
		var elbow := _limb(arm, "Elbow", 0.36, 0.055, 0.05, PUTTY)
		elbow.rotation.x = 0.35
		_ball(elbow, "Joint", 0.05, PUTTY)
		_box(elbow, "Cuff", Vector3(0.12, 0.12, 0.12), BRASS, Vector3(0, -0.08, 0))
		var knuckle := _limb(elbow, "Knuckle", 0.36, 0.05, 0.045, PUTTY)
		_ball(knuckle, "Fist", 0.07, PUTTY_DARK, Vector3(0, -0.01, 0.02), Vector3(1, 0.7, 1.2))

	# The upright torso, a leather coat with a flame-coloured muffler.
	var body := _pivot(g, "Body", Vector3(0, 0.84, 0.12))
	_cyl(body, "Coat", 0.2, 0.24, 0.46, LEATHER, Vector3(0, 0.22, 0), 7)
	_cyl(body, "Muffler", 0.13, 0.15, 0.1, FLAME, Vector3(0, 0.5, 0), 7)
	var head := _pivot(body, "Head", Vector3(0, 0.58, 0))
	_ball(head, "Egg", 0.13, PUTTY, Vector3(0, 0.12, 0), Vector3(0.95, 1.22, 1))
	_cyl(head, "HatBrim", 0.32, 0.32, 0.03, BARK, Vector3(0, 0.24, 0), 8)
	_cyl(head, "HatCrown", 0.13, 0.15, 0.16, BARK, Vector3(0, 0.33, 0), 7)
	_cyl(head, "HatBand", 0.155, 0.155, 0.03, FLAME, Vector3(0, 0.27, 0), 7)

	# Upper arm on one side: a lantern hung from a hook.
	var lantern_arm := _arm(body, "LanternArm", Vector3(0.25, 0.38, 0), 0.26, 0.26, 0.045)
	_euler(lantern_arm, -0.3, 0, 0.5)
	lantern_arm.get_node("Elbow").rotation.x = -1.3
	var hook := _pivot(lantern_arm.get_node("Elbow/Hand"), "LanternHook", Vector3(0, -0.04, 0))
	var lantern := _pivot(hook, "Lantern")
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

	# Upper arm on the other side: the hand puppet with a little Whittler face, which does
	# the talking, and its jaw.
	var puppet_arm := _arm(body, "PuppetArm", Vector3(-0.25, 0.38, 0), 0.26, 0.24, 0.045)
	_euler(puppet_arm, -1.0, 0, -0.3)
	puppet_arm.get_node("Elbow").rotation.x = -0.6
	var puppet := _pivot(puppet_arm.get_node("Elbow/Hand"), "Puppet", Vector3(0, -0.06, 0))
	# The concept's 1.55 leaves the puppet's face looking at the sky once the arm is raised;
	# a quarter turn more points it forward, at whoever the monger is talking to.
	puppet.rotation.x = 1.55 + PI / 2
	_cyl(puppet, "Sleeve", 0.07, 0.06, 0.12, PLUM, Vector3.ZERO, 6)
	var face := _mask(puppet, "Face", "whittler", Vector3(0, 0.075, 0))
	face.rotation.x = -PI / 2
	var jaw := _pivot(puppet, "Jaw", Vector3(0, -0.06, 0.05))
	_box(jaw, "Chin", Vector3(0.11, 0.02, 0.1), PUTTY_DARK, Vector3.ZERO)

	# The rack on its back, hung with faces for sale.
	var rack := _pivot(g, "Rack", Vector3(0, 0.9, -0.35))
	for s in [1, -1]:
		_cyl(rack, "Post", 0.02, 0.02, 1.0, BARK_LIGHT, Vector3(0.34 * s, 0.5, 0), 4)
	for y in [0.98, 0.6]:
		_cyl(rack, "Bar", 0.018, 0.018, 0.76, BARK_LIGHT, Vector3(0, y, 0), 4).rotation.z = PI / 2
	for i in RACK_MASKS.size():
		var entry: Array = RACK_MASKS[i]
		var hanger := _pivot(rack, "Hook%d" % (i + 1), Vector3(entry[0], entry[1], 0.03))
		_cyl(hanger, "String", 0.003, 0.003, 0.08, ROPE, Vector3(0, -0.04, 0), 3)
		_mask(hanger, "Mask", entry[2], Vector3(0, -0.17, 0))

	_ball(g, "Bag", 0.1, LEATHER, Vector3(-0.3, 0.55, -0.15), Vector3(1, 1.2, 1))


## A backward-kneed leg reaching the ground from hip height y (the concept's dLeg).
## Returns the hip pivot.
func _leg(p: Node3D, leg_name: String, at: Vector3, r: float) -> Node3D:
	var k := (at.y - 0.05) / 0.831
	var hip := _pivot(p, leg_name, at)
	hip.rotation.x = -0.5
	var knee := _limb(hip, "Knee", 0.36 * k, r * 1.25, r, PUTTY)
	knee.rotation.x = 1.2
	_ball(knee, "Joint", r * 1.05, PUTTY)
	var ankle := _limb(knee, "Ankle", 0.34 * k, r, r * 0.7, PUTTY)
	ankle.rotation.x = -0.9
	var toe := _limb(ankle, "Toe", 0.26 * k, r * 0.7, r * 0.55, PUTTY)
	var foot := _pivot(toe, "Foot")
	foot.rotation.x = 0.2
	_box(foot, "Sole", Vector3(r * 2.2, 0.05, r * 3.6), PUTTY_DARK, Vector3(0, -0.02, r * 1.2))
	return hip


## Shoulder, upper arm, elbow, forearm and hand (the concept's arm). Returns the shoulder.
func _arm(p: Node3D, arm_name: String, at: Vector3, upper: float, fore: float, r: float) -> Node3D:
	var shoulder := _pivot(p, arm_name, at)
	var elbow := _limb(shoulder, "Elbow", upper, r, r * 0.85, PUTTY)
	_ball(elbow, "Joint", r * 0.95, PUTTY)
	var hand := _limb(elbow, "Hand", fore, r * 0.85, r * 0.75, PUTTY)
	_ball(hand, "Palm", r * 1.15, PUTTY_DARK, Vector3(0, -r * 0.6, 0), Vector3(1, 1.3, 0.8))
	return shoulder


## A limb segment hanging down from p; returns the pivot at its far end, named joint_name.
func _limb(p: Node3D, joint_name: String, length: float, r0: float, r1: float, col: Color) -> Node3D:
	_cyl(p, "Bone", r1, r0, length, col, Vector3(0, -length / 2, 0), 5)
	return _pivot(p, joint_name, Vector3(0, -length, 0))


## One of the game's carved masks, scaled down, facing the concept's front (+Z).
func _mask(p: Node3D, mask_name: String, kind: String, at: Vector3) -> Node3D:
	var holder := _pivot(p, mask_name, at)
	holder.scale = Vector3.ONE * MASK_SCALE
	var scene: PackedScene = {
		"villager": VILLAGER_MASK, "bandit": BANDIT_MASK, "whittler": WHITTLER_MASK,
	}[kind]
	var instance: Node3D = scene.instantiate()
	instance.rotation.y = PI  # the mask scenes face -Z; the concept's front is +Z
	holder.add_child(instance)
	return holder


func _pivot(p: Node3D, node_name: String, at := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = at
	p.add_child(n)
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


## Flat-coloured, unlit-looking clay like the concept's Lambert materials, one per colour.
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


## Sets a three.js-style rotation (X, then Y, then Z) on a pivot.
func _euler(n: Node3D, x: float, y: float, z: float) -> void:
	n.basis = Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y) * Basis(Vector3.BACK, z)


func _side(s: int) -> String:
	# The concept's +X is the monger's own left (it faces +Z).
	return "L" if s > 0 else "R"


func _own(n: Node) -> void:
	for child in n.get_children():
		child.owner = _root
		if child.scene_file_path.is_empty():
			_own(child)
