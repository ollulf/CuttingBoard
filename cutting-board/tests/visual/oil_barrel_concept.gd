extends Node3D

## Concept prototype for the oil barrel (docs/concepts/oil-barrel.md): a darkened item
## barrel leaking a small stain is kicked into a post, breaks, and an oil puddle
## spreads where it burst. Nothing here is game code; the puddle lives in this file.
##
##   godot --path cutting-board --write-movie <dir>/oil.avi --fixed-fps 30
##       --resolution 960x540 --quit-after 120 res://tests/visual/oil_barrel_concept.tscn

const BARREL := preload("res://scenes/items/barrel.tscn")
## Multiplies the barrel's wood and iron: oil-soaked staves read near black.
const OIL_TINT := Color(0.34, 0.29, 0.26)
const KICK_IMPULSE := Vector3(320.0, 50.0, 0.0)
const POST_X := 2.2

var _barrel: RigidBody3D
var _kicked := false


func _ready() -> void:
	PsxScreen.enabled = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	# The sky colour shows in glossy surfaces, so the oil reads wet rather than flat black.
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.4, 0.32)
	floor_mesh.material_override = floor_mat
	ground.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(floor_shape)
	add_child(ground)

	# A post to kick the barrel into.
	var post := StaticBody3D.new()
	var post_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.6, 1.6)
	post_mesh.mesh = box
	post.add_child(post_mesh)
	var post_shape := CollisionShape3D.new()
	var post_box := BoxShape3D.new()
	post_box.size = box.size
	post_shape.shape = post_box
	post.add_child(post_shape)
	add_child(post)
	post.global_position = Vector3(POST_X + 0.2, 0.8, 0.0)

	_barrel = BARREL.instantiate()
	_barrel.freeze = true
	add_child(_barrel)
	_barrel.global_position = Vector3(-1.2, 0.46, 0.0)
	_soak(_barrel)
	_barrel.get_node("Destructible").destroyed.connect(_on_barrel_destroyed)

	# The leak under a standing oil barrel: a hint that it is not a water barrel.
	var stain := OilPuddle.new()
	stain.radius = 0.55
	add_child(stain)
	stain.global_position = Vector3(-1.05, 0.0, 0.25)

	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0.4, 2.6, 4.6), Vector3(0.6, 0.2, 0))
	camera.make_current()

	await get_tree().create_timer(0.8).timeout
	# Stand-in for the player's kick (kick.gd pushes 320 N s at full strength).
	_barrel.freeze = false
	_barrel.apply_impulse(KICK_IMPULSE)
	await get_tree().create_timer(0.3).timeout
	_kicked = true


func _physics_process(_delta: float) -> void:
	if not _kicked or not is_instance_valid(_barrel):
		return
	# Breaks on the post (or wherever it stops short of it); ImpactDamage would do this
	# in game, forced here so the clip does not depend on how hard the hit lands.
	if _barrel.global_position.x > POST_X - 0.75 or _barrel.linear_velocity.length() < 0.4:
		(_barrel.get_node("Destructible") as Destructible).damage(Destructible.MAX_DURABILITY)


func _on_barrel_destroyed() -> void:
	var puddle := OilPuddle.new()
	puddle.radius = 1.3
	add_child(puddle)
	var at := _barrel.global_position
	puddle.global_position = Vector3(at.x - 0.2, 0.0, at.z)
	puddle.spread(1.2)


## Darkens every surface of the barrel's meshes by OIL_TINT.
func _soak(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var soaked := mat.duplicate() as StandardMaterial3D
				soaked.albedo_color *= OIL_TINT
				soaked.roughness = 0.45
				soaked.metallic_specular = 0.8
				mi.set_surface_override_material(i, soaked)


## A flat, irregular blob of glossy oil that grows from a point to `radius`. A few
## smaller lobes around the main one break up the circle.
class OilPuddle:
	extends Node3D

	## Near-black oil with a sky-coloured sheen at grazing angles and faint rainbow
	## bands that drift across it, so it reads wet even without real reflections.
	const SHEEN_SHADER := """
shader_type spatial;
render_mode cull_disabled;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.0);
	float band = sin(world_pos.x * 4.0 + cos(world_pos.z * 3.0) * 2.0 + TIME * 0.6);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (band * 0.5 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = vec3(0.05, 0.04, 0.03);
	ROUGHNESS = 0.08;
	SPECULAR = 1.0;
	EMISSION = vec3(0.3, 0.36, 0.45) * fresnel * 0.6 + rainbow * 0.05;
}
"""

	var radius := 1.0
	var lobes := 4
	var points := 28

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = SHEEN_SHADER
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(radius)
		_add_blob(Vector2.ZERO, radius, rng, mat, 0.012)
		for i in lobes:
			var angle := rng.randf() * TAU
			var offset := Vector2.from_angle(angle) * radius * rng.randf_range(0.55, 0.85)
			_add_blob(offset, radius * rng.randf_range(0.3, 0.5), rng, mat, 0.011)

	## Grows over `seconds`, fast at first like a spill.
	func spread(seconds: float) -> void:
		scale = Vector3(0.05, 1.0, 0.05)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ONE, seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _add_blob(center: Vector2, r: float, rng: RandomNumberGenerator,
			mat: Material, height: float) -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		var rim: Array[Vector3] = []
		var phase := rng.randf() * TAU
		for i in points:
			var a := TAU * i / points
			# Two sine wobbles plus noise give a soft, uneven edge.
			var k := 1.0 + 0.12 * sin(a * 3.0 + phase) + 0.08 * sin(a * 5.0 - phase) \
				+ rng.randf_range(-0.05, 0.05)
			rim.append(Vector3(center.x + cos(a) * r * k, height, center.y + sin(a) * r * k))
		var mid := Vector3(center.x, height, center.y)
		for i in points:
			st.add_vertex(mid)
			st.add_vertex(rim[(i + 1) % points])
			st.add_vertex(rim[i])
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = st.commit()
		mesh_instance.material_override = mat
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
