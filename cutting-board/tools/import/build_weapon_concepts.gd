extends "res://tools/import/mesh_builder.gd"

const DARK_WOOD := preload("res://assets/materials/environment/dark_planks.tres")
const LIGHT_WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")
const FABRIC := preload("res://assets/materials/environment/fabric_white.tres")

const UV_SCALE := 3.0
const WEAPONS := [
	["marionette_cross", "_build_marionette_cross"],
	["pegged_rolling_pin", "_build_pegged_rolling_pin"],
	["chair_leg_club", "_build_chair_leg_club"],
	["oven_peel", "_build_oven_peel"],
	["clothes_peg_knuckles", "_build_clothes_peg_knuckles"],
	["loom_shuttle", "_build_loom_shuttle"],
	["mousetrap_mace", "_build_mousetrap_mace"],
	["pendulum_maul", "_build_pendulum_maul"],
	["back_scratcher_rake", "_build_back_scratcher_rake"],
	["rocker_sickle", "_build_rocker_sickle"],
]

var _rope: StandardMaterial3D
var _leather: StandardMaterial3D
var _ember: StandardMaterial3D
var _paint: StandardMaterial3D
var _tools := {}


func _init() -> void:
	uv_scale = UV_SCALE
	_rope = FABRIC.duplicate()
	_rope.albedo_color = Color(0.78, 0.64, 0.42)
	_leather = FABRIC.duplicate()
	_leather.albedo_color = Color(0.32, 0.2, 0.13)
	_ember = StandardMaterial3D.new()
	_ember.albedo_color = Color(0.85, 0.22, 0.1)
	_ember.emission_enabled = true
	_ember.emission = Color(1.0, 0.35, 0.1)
	_ember.emission_energy_multiplier = 1.4
	_paint = StandardMaterial3D.new()
	_paint.albedo_color = Color(0.62, 0.16, 0.1)
	var ok := true
	for weapon in WEAPONS:
		_tools = {}
		call(weapon[1])
		var mesh := ArrayMesh.new()
		for material in _tools:
			_commit(mesh, _tools[material], material)
		ok = _save(mesh, "weapon_concept_%s.res" % weapon[0]) and ok
	quit(0 if ok else 1)


func _build_marionette_cross() -> void:
	_rod(DARK_WOOD, Vector3(0, -0.08, 0), Vector3(0, 0.22, 0), 0.012, 6)
	_box(LIGHT_WOOD, Vector3(0, 0.16, 0), Vector3(0.3, 0.025, 0.025))
	_box(LIGHT_WOOD, Vector3(0, 0.1, 0), Vector3(0.025, 0.025, 0.22))
	var ends := [Vector3(-0.14, 0.16, 0), Vector3(0.14, 0.16, 0), Vector3(0, 0.1, -0.1)]
	var hang := [Vector3(-0.2, -0.2, 0.04), Vector3(0.22, -0.26, 0.0), Vector3(0.02, -0.34, -0.16)]
	for k in ends.size():
		_rod(_rope, ends[k], hang[k], 0.0025, 4)
		var weight: Vector3 = hang[k]
		_lathe(_tool(DARK_WOOD), [Vector2(0, 0), Vector2(0.025, 0.012), Vector2(0.03, 0.04),
				Vector2(0.018, 0.06), Vector2(0, 0.065)] as Array[Vector2], 7,
				Transform3D(Basis.IDENTITY, weight - Vector3(0, 0.065, 0)))
	_rod(_paint, Vector3(0, 0.215, 0), Vector3(0, 0.24, 0), 0.016, 6)


