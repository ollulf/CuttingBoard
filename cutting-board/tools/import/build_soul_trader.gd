extends SceneTree

## Builds the Soul Trader concept, scenes/characters/soul_trader.tscn (docs/concepts/
## soul-trader.md, look A "the Flask Peddler"): a stooped wooden puppet about 2.1 m tall
## whose head is a corked jug with two ember eye-holes, pushing a two-wheeled handcart.
## The cart's canopy beam is hung with glowing soul flasks (the currency it takes), and
## its side rack shows the weapons and goods it sells. Concept only: no script, no
## collision, not placed in any level.
##
## Built like build_mask_monger.gd: flat-coloured primitives under named Node3D pivots,
## the joints that would animate (%Head, %Jaw, %ArmL/%ArmR, %Flask1..) as scene-unique
## names. The trader faces -Z like the game's other characters; the cart is in front of it.
##
##   godot --headless --path cutting-board -s res://tools/import/build_soul_trader.gd

const OUT_PATH := "res://scenes/characters/soul_trader.tscn"
const BOTTLE_MESH := preload("res://assets/meshes/props/soul_bottle.res")

## Warm wood, bone and one ember accent, as for the Carver.
const WOOD := Color("9a6a3e")
const WOOD_DARK := Color("5e3e24")
const WOOD_LIGHT := Color("c49260")
const BONE := Color("d8c8a4")
const CLOTH := Color("6a3a2a")
const CANVAS := Color("8a7458")
const ROPE := Color("9a7a50")
const IRON := Color("4a4650")
const EMBER := Color("e8501c")
const SOUL := Color(1.0, 0.72, 0.16)

## Flasks along the canopy beam: (x, string length).
const BEAM_FLASKS := [[-0.62, 0.16], [-0.38, 0.28], [-0.12, 0.2], [0.14, 0.32], [0.4, 0.18], [0.64, 0.26]]

var _root: Node3D
var _materials := {}
var _unique: Array[Node3D] = []


func _init() -> void:
	_root = Node3D.new()
	_root.name = "SoulTrader"
	_build_trader(_pivot(_root, "Trader", Vector3(0, 0, 0.55), true))
	_build_cart(_pivot(_root, "Cart", Vector3(0, 0, -0.55), true))
	_own(_root)
	for n in _unique:
		n.unique_name_in_owner = true
	var scene := PackedScene.new()
	var ok := scene.pack(_root) == OK and ResourceSaver.save(scene, OUT_PATH) == OK
	print("soul trader: ", "saved " + OUT_PATH if ok else "FAILED")
	_root.free()
	quit(0 if ok else 1)


