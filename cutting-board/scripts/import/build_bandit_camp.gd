extends SceneTree

## Builds scenes/environment/bandit_camp/bandit_camp.tscn, the Hollowstump bandit camp
## (layout: docs/concepts/bandit-camp-layout.md). The camp origin is the middle of the
## hollow oak; the door and the yard gate face west (-X), toward the village.
##
## It places existing props (village fences, boxes, barrels, the lantern, rocks, the
## chest) and a few primitive-built ones (curtain, straw bed, fire pit, stump table,
## mask rack, lookout platform). Run it again whenever the tables below change:
##   godot --headless --path cutting-board -s res://scripts/import/build_bandit_camp.gd

const OUT := "res://scenes/environment/bandit_camp/bandit_camp.tscn"

const HOLLOW_OAK := preload("res://scenes/environment/bandit_camp/hollow_oak.gd")
const FENCE := preload("res://scenes/environment/buildings/1x2_fence.tscn")
const BOX := preload("res://scenes/environment/decoration/1_box.tscn")
const BOX_2 := preload("res://scenes/environment/decoration/2_box.tscn")
const BARREL := preload("res://scenes/environment/decoration/barrel_1.tscn")
const SACK := preload("res://scenes/environment/decoration/sack.tscn")
const LANTERN := preload("res://scenes/environment/decoration/lantern.tscn")
const ROCK := preload("res://scenes/environment/foliage/rocks/1_rock.tscn")
const ROCK_2 := preload("res://scenes/environment/foliage/rocks/2_rock.tscn")
const CHEST := preload("res://scenes/props/chest.tscn")
const BANDIT := preload("res://scenes/characters/bandit.tscn")
const ROCK_ITEM :=preload("res://scenes/items/rock.tscn")
const BANDIT_MASK_MESH := preload("res://scenes/characters/masks/bandit_mask.tscn")
const VILLAGER_MASK_MESH := preload("res://scenes/characters/masks/villager_mask.tscn")

const PLANKS := preload("res://assets/materials/environment/wooden_planks.tres")
const DARK_PLANKS := preload("res://assets/materials/environment/dark_planks.tres")
const BARK := preload("res://assets/materials/environment/foliage/tree_strange_1_bark.tres")
const STONE := preload("res://assets/materials/environment/foliage/stone_1.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")

## Palisade ring around the tree, with a gate gap facing west.
const YARD_RADIUS := 8.5
const FENCE_COUNT := 11
const GATE_GAP := 0.42

var _root: Node3D


func _init() -> void:
	_root = Node3D.new()
	_root.name = "BanditCamp"

	var oak := Node3D.new()
	oak.name = "HollowOak"
	oak.set_script(HOLLOW_OAK)
	oak.unique_name_in_owner = true
	_add(oak, Vector3.ZERO, 0.0, ["navigation_source"])

	_build_palisade()
	_build_den()
	_build_lookout()
	_build_yard()
	_group("Bandits")

	var scene := PackedScene.new()
	var err := scene.pack(_root)
	if err == OK:
		err = ResourceSaver.save(scene, OUT)
	if err == OK:
		err = _append_bandits()
	print("bandit camp -> %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _build_palisade() -> void:
	var fences := _group("Palisade")
	var step := (TAU - GATE_GAP) / FENCE_COUNT
	for i in FENCE_COUNT:
		var a := PI + GATE_GAP * 0.5 + step * (i + 0.5)
		var pos := Vector3(cos(a), 0, sin(a)) * YARD_RADIUS
		_add(FENCE.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), pos, -a - PI * 0.5, ["navigation_source"], fences, "Fence%d" % i)


func _build_den() -> void:
	var den := _group("Den")
	# Stolen curtain over the door, pulled to one side; no collision, so it never blocks.
	var curtain := _box_mesh(Vector3(0.05, 2.1, 1.1), _cloth(Color(0.55, 0.16, 0.14)))
	_add(curtain, Vector3(-3.0, 1.15, -0.75), 0.0, [], den, "Curtain")
	var rod := _box_mesh(Vector3(0.06, 0.06, 2.4), PLANKS)
	_add(rod, Vector3(-3.0, 2.25, 0.0), 0.0, [], den, "CurtainRod")

	var chest := CHEST.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	chest.unique_name_in_owner = true
	_add(chest, Vector3(0.6, 0.0, -1.7), PI * 0.5, ["navigation_source"], den, "LootChest")

	var lantern := LANTERN.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_add(lantern, Vector3(0.0, 2.2, 0.0), 0.0, [], den, "Lantern")
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.shadow_enabled = true
	_add(light, Vector3(0.0, 1.9, 0.0), 0.0, [], den, "LanternLight")

	var bed := _box_mesh(Vector3(1.0, 0.25, 1.9), _cloth(Color(0.78, 0.66, 0.36)))
	_add(bed, Vector3(1.2, 0.12, 1.0), 0.25, [], den, "StrawBed")
	_add(SACK.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(1.6, 0.0, 2.0), 0.6, [], den, "Pillow")

	# The bush in front of the back crack: a few dark leafy blobs, see-through for nav.
	var bush := _group("CrackBush", den)
	for p in [Vector3(4.4, 0.5, 0.3), Vector3(4.2, 0.4, -0.5), Vector3(4.7, 0.35, 0.9)]:
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.7
		sphere.height = 1.1
		sphere.radial_segments = 7
		sphere.rings = 4
		blob.mesh = sphere
		blob.material_override = _cloth(Color(0.2, 0.3, 0.14))
		_add(blob, p, 0.0, [], bush)