func _build_pegged_rolling_pin() -> void:
	_rod(LIGHT_WOOD, Vector3(0, -0.06, 0), Vector3(0, 0.06, 0), 0.016, 7)
	_rod(LIGHT_WOOD, Vector3(0, 0.06, 0), Vector3(0, 0.36, 0), 0.042, 10)
	_rod(LIGHT_WOOD, Vector3(0, 0.36, 0), Vector3(0, 0.46, 0), 0.016, 7)
	_rod(DARK_WOOD, Vector3(0, 0.05, 0), Vector3(0, 0.07, 0), 0.025, 7)
	_rod(DARK_WOOD, Vector3(0, 0.35, 0), Vector3(0, 0.37, 0), 0.025, 7)
	for row in 5:
		for k in 6:
			var angle := TAU * (k + (row % 2) * 0.5) / 6.0
			var out := Vector3(cos(angle), 0, sin(angle))
			var y := 0.09 + row * 0.06
			_box(DARK_WOOD, Vector3(0, y, 0) + out * 0.058, Vector3(0.03, 0.022, 0.012),
					Basis(Vector3.UP, -angle))
			_rod(METAL, Vector3(0, y, 0) + out * 0.042, Vector3(0, y, 0) + out * 0.072, 0.003, 4)


func _build_chair_leg_club() -> void:
	_box(DARK_WOOD, Vector3(0, 0.0, 0), Vector3(0.032, 0.18, 0.032))
	_lathe(_tool(DARK_WOOD), [Vector2(0, 0), Vector2(0.024, 0), Vector2(0.03, 0.03), Vector2(0.022, 0.06),
			Vector2(0.034, 0.1), Vector2(0.026, 0.14), Vector2(0.03, 0.2), Vector2(0, 0.2)] as Array[Vector2],
			8, Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)))
	_box(DARK_WOOD, Vector3(0, 0.39, 0), Vector3(0.05, 0.2, 0.05))
	_box(DARK_WOOD, Vector3(0.0, 0.42, -0.06), Vector3(0.018, 0.018, 0.08))
	_box(_leather, Vector3(0, 0.495, 0), Vector3(0.06, 0.012, 0.06))
	for k in 4:
		var angle := TAU * k / 4.0 + 0.4
		_box(LIGHT_WOOD, Vector3(cos(angle) * 0.012, -0.1 - k * 0.006, sin(angle) * 0.012),
				Vector3(0.012, 0.03 + k * 0.008, 0.01), Basis(Vector3.FORWARD, 0.2 * (k - 1.5)))


func _build_oven_peel() -> void:
	_rod(LIGHT_WOOD, Vector3(0, -0.2, 0), Vector3(0, 0.42, 0), 0.016, 7)
	_lathe(_tool(LIGHT_WOOD), [Vector2(0, 0), Vector2(0.03, 0), Vector2(0.03, 0.02), Vector2(0, 0.02)] as Array[Vector2],
			7, Transform3D(Basis.IDENTITY, Vector3(0, -0.22, 0)))
	var t := 0.012
	var outline := [Vector2(-0.05, 0.4), Vector2(0.05, 0.4), Vector2(0.13, 0.5), Vector2(0.14, 0.78),
			Vector2(0.1, 0.82), Vector2(-0.1, 0.82), Vector2(-0.14, 0.78), Vector2(-0.13, 0.5)]
	_slab(LIGHT_WOOD, outline, t)
	_box(_rope, Vector3(0, 0.44, 0), Vector3(0.05, 0.03, 0.03))
	for k in 5:
		var at := Vector3(-0.07 + k * 0.035, 0.62 + (k % 2) * 0.06, -t * 0.5 - 0.012)
		_box(_ember, at, Vector3(0.026, 0.022, 0.022), Basis(Vector3(1, 1, 0).normalized(), k * 0.7))
	_box(DARK_WOOD, Vector3(0, 0.7, -t * 0.5 - 0.001), Vector3(0.18, 0.2, 0.002))


func _build_clothes_peg_knuckles() -> void:
	_box(LIGHT_WOOD, Vector3(0, 0, -0.02), Vector3(0.03, 0.14, 0.02))
	_box(_leather, Vector3(0, 0, 0.03), Vector3(0.03, 0.15, 0.012))
	for k in 4:
		var y := -0.054 + k * 0.036
		_rod(_leather, Vector3(0, y, -0.02), Vector3(0, y, 0.03), 0.006, 4)
		for side in [-1.0, 1.0]:
			_box(LIGHT_WOOD, Vector3(side * 0.006, y, -0.07), Vector3(0.007, 0.012, 0.09),
					Basis(Vector3.UP, side * 0.08))
		_spring(Vector3(-0.009, y, -0.06), Vector3(0.009, y, -0.06), 0.006, 2, 0.0015)