func _build_trader(g: Node3D) -> void:
	# Two peg legs with clog feet, and a barrel-stave skirt over the hips.
	for s in [1, -1]:
		var hip := _pivot(g, "Leg" + _side(s), Vector3(0.13 * s, 0.82, 0))
		_cyl(hip, "Thigh", 0.05, 0.06, 0.42, WOOD, Vector3(0, -0.21, 0), 6)
		_ball(hip, "Knee", 0.065, WOOD_DARK, Vector3(0, -0.42, 0))
		_cyl(hip, "Shin", 0.04, 0.05, 0.38, WOOD, Vector3(0, -0.61, 0), 6)
		_box(hip, "Clog", Vector3(0.12, 0.07, 0.22), WOOD_DARK, Vector3(0, -0.79, -0.04))
	_cyl(g, "Skirt", 0.2, 0.27, 0.3, WOOD_LIGHT, Vector3(0, 0.86, 0), 9)
	_cyl(g, "SkirtHoop", 0.275, 0.275, 0.03, IRON, Vector3(0, 0.74, 0), 9)

	# A stooped torso leaning towards the cart, in a patched coat with an ember sash.
	var torso := _pivot(g, "Torso", Vector3(0, 1.0, 0), true)
	torso.rotation.x = -0.35
	_cyl(torso, "Coat", 0.24, 0.2, 0.55, CLOTH, Vector3(0, 0.27, 0), 8)
	_box(torso, "Patch", Vector3(0.14, 0.14, 0.02), CANVAS, Vector3(0.1, 0.3, -0.22))
	var sash := _box(torso, "Sash", Vector3(0.08, 0.62, 0.5), EMBER, Vector3(0, 0.28, 0))
	sash.rotation.z = 0.7
	# A satchel of loose flasks at its hip, and a ledger board on a string.
	_ball(torso, "Satchel", 0.11, CANVAS, Vector3(-0.27, 0.05, 0.02), Vector3(0.7, 1, 1.1))
	_box(torso, "Ledger", Vector3(0.16, 0.2, 0.02), WOOD_LIGHT, Vector3(0.18, 0.08, -0.2))

	# A long jointed neck craning forward, ending in the jug head.
	var neck := _pivot(torso, "Neck", Vector3(0, 0.55, 0), true)
	neck.rotation.x = -0.55
	for i in 3:
		_cyl(neck, "Vertebra%d" % i, 0.04, 0.05, 0.08, WOOD_DARK, Vector3(0, 0.05 + i * 0.09, 0), 6)
	var head := _pivot(neck, "Head", Vector3(0, 0.3, 0), true)
	head.rotation.x = 0.75
	# The jug: a bulb, a shoulder, a neck and a cork with a little ember wick.
	_ball(head, "Bulb", 0.17, BONE, Vector3(0, 0.14, 0), Vector3(1, 1.1, 0.95))
	_cyl(head, "JugNeck", 0.06, 0.1, 0.14, BONE, Vector3(0, 0.33, 0), 8)
	_cyl(head, "Cork", 0.065, 0.055, 0.08, WOOD_LIGHT, Vector3(0, 0.43, 0), 7)
	_cyl(head, "Wick", 0.008, 0.008, 0.06, EMBER, Vector3(0, 0.5, 0), 3, true)
	_ring(head, "Handle", Vector3(0.17, 0.2, 0.0), 0.07, BONE)
	for s in [1, -1]:
		_ball(head, "Eye" + _side(s), 0.03, EMBER, Vector3(0.065 * s, 0.17, -0.155), Vector3.ONE, true)
	# A hinged lower lip that would flap when it haggles.
	var jaw := _pivot(head, "Jaw", Vector3(0, 0.07, -0.13), true)
	_box(jaw, "Lip", Vector3(0.12, 0.025, 0.06), WOOD_DARK, Vector3(0, 0, -0.02))
	var glow := OmniLight3D.new()
	glow.name = "EyeGlow"
	glow.light_color = EMBER
	glow.light_energy = 0.4
	glow.omni_range = 0.8
	glow.position = Vector3(0, 0.17, -0.3)
	head.add_child(glow)

	# Arms reaching down to the cart's handles.
	for s in [1, -1]:
		var arm := _pivot(torso, "Arm" + _side(s), Vector3(0.27 * s, 0.48, 0), true)
		arm.rotation = Vector3(1.1, 0, 0.08 * s)
		_cyl(arm, "Upper", 0.035, 0.045, 0.34, WOOD, Vector3(0, -0.17, 0), 6)
		var elbow := _pivot(arm, "Elbow" + _side(s), Vector3(0, -0.34, 0), true)
		elbow.rotation.x = -0.5
		_ball(elbow, "Joint", 0.045, WOOD_DARK)
		_cyl(elbow, "Fore", 0.03, 0.04, 0.32, WOOD, Vector3(0, -0.16, 0), 6)
		_ball(elbow, "Mitt", 0.06, WOOD_DARK, Vector3(0, -0.36, 0), Vector3(1, 1.3, 0.8))