## The broken limb on the north-east side with a plank platform at 6 m. There is no
## climbing yet, so the lookout bandit is simply placed up there (see the layout notes).
func _build_lookout() -> void:
	var lookout := _group("Lookout")
	var limb := StaticBody3D.new()
	limb.name = "Limb"
	var limb_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.6
	cyl.height = 3.6
	cyl.radial_segments = 7
	limb_mesh.mesh = cyl
	limb_mesh.material_override = BARK
	limb.add_child(limb_mesh)
	var dir := Vector3(1, 0, -1).normalized()
	limb.transform = Transform3D(Basis(dir.cross(Vector3.UP).normalized(), deg_to_rad(-62)), dir * 4.2 + Vector3.UP * 5.6)
	lookout.add_child(limb)
	limb_mesh.owner = _root
	limb.owner = _root

	var platform := StaticBody3D.new()
	platform.name = "Platform"
	platform.unique_name_in_owner = true
	var deck := _box_mesh(Vector3(2.6, 0.15, 2.2), DARK_PLANKS)
	platform.add_child(deck)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 0.15, 2.2)
	shape.shape = box
	platform.add_child(shape)
	_add(platform, dir * 4.6 + Vector3.UP * 6.0, PI * 0.25, [], lookout)
	deck.owner = _root
	shape.owner = _root
	# A low rail on the outer edges.
	for x in [-1.25, 1.25]:
		_add(_box_mesh(Vector3(0.1, 0.6, 2.2), PLANKS), Vector3(x, 0.35, 0), 0.0, [], platform)
	_add(_box_mesh(Vector3(2.6, 0.6, 0.1), PLANKS), Vector3(0, 0.35, -1.05), 0.0, [], platform)


func _build_yard() -> void:
	var yard := _group("Yard")
	# Fire pit: a ring of stones, charred logs, a soup pot and the glow.
	var fire := _group("FirePit", yard)
	fire.position = Vector3(-4.6, 0, 3.2)
	for i in 7:
		var a := TAU * i / 7.0
		var stone := _box_mesh(Vector3(0.35, 0.22, 0.3), STONE)
		_add(stone, Vector3(cos(a), 0.11, sin(a)) * Vector3(0.7, 1, 0.7) + Vector3(0, 0.11, 0), a, [], fire)
	for a in [0.3, 1.9]:
		_add(_box_mesh(Vector3(0.9, 0.12, 0.14), DARK_PLANKS), Vector3(0, 0.1, 0), a, [], fire)
	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.3
	pot_mesh.bottom_radius = 0.22
	pot_mesh.height = 0.4
	pot_mesh.radial_segments = 8
	pot.mesh = pot_mesh
	pot.material_override = METAL
	_add(pot, Vector3(0, 0.55, 0), 0.0, [], fire, "SoupPot")
	for side in [-1.0, 1.0]:
		_add(_box_mesh(Vector3(0.06, 0.95, 0.06), DARK_PLANKS), Vector3(0.55 * side, 0.47, 0), 0.0, [], fire)
	_add(_box_mesh(Vector3(1.2, 0.05, 0.05), DARK_PLANKS), Vector3(0, 0.93, 0), 0.0, [], fire)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 2.0
	glow.omni_range = 7.0
	_add(glow, Vector3(0, 0.6, 0), 0.0, [], fire, "FireLight")

	# Stump table with a stolen villager mask and the camp's spare rocks on it.
	var table := StaticBody3D.new()
	table.name = "StumpTable"
	var table_mesh := MeshInstance3D.new()
	var stump := CylinderMesh.new()
	stump.top_radius = 0.55
	stump.bottom_radius = 0.7
	stump.height = 0.8
	stump.radial_segments = 9
	table_mesh.mesh = stump
	table_mesh.material_override = BARK
	table.add_child(table_mesh)
	var table_shape := CollisionShape3D.new()
	var table_cyl := CylinderShape3D.new()
	table_cyl.radius = 0.6
	table_cyl.height = 0.8
	table_shape.shape = table_cyl
	table.add_child(table_shape)
	_add(table, Vector3(-4.4, 0.4, -3.4), 0.0, ["navigation_source"], yard)
	table_mesh.owner = _root
	table_shape.owner = _root

	# Mask rack by the door: two posts and a bar with stolen masks hung on it.
	var rack := _group("MaskRack", yard)
	rack.position = Vector3(-4.0, 0, -1.6)
	rack.rotation.y = PI * 0.5
	for x in [-0.8, 0.8]:
		_add(_box_mesh(Vector3(0.1, 1.7, 0.1), DARK_PLANKS), Vector3(x, 0.85, 0), 0.0, [], rack)
	_add(_box_mesh(Vector3(1.8, 0.08, 0.08), PLANKS), Vector3(0, 1.6, 0), 0.0, [], rack)
	var masks := [VILLAGER_MASK_MESH, VILLAGER_MASK_MESH, BANDIT_MASK_MESH, VILLAGER_MASK_MESH]
	for i in masks.size():
		_add(masks[i].instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(-0.6 + 0.4 * i, 1.4, -0.06), PI, [], rack, "Mask%d" % i)

	# Rock pile by the gate, real throwable rocks on top of a couple of boulders.
	var pile := _group("RockPile", yard)
	pile.position = Vector3(-7.0, 0, 2.6)
	_add(ROCK_2.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3.ZERO, 0.0, ["navigation_source"], pile, "Boulder")
	for i in 4:
		var a := TAU * i / 4.0
		_add(ROCK_ITEM.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(cos(a) * 0.7, 0.4, sin(a) * 0.7), a, [], pile, "Rock%d" % i)

	# Loot stacked around the trunk.
	var stash := _group("Stash", yard)
	_add(BARREL.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(1.8, 0, 5.0), 0.0, ["navigation_source"], stash)
	_add(BARREL.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(2.8, 0, 4.6), 1.2, ["navigation_source"], stash)
	_add(BOX.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(-0.6, 0, -5.2), 0.3, ["navigation_source"], stash)
	_add(BOX_2.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(0.8, 0, -5.6), -0.2, ["navigation_source"], stash)
	_add(SACK.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(4.6, 0, -3.8), 0.9, [], stash)
	_add(ROCK.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector3(5.6, 0, 3.4), 0.0, ["navigation_source"], stash)