func _build_loom_shuttle() -> void:
	_lathe(_tool(LIGHT_WOOD), [Vector2(0, -0.14), Vector2(0.012, -0.11), Vector2(0.024, -0.06),
			Vector2(0.026, 0.0), Vector2(0.024, 0.06), Vector2(0.012, 0.11), Vector2(0, 0.14)] as Array[Vector2],
			6, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	_rod(METAL, Vector3(0, 0, -0.14), Vector3(0, 0, -0.18), 0.004, 4)
	_rod(METAL, Vector3(0, 0, 0.14), Vector3(0, 0, 0.18), 0.004, 4)
	_box(DARK_WOOD, Vector3(0, 0.02, 0), Vector3(0.03, 0.012, 0.1))
	_rod(_paint, Vector3(0, 0.02, -0.035), Vector3(0, 0.02, 0.035), 0.012, 6)
	_rod(_paint, Vector3(0, 0.026, 0.0), Vector3(0.05, 0.0, 0.2), 0.0025, 4)


func _build_mousetrap_mace() -> void:
	_rod(DARK_WOOD, Vector3(0, -0.14, 0), Vector3(0, 0.36, 0), 0.015, 7)
	_box(LIGHT_WOOD, Vector3(0, 0.44, 0), Vector3(0.1, 0.2, 0.02))
	_rod(METAL, Vector3(-0.045, 0.44, -0.014), Vector3(0.045, 0.44, -0.014), 0.004, 4)
	_spring(Vector3(-0.045, 0.44, -0.014), Vector3(-0.02, 0.44, -0.014), 0.01, 3, 0.002)
	_spring(Vector3(0.02, 0.44, -0.014), Vector3(0.045, 0.44, -0.014), 0.01, 3, 0.002)
	_rod(METAL, Vector3(-0.04, 0.44, -0.014), Vector3(-0.04, 0.35, -0.03), 0.003, 4)
	_rod(METAL, Vector3(0.04, 0.44, -0.014), Vector3(0.04, 0.35, -0.03), 0.003, 4)
	_rod(METAL, Vector3(-0.04, 0.35, -0.03), Vector3(0.04, 0.35, -0.03), 0.003, 4)
	_rod(METAL, Vector3(0, 0.52, -0.014), Vector3(0, 0.38, -0.02), 0.002, 4)
	_box(_ember, Vector3(0, 0.5, -0.016), Vector3(0.025, 0.02, 0.01))
	_lash(Vector3(0, 0.33, 0), 0.03)


func _build_pendulum_maul() -> void:
	_rod(DARK_WOOD, Vector3(0, -0.08, 0), Vector3(0, 0.08, 0), 0.017, 7)
	_rod(METAL, Vector3(0, 0.08, 0), Vector3(0, 0.62, 0), 0.006, 5)
	_rod(METAL, Vector3(-0.012, 0.3, 0), Vector3(0.012, 0.3, 0), 0.004, 4)
	_lathe(_tool(METAL), [Vector2(0, -0.022), Vector2(0.08, -0.022), Vector2(0.11, -0.012),
			Vector2(0.11, 0.012), Vector2(0.08, 0.022), Vector2(0, 0.022)] as Array[Vector2],
			12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.72, 0)))
	_rod(_paint, Vector3(0, 0.72, -0.022), Vector3(0, 0.72, -0.026), 0.05, 10)
	_box(DARK_WOOD, Vector3(0, 0.6, 0), Vector3(0.03, 0.03, 0.03))


func _build_back_scratcher_rake() -> void:
	_rod(LIGHT_WOOD, Vector3(0, -0.16, 0), Vector3(0, 0.46, 0), 0.011, 6)
	_box(LIGHT_WOOD, Vector3(0, 0.5, -0.01), Vector3(0.09, 0.08, 0.018), Basis(Vector3.RIGHT, 0.3))
	for k in 5:
		var x := -0.036 + k * 0.018
		var base := Vector3(x, 0.53, -0.02)
		var knuckle := base + Vector3(x * 0.3, 0.05 - absf(x) * 0.6, -0.025)
		_rod(LIGHT_WOOD, base, knuckle, 0.007, 5)
		_rod(DARK_WOOD, knuckle, knuckle + Vector3(0, -0.01, -0.035), 0.005, 4)
	_rod(_leather, Vector3(0, -0.16, 0), Vector3(0, -0.12, 0), 0.014, 6)
	_rod(_paint, Vector3(0, 0.44, 0), Vector3(0, 0.455, 0), 0.014, 6)