func _build_cart(c: Node3D) -> void:
	# The bed: a plank box on an axle with two spoked wheels.
	_box(c, "Bed", Vector3(1.5, 0.08, 0.8), WOOD, Vector3(0, 0.62, 0))
	for z in [-0.4, 0.4]:
		_box(c, "Side", Vector3(1.5, 0.22, 0.04), WOOD_DARK, Vector3(0, 0.75, z))
	for x in [-0.75, 0.75]:
		_box(c, "End", Vector3(0.04, 0.22, 0.8), WOOD_DARK, Vector3(x, 0.75, 0))
	_cyl(c, "Axle", 0.03, 0.03, 1.7, IRON, Vector3(0, 0.38, 0), 5).rotation.z = PI / 2
	for x in [-0.84, 0.84]:
		var wheel := _pivot(c, "Wheel", Vector3(x, 0.38, 0))
		wheel.rotation.z = PI / 2
		_cyl(wheel, "Rim", 0.38, 0.38, 0.05, WOOD_DARK, Vector3.ZERO, 12)
		_cyl(wheel, "Hub", 0.08, 0.08, 0.07, IRON, Vector3.ZERO, 6)
		for k in 3:
			var spoke := _box(wheel, "Spoke", Vector3(0.7, 0.06, 0.035), WOOD_LIGHT, Vector3(0, 0.0, 0))
			spoke.rotation.y = k * PI / 3
	# Two handles back towards the trader, and a leg propping the front.
	for s in [1, -1]:
		var handle := _cyl(c, "Handle", 0.025, 0.025, 0.9, WOOD_LIGHT, Vector3(0.3 * s, 0.72, 0.75), 5)
		handle.rotation.x = PI / 2 - 0.2
	_cyl(c, "Prop", 0.03, 0.03, 0.62, WOOD_DARK, Vector3(0, 0.31, -0.42), 5)

	# Four posts and a patched canvas canopy.
	for x in [-0.72, 0.72]:
		for z in [-0.38, 0.38]:
			_cyl(c, "Post", 0.025, 0.025, 1.7, WOOD_LIGHT, Vector3(x, 1.47, z), 5)
	var roof := _box(c, "Canopy", Vector3(1.75, 0.04, 1.05), CANVAS, Vector3(0, 2.35, 0))
	roof.rotation.x = -0.12
	_box(c, "CanopyStripe", Vector3(1.76, 0.045, 0.2), EMBER, Vector3(0, 2.34, 0.0)).rotation.x = -0.12
	# The front beam the flasks hang from, under the canopy's low edge.
	var beam := _pivot(c, "FlaskBeam", Vector3(0, 2.22, -0.44), true)
	_cyl(beam, "Bar", 0.025, 0.025, 1.6, WOOD_DARK, Vector3.ZERO, 5).rotation.z = PI / 2
	for i in BEAM_FLASKS.size():
		var entry: Array = BEAM_FLASKS[i]
		var hanger := _pivot(beam, "Flask%d" % (i + 1), Vector3(entry[0], 0, 0), true)
		_cyl(hanger, "String", 0.004, 0.004, entry[1], ROPE, Vector3(0, -entry[1] / 2.0, 0), 3)
		_flask(hanger, Vector3(0, -entry[1] - 0.11, 0), i % 3 == 1)

	# The goods on the bed: a crate of flasks, planks, a glue pot and a lamp.
	_box(c, "Crate", Vector3(0.4, 0.26, 0.34), WOOD_LIGHT, Vector3(0.45, 0.79, 0.1))
	for k in 3:
		_flask(c, Vector3(0.34 + k * 0.11, 1.0, 0.1), false)
	for k in 3:
		_box(c, "Plank", Vector3(0.9, 0.04, 0.16), WOOD_LIGHT, Vector3(-0.25, 0.68 + k * 0.045, 0.16 - k * 0.01))
	_cyl(c, "GluePot", 0.08, 0.09, 0.14, BONE, Vector3(-0.5, 0.73, -0.2), 7)
	_box(c, "Lamp", Vector3(0.12, 0.18, 0.12), IRON, Vector3(-0.05, 0.75, -0.22))
	_box(c, "LampFlame", Vector3(0.08, 0.1, 0.125), SOUL, Vector3(-0.05, 0.75, -0.22), true)

	# The side rack with weapons hung on pegs, facing out of the cart's right side.
	var rack := _pivot(c, "WeaponRack", Vector3(0.78, 0.0, 0), true)
	_box(rack, "Board", Vector3(0.04, 0.6, 0.76), WOOD_DARK, Vector3(0, 1.12, 0))
	# Rolling pin, chair-leg club, rake and sickle, as simple stand-ins.
	_cyl(rack, "RollingPin", 0.04, 0.04, 0.42, WOOD_LIGHT, Vector3(0.05, 1.32, 0), 7).rotation.x = PI / 2
	var club := _cyl(rack, "ChairLeg", 0.035, 0.05, 0.5, WOOD, Vector3(0.05, 1.08, -0.18), 6)
	club.rotation.x = 0.3
	var rake := _pivot(rack, "Rake", Vector3(0.05, 1.08, 0.2))
	rake.rotation.x = -0.25
	_cyl(rake, "Shaft", 0.015, 0.015, 0.5, WOOD_LIGHT, Vector3.ZERO, 4)
	_box(rake, "Tines", Vector3(0.03, 0.05, 0.12), BONE, Vector3(0, 0.26, 0))
	var sickle := _pivot(rack, "Sickle", Vector3(0.06, 0.95, 0.02))
	_cyl(sickle, "Grip", 0.02, 0.02, 0.18, WOOD_DARK, Vector3.ZERO, 4).rotation.x = PI / 2
	var blade := _box(sickle, "Blade", Vector3(0.02, 0.18, 0.04), BONE, Vector3(0, 0.07, -0.12))
	blade.rotation.x = 0.5
	# A price board on top: a flask painted next to a tally.
	_box(rack, "PriceBoard", Vector3(0.03, 0.14, 0.4), BONE, Vector3(0.02, 1.5, 0))
	_ball(rack, "PaintedFlask", 0.035, SOUL, Vector3(0.04, 1.5, -0.12), Vector3.ONE, true)
	for k in 4:
		_box(rack, "Tally", Vector3(0.035, 0.08, 0.012), EMBER, Vector3(0.04, 1.5, -0.02 + k * 0.04))


