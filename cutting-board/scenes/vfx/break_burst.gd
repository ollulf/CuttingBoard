class_name BreakBurst
extends Node3D

## A one-shot burst of chunky debris and a dust puff where something came apart.
## Destructible spawns it into the world as its object is freed; it reads the object's
## size and look first, so a barrel bursts bigger than a small box and the pieces wear
## the object's own material. The pieces are plain meshes moved by hand rather than
## bodies, so they cost little and never collide with anything but a flat floor.

enum Kind { WOOD, STONE }

const GRAVITY := 9.8
const LIFETIME := 1.4
## Fallback look for objects without a readable material.
const WOOD_COLOR := Color(0.55, 0.38, 0.22)
const STONE_COLOR := Color(0.5, 0.5, 0.48)

@export var kind := Kind.WOOD

var _shards: Array[Dictionary] = []
var _floor_y := 0.0
var _age := 0.0


## Reads size and material off the object about to be freed. Call before adding the
## burst to the tree.
func setup(source: Node3D) -> void:
	var box := AABB(source.global_position, Vector3.ZERO)
	var material: Material
	for mesh_instance in source.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		box = box.merge(mi.global_transform * mi.get_aabb())
		if material == null:
			material = mi.material_override
			if material == null and mi.mesh.get_surface_count() > 0:
				material = mi.get_active_material(0)
	position = box.get_center()
	_floor_y = box.position.y
	_spawn_shards(box.size, material)
	_spawn_dust(box.size)


func _spawn_shards(size: Vector3, material: Material) -> void:
	var extent := clampf(maxf(size.x, maxf(size.y, size.z)), 0.15, 2.0)
	var count := clampi(roundi(6 + extent * 8), 6, 16)
	if material == null:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = WOOD_COLOR if kind == Kind.WOOD else STONE_COLOR
		material = flat
	for i in count:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = _shard_mesh(extent)
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		mesh_instance.position = Vector3(randf_range(-0.5, 0.5) * size.x,
				randf_range(-0.4, 0.4) * size.y, randf_range(-0.5, 0.5) * size.z)
		mesh_instance.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var out := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var speed := randf_range(1.5, 3.0) * (0.7 + extent * 0.4)
		_shards.append({
			"node": mesh_instance,
			"velocity": out * speed + Vector3.UP * randf_range(2.0, 4.0),
			"spin": Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)),
		})


## Splinters for wood: long thin slats. Chunks for stone: lumpy blocks.
func _shard_mesh(extent: float) -> Mesh:
	var unit := extent * randf_range(0.12, 0.22)
	var shard := BoxMesh.new()
	if kind == Kind.WOOD:
		shard.size = Vector3(unit * 0.35, unit * 0.15, unit * randf_range(1.2, 2.2))
	else:
		shard.size = Vector3(unit, unit * randf_range(0.6, 1.0), unit * randf_range(0.7, 1.1))
	return shard


func _spawn_dust(size: Vector3) -> void:
	var extent := clampf(maxf(size.x, size.z), 0.2, 2.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * extent * 0.35
	quad.material = material
	var dust := CPUParticles3D.new()
	dust.mesh = quad
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 10 if kind == Kind.WOOD else 16
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = extent * 0.35
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.2
	dust.gravity = Vector3(0, -0.6, 0)
	dust.damping_min = 1.0
	dust.damping_max = 2.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var base := Color(0.62, 0.52, 0.4) if kind == Kind.WOOD else Color(0.6, 0.6, 0.58)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(base, 0.7))
	ramp.set_color(1, Color(base, 0.0))
	dust.color_ramp = ramp
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	dust.emitting = true


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Shrink out over the last third of the burst.
	var fade := clampf((LIFETIME - _age) / (LIFETIME / 3.0), 0.01, 1.0)
	var floor_local := _floor_y - global_position.y
	for shard in _shards:
		var node: MeshInstance3D = shard.node
		var velocity: Vector3 = shard.velocity
		velocity.y -= GRAVITY * delta
		node.position += velocity * delta
		node.rotation += shard.spin * delta
		if node.position.y < floor_local and velocity.y < 0.0:
			node.position.y = floor_local
			velocity = Vector3(velocity.x * 0.5, -velocity.y * 0.35, velocity.z * 0.5)
			shard.spin *= 0.5
		shard.velocity = velocity
		node.scale = Vector3.ONE * fade