## The five bandits, each the stock bandit tuned for its role through the existing NPC
## exports: wander radius around its home, sight range, cowardice, defend allies. The
## NPC scripts need autoloads that a -s run doesn't have, so the bandits are written as
## plain scene text (instances with property overrides) after the scene is saved.
func _append_bandits() -> Error:
	var lookout_at := Vector3(1, 0, -1).normalized() * 4.6 + Vector3.UP * 6.2
	# name, position, yaw, wander radius, sight metres, flee below health, hears allies
	var roles := [
		["Lookout", lookout_at, PI * 0.75, 0.0, 25.0, 0.0, false],
		["GateGuardNorth", Vector3(-9.6, 0, -2.2), PI * 0.5, 2.0, 15.0, 0.0, false],
		["GateGuardSouth", Vector3(-9.6, 0, 2.2), PI * 0.5, 2.0, 15.0, 0.0, false],
		["Cook", Vector3(-4.6, 0, 4.4), 0.0, 2.5, 12.0, 0.6, false],
		["Sleeper", Vector3(0.6, 0, 0.6), 0.0, 0.5, 4.0, 0.0, true],
	]
	var text := FileAccess.get_file_as_string(OUT)
	var header_end := text.find("\n\n[", text.find("[ext_resource"))
	text = text.insert(header_end, "\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"bandit\"]" % BANDIT.resource_path)
	for role in roles:
		var path := "Bandits/%s" % role[0]
		text += "\n[node name=\"%s\" parent=\"Bandits\" instance=ExtResource(\"bandit\")]\n" % role[0]
		text += "transform = %s\n" % var_to_str(Transform3D(Basis(Vector3.UP, role[2]), role[1]))
		text += "defend_allies_radius = 14.0\n"
		if role[6]:
			text += "hears_allies = true\n"
		text += "\n[node name=\"Sight\" parent=\"%s/Eyes\" index=\"0\"]\nview_distance = %s\n" % [path, role[4]]
		text += "\n[node name=\"Wander\" parent=\"%s/Brain\" index=\"0\"]\nradius = %s\n" % [path, role[3]]
		if role[5] > 0.0:
			text += "\n[node name=\"Flee\" parent=\"%s/Brain\" index=\"1\"]\ncowardice = 1.0\nflee_below_health = %s\n" % [path, role[5]]
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	return OK


func _group(group_name: String, parent: Node = null) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	_add(node, Vector3.ZERO, 0.0, [], parent)
	return node


func _add(node: Node3D, pos: Vector3, yaw: float, groups: Array, parent: Node = null, node_name := "") -> Node3D:
	if node_name != "":
		node.name = node_name
	node.position = pos
	if yaw != 0.0:
		node.rotation.y = yaw
	for g in groups:
		node.add_to_group(g, true)
	(parent if parent else _root).add_child(node, true)
	node.owner = _root
	return node


func _box_mesh(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	return mesh_instance


func _cloth(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