## A soul flask: the game's bottle mesh with a glowing swirl inside (a static stand-in for
## the swirl shader). `ember` makes it one of the rarer red souls.
func _flask(p: Node3D, at: Vector3, ember: bool) -> void:
	var bottle := MeshInstance3D.new()
	bottle.name = "Bottle"
	bottle.mesh = BOTTLE_MESH
	bottle.position = at
	p.add_child(bottle)
	_ball(bottle, "Soul", 0.034, EMBER if ember else SOUL, Vector3.ZERO, Vector3.ONE, true)


## A loop handle on the jug: a short ring of boxes standing in the XY plane on its right.
func _ring(p: Node3D, node_name: String, at: Vector3, r: float, col: Color) -> void:
	var ring := _pivot(p, node_name, at)
	for k in 6:
		var t := PI * k / 5.0 - PI / 2
		var seg := _box(ring, "Seg", Vector3(0.025, 0.045, 0.025), col, Vector3(sin(t + PI / 2) * r * 0.6, sin(t) * r, 0))
		seg.rotation.z = t


func _pivot(p: Node3D, node_name: String, at := Vector3.ZERO, unique := false) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = at
	p.add_child(n)
	if unique:
		_unique.append(n)
	return n


func _cyl(p: Node3D, node_name: String, top: float, bottom: float, height: float, col: Color,
		at: Vector3, sides: int, glow := false) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 0
	return _mesh(p, node_name, m, col, at, glow)


func _box(p: Node3D, node_name: String, size: Vector3, col: Color, at: Vector3,
		glow := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(p, node_name, m, col, at, glow)


func _ball(p: Node3D, node_name: String, r: float, col: Color, at := Vector3.ZERO,
		squash := Vector3.ONE, glow := false) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	var inst := _mesh(p, node_name, m, col, at, glow)
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


## Flat-coloured clay, one material per colour, as in build_mask_monger.gd.
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
			mat.emission_energy_multiplier = 1.5
		_materials[key] = mat
	return _materials[key]


func _side(s: int) -> String:
	# It faces -Z, so +X is its right.
	return "R" if s > 0 else "L"


func _own(n: Node) -> void:
	for child in n.get_children():
		child.owner = _root
		if child.scene_file_path.is_empty():
			_own(child)
