@tool
extends Node3D
## Hollowstump: the dead hollow oak the bandits live in. Builds a ring trunk mesh with
## a west door and a narrow east crack, plus one box collider per wall segment, so the
## hollow inside stays walkable and the navmesh bakes through the openings.

const SEGMENTS := 20
const BARK_TEXTURE := preload("res://assets/textures/environment/trees/tree_strange_1_bark.png")

@export var outer_radius := 3.5
@export var inner_radius := 2.6
@export var height := 9.0
## Opening half-widths in radians. West (PI) is the door, east (0) the back crack.
@export var door_half_angle := 0.5
@export var crack_half_angle := 0.16


func _ready() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()
	_build()


func _is_open(angle: float) -> bool:
	var to_door := absf(wrapf(angle - PI, -PI, PI))
	var to_crack := absf(wrapf(angle, -PI, PI))
	return to_door < door_half_angle or to_crack < crack_half_angle


func _top_height(i: int) -> float:
	# Snapped top: jagged, lower on the south side.
	var jag := [0.0, -1.2, 0.6, -0.4, -2.0, 0.3, -0.8, 0.9, -1.5, 0.2]
	return height + jag[i % jag.size()] - 2.0 * (0.5 + 0.5 * sin(TAU * i / SEGMENTS))


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var body := StaticBody3D.new()
	body.name = "TrunkBody"
	body.set_meta(&"generated", true)
	add_child(body)
	var step := TAU / SEGMENTS
	for i in SEGMENTS:
		var a0 := i * step
		var a1 := a0 + step
		var mid := a0 + step * 0.5
		if _is_open(mid):
			continue
		var h0 := _top_height(i)
		var h1 := _top_height(i + 1)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		# Slight flare at the roots.
		var o0b := d0 * (outer_radius + 0.4)
		var o1b := d1 * (outer_radius + 0.4)
		var o0t := d0 * outer_radius + Vector3.UP * h0
		var o1t := d1 * outer_radius + Vector3.UP * h1
		var i0b := d0 * inner_radius
		var i1b := d1 * inner_radius
		var i0t := d0 * inner_radius + Vector3.UP * (h0 - 0.3)
		var i1t := d1 * inner_radius + Vector3.UP * (h1 - 0.3)
		var u0 := float(i) / SEGMENTS * 4.0
		var u1 := float(i + 1) / SEGMENTS * 4.0
		# Per-segment shade so the bark reads as ridges; the inside is darker.
		var shade := 0.8 + 0.2 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		st.set_color(Color(shade, shade * 0.95, shade * 0.9))
		_quad(st, o0b, o1b, o1t, o0t, u0, u1, h0 / 3.0)   # outside
		st.set_color(Color(shade * 0.55, shade * 0.5, shade * 0.45))
		_quad(st, i0b, i1b, i1t, i0t, u0, u1, h0 / 3.0)   # inside
		st.set_color(Color(shade * 0.75, shade * 0.65, shade * 0.55))
		_quad(st, o0t, o1t, i1t, i0t, u0, u1, 0.3)        # broken rim
		# Side faces where an opening starts or ends.
		if _is_open(mid - step):
			_quad(st, i0b, o0b, o0t, i0t, 0.0, 0.3, h0 / 3.0)
		if _is_open(mid + step):
			_quad(st, o1b, i1b, i1t, o1t, 0.0, 0.3, h1 / 3.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var chord := 2.0 * outer_radius * sin(step * 0.5) + 0.15
		box.size = Vector3(outer_radius - inner_radius + 0.2, minf(h0, h1), chord)
		shape.shape = box
		var centre := Vector3(cos(mid), 0, sin(mid)) * (outer_radius + inner_radius) * 0.5
		shape.transform = Transform3D(Basis(Vector3.UP, -mid), centre + Vector3.UP * minf(h0, h1) * 0.5)
		body.add_child(shape)
	st.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TrunkMesh"
	mesh_instance.set_meta(&"generated", true)
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _bark_material()
	add_child(mesh_instance)


## Opaque bark: the shared foliage bark material is alpha-scissored, which cut
## see-through holes into the trunk walls. Culling stays on since every quad
## already has both windings.
func _bark_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = BARK_TEXTURE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	return mat


## Adds a quad with both windings, so it shows from either side without a
## double-sided copy of the shared bark material.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float, v: float) -> void:
	var pts := [[a, Vector2(u0, v)], [b, Vector2(u1, v)], [c, Vector2(u1, 0)], [d, Vector2(u0, 0)]]
	for tri in [[0, 1, 2], [0, 2, 3], [0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_uv(pts[k][1])
			st.add_vertex(pts[k][0])
