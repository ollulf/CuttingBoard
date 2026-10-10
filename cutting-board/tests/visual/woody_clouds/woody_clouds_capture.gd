extends Node3D

const VILLAGE := preload("res://scenes/levels/village.tscn")
const LIGHTING := {
	"day": preload("res://scenes/levels/lighting/daylight_lighting.tscn"),
	"night": preload("res://scenes/levels/lighting/tallow_fair_lighting.tscn"),
}
const PLYWOOD := preload("res://tests/visual/woody_clouds/plywood.gdshader")
const EYE := Vector3(0.0, 2.5, 32.0)
const LOOK := Vector3(-2.0, 18.0, -40.0)

var _lighting: Node
var _clouds: Node3D
var _swayers: Array = []
var _sliders: Array = []
var _time := 0.0


func _ready() -> void:
	var shots_dir := ""
	var clip := ""
	var clip_time := "day"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		elif arg.begins_with("--time="):
			clip_time = arg.trim_prefix("--time=")
	add_child(VILLAGE.instantiate())
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.position = EYE
	camera.look_at(LOOK)
	if clip != "":
		_setup(clip, clip_time)
		return
	for concept in ["plain", "A", "B", "C"]:
		for time in ["day", "night"]:
			_setup(concept, time)
			for i in 12:
				await get_tree().process_frame
			if shots_dir != "":
				DirAccess.make_dir_recursive_absolute(shots_dir)
				get_viewport().get_texture().get_image().save_png(
					"%s/%s_%s.png" % [shots_dir, concept, time])
	get_tree().quit()


func _process(delta: float) -> void:
	_time += delta
	for s in _swayers:
		var node: Node3D = s[0]
		node.rotation.z = sin(_time * 0.5 + s[1]) * 0.04
		node.rotation.x = sin(_time * 0.37 + s[1] * 1.7) * 0.025
	for s in _sliders:
		var node: Node3D = s[0]
		node.position.x = s[1] + sin(_time * 0.12 + s[2]) * 6.0


func _setup(concept: String, time: String) -> void:
	if _lighting:
		_lighting.queue_free()
	if _clouds:
		_clouds.queue_free()
	_swayers.clear()
	_sliders.clear()
	_lighting = LIGHTING[time].instantiate()
	add_child(_lighting)
	_clouds = Node3D.new()
	_clouds.position = Vector3(0, -4, 48)
	add_child(_clouds)
	var night := time == "night"
	if concept != "B":
		_hide_wood_clouds()
	match concept:
		"A":
			_build_whittled(night)
		"C":
			_build_plywood(night)


func _build_whittled(night: bool) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.30, 0.34) if night else Color(0.74, 0.52, 0.32)
	wood.roughness = 0.85
	var string_mat := StandardMaterial3D.new()
	string_mat.albedo_color = Color(0.25, 0.2, 0.15)
	string_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := [
		Vector3(-14, 18, -34), Vector3(6, 22, -46), Vector3(-30, 26, -58),
		Vector3(20, 16, -30), Vector3(-6, 30, -70), Vector3(34, 27, -62),
	]
	for i in spots.size():
		var pivot := Node3D.new()
		pivot.position = spots[i] + Vector3(0, 40, 0)
		_clouds.add_child(pivot)
		var cloud := Node3D.new()
		cloud.position = Vector3(0, -40, 0)
		pivot.add_child(cloud)
		var width := rng.randf_range(5.0, 9.0)
		var lumps := rng.randi_range(4, 6)
		for j in lumps:
			var t := float(j) / (lumps - 1) - 0.5
			var lump := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			var r := rng.randf_range(1.4, 2.4) * (1.0 - absf(t) * 0.8)
			sphere.radius = r
			sphere.height = r * 1.6
			sphere.radial_segments = 7
			sphere.rings = 4
			lump.mesh = sphere
			lump.material_override = wood
			lump.position = Vector3(t * width, rng.randf_range(0.0, 0.8), rng.randf_range(-0.6, 0.6))
			lump.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.4)
			cloud.add_child(lump)
		var base := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width * 0.9, 0.5, 2.2)
		base.mesh = box
		base.material_override = wood
		base.position = Vector3(0, -0.9, 0)
		cloud.add_child(base)
		for side in [-0.3, 0.3]:
			var string := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.04
			cyl.height = 40.0
			cyl.radial_segments = 4
			string.mesh = cyl
			string.material_override = string_mat
			string.position = Vector3(side * width, 20.0, 0)
			cloud.add_child(string)
		_swayers.append([pivot, float(i) * 1.3])


func _hide_wood_clouds() -> void:
	var world_env := _find_world_env(_lighting)
	var env: Environment = world_env.environment.duplicate(true)
	(env.sky.sky_material as ShaderMaterial).set_shader_parameter("cloud_cover", 0.0)
	world_env.environment = env


func _find_world_env(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found := _find_world_env(child)
		if found:
			return found
	return null


func _build_plywood(night: bool) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = PLYWOOD
	if night:
		mat.set_shader_parameter("wood_light", Color(0.38, 0.30, 0.36))
		mat.set_shader_parameter("wood_dark", Color(0.26, 0.20, 0.26))
		mat.set_shader_parameter("edge_color", Color(0.12, 0.08, 0.10))
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.3, 0.2, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rows := [[-30.0, 15.0, 3], [-48.0, 21.0, 3], [-70.0, 28.0, 4]]
	for row in rows:
		var z: float = row[0]
		var y: float = row[1]
		var count: int = row[2]
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(160, 0.3, 0.3)
		rail.mesh = rail_box
		rail.material_override = rail_mat
		rail.position = Vector3(0, y + 7.0, z)
		_clouds.add_child(rail)
		for k in count:
			var flat := CSGPolygon3D.new()
			flat.polygon = _cloud_outline(rng)
			flat.depth = 0.4
			flat.material = mat
			var x0 := (float(k) - (count - 1) * 0.5) * 22.0 + rng.randf_range(-4, 4)
			flat.position = Vector3(x0, y, z)
			_clouds.add_child(flat)
			for side in [-2.5, 2.5]:
				var rod := MeshInstance3D.new()
				var rod_box := BoxMesh.new()
				rod_box.size = Vector3(0.12, 7.0, 0.12)
				rod.mesh = rod_box
				rod.material_override = rail_mat
				rod.position = Vector3(side, 3.5, -0.2)
				flat.add_child(rod)
			_sliders.append([flat, x0, rng.randf() * TAU])


func _cloud_outline(rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := rng.randf_range(4.5, 6.5)
	pts.append(Vector2(half, 0))
	var bumps := rng.randi_range(3, 4)
	var step := 2.0 * half / bumps
	for bi in bumps:
		var b := bumps - 1 - bi
		var cx := -half + step * (b + 0.5)
		var r := step * 0.5 * rng.randf_range(1.0, 1.3)
		var cy := r * 0.4 + (1.2 if b == 1 or b == bumps - 2 else 0.0)
		for a in range(0, 9):
			var ang := PI * a / 8.0
			pts.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r))
	pts.append(Vector2(-half, 0))
	return pts