func _build_rocker_sickle() -> void:
	_rod(DARK_WOOD, Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), 0.016, 7)
	_rod(DARK_WOOD, Vector3(0, 0.1, 0), Vector3(0, 0.18, 0), 0.022, 7)
	var segments := 9
	var radius := 0.26
	var centre := Vector3(0, 0.18, -radius)
	for k in segments:
		var a0 := k * 0.2
		var a1 := a0 + 0.2
		var p0 := centre + Vector3(0, sin(a0) * radius, cos(a0) * radius)
		var p1 := centre + Vector3(0, sin(a1) * radius, cos(a1) * radius)
		var mid := (p0 + p1) * 0.5
		var along := p1 - p0
		var basis := Basis.looking_at(along, Vector3.RIGHT)
		_box(DARK_WOOD, mid, Vector3(0.04, 0.022, along.length() + 0.004), basis)
		var inner := mid + (centre - mid).normalized() * 0.026
		_box(LIGHT_WOOD, inner, Vector3(0.014, 0.008, along.length() + 0.004), basis)
	_lash(Vector3(0, 0.17, 0), 0.03)


func _slab(material: Material, outline: Array, thickness: float) -> void:
	var tool := _tool(material)
	var h := thickness * 0.5
	var front: Array = []
	var back: Array = []
	for p in outline:
		front.append(Vector3(p.x, p.y, -h))
		back.append(Vector3(p.x, p.y, h))
	_face_fan(tool, front, Vector3.FORWARD)
	_face_fan(tool, back, Vector3.BACK)
	for k in outline.size():
		var j := (k + 1) % outline.size()
		var edge: Vector2 = outline[j] - outline[k]
		_face(tool, [front[k], front[j], back[j], back[k]], Vector3(edge.y, -edge.x, 0))


func _face_fan(tool: SurfaceTool, corners: Array, facing: Vector3) -> void:
	for k in range(1, corners.size() - 1):
		_face(tool, [corners[0], corners[k], corners[k + 1]], facing)


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		_tools[material] = _begin()
	return _tools[material]


func _box(material: Material, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var tool := _tool(material)
	var h := size * 0.5
	for axis in 3:
		for s in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var corners: Array = []
			for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var local := Vector3.ZERO
				local[axis] = s * h[axis]
				local[u] = c[0] * h[u]
				local[v] = c[1] * h[v]
				corners.append(center + basis * local)
			var facing := Vector3.ZERO
			facing[axis] = s
			_face(tool, corners, basis * facing)


func _rod(material: Material, a: Vector3, b: Vector3, radius: float, sides: int) -> void:
	var length := a.distance_to(b)
	var profile: Array[Vector2] = [Vector2(0, 0), Vector2(radius, 0), Vector2(radius, length), Vector2(0, length)]
	_lathe(_tool(material), profile, sides, _along(a, b))


func _along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), a)


func _spring(a: Vector3, b: Vector3, radius: float, turns: int, wire: float, material: Material = METAL) -> void:
	var frame := _along(a, b)
	var length := a.distance_to(b)
	var steps := turns * 8
	var last := Vector3.ZERO
	for k in steps + 1:
		var t := float(k) / steps
		var angle := TAU * turns * t
		var point := frame * Vector3(cos(angle) * radius, t * length, sin(angle) * radius)
		if k > 0:
			_rod(material, last, point, wire, 4)
		last = point


func _lash(center: Vector3, radius: float) -> void:
	for turn in 3:
		var offset := Vector3(0, (turn - 1) * 0.008, 0)
		var last := Vector3.ZERO
		for k in 9:
			var angle := TAU * k / 8.0
			var point := center + offset + Vector3(cos(angle) * radius * 0.7, 0, sin(angle) * radius * 0.7)
			if k > 0:
				_rod(_rope, last, point, 0.0035, 4)
			last = point
