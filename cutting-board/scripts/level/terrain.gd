@tool
class_name Terrain
extends StaticBody3D

## Ground for a level, generated from noise when the level loads (and in the editor):
## open meadow in the middle that rises into hills towards the edges. The mesh and its
## collision come from the same height grid, one vertex per metre.
##
## Places that need level ground — a village, a camp — are listed as flat areas and kept
## at height 0, so buildings can be placed at y = 0 and sit flush. Paths and gravel
## squares are painted into the vertex colours for the terrain shader to texture.
##
## Anything in the snap group (trees, rocks on the hills) is moved onto the ground after
## each build, so scattered props only need their x and z placed by hand.

const SNAP_GROUP := &"terrain_snap"

## Edge length of the square terrain in metres; it is centred on this node.
@export var size := 200
## Height the hills reach at the very edge of the terrain.
@export var hill_height := 18.0
## Distance from the centre, along either axis, where the hills start to rise.
@export var hills_start := 55.0
## Height of the gentle bumps across the meadow.
@export var bump_height := 1.2
@export var noise: FastNoiseLite
## Areas kept perfectly flat at height 0, as (x, z, radius) in local metres.
@export var flat_areas: Array[Vector3] = []
## Metres over which a flat area blends back into the surrounding ground.
@export var flat_blend := 14.0
## Dirt paths, each a polyline of (x, z) points in local metres.
@export var paths: Array[PackedVector2Array] = []
@export var path_width := 3.0
## Gravel-covered areas such as a village square, as (x, z, radius) in local metres.
@export var gravel_areas: Array[Vector3] = []
@export var material: Material
## How far snapped props are pushed into the ground, so roots and rock bases do not float
## on slopes.
@export var snap_sink := 0.3
@export_tool_button("Rebuild") var rebuild_action := build

var _heights := PackedFloat32Array()
var _resolution := 0

@onready var _mesh_instance: MeshInstance3D = %TerrainMesh
@onready var _collision: CollisionShape3D = %TerrainCollision


func _ready() -> void:
	build()


## Regenerates the height grid, mesh and collision, then settles snapped props.
func build() -> void:
	if not is_node_ready():
		return
	_resolution = size + 1
	_build_heights()
	_mesh_instance.mesh = _build_mesh()
	_mesh_instance.material_override = material
	var shape := HeightMapShape3D.new()
	shape.map_width = _resolution
	shape.map_depth = _resolution
	shape.map_data = _heights
	_collision.shape = shape
	_snap_props()


## Ground height at a local (x, z), interpolated between grid points.
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var half := size * 0.5
	var gx := clampf(x + half, 0.0, size - 0.001)
	var gz := clampf(z + half, 0.0, size - 0.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var h00 := _heights[iz * _resolution + ix]
	var h10 := _heights[iz * _resolution + ix + 1]
	var h01 := _heights[(iz + 1) * _resolution + ix]
	var h11 := _heights[(iz + 1) * _resolution + ix + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func _build_heights() -> void:
	_heights.resize(_resolution * _resolution)
	var half := size * 0.5
	for iz in _resolution:
		for ix in _resolution:
			_heights[iz * _resolution + ix] = _height_from_noise(ix - half, iz - half)


func _height_from_noise(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) if noise else 0.0
	var half := size * 0.5
	var edge := maxf(absf(x), absf(z))
	var rise := smoothstep(hills_start, half, edge)
	var height := rise * rise * hill_height * (0.75 + 0.5 * n) + n * bump_height
	return height * (1.0 - _flatness(x, z))


## 1 inside a flat area, falling to 0 over the blend distance around it.
func _flatness(x: float, z: float) -> float:
	var flat := 0.0
	for area in flat_areas:
		var distance := Vector2(x - area.x, z - area.y).length()
		flat = maxf(flat, 1.0 - smoothstep(area.z, area.z + flat_blend, distance))
	return flat


func _build_mesh() -> ArrayMesh:
	var half := size * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(_resolution * _resolution)
	normals.resize(vertices.size())
	colors.resize(vertices.size())
	for iz in _resolution:
		for ix in _resolution:
			var i := iz * _resolution + ix
			var x := ix - half
			var z := iz - half
			vertices[i] = Vector3(x, _heights[i], z)
			# Central differences over the grid, clamped at the border.
			var dx := _grid_height(ix + 1, iz) - _grid_height(ix - 1, iz)
			var dz := _grid_height(ix, iz + 1) - _grid_height(ix, iz - 1)
			normals[i] = Vector3(-dx, 2.0, -dz).normalized()
			colors[i] = Color(_path_coverage(x, z), _gravel_coverage(x, z), 0.0)
	for iz in size:
		for ix in size:
			var a := iz * _resolution + ix
			var b := a + 1
			var c := a + _resolution
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _grid_height(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, size)
	iz = clampi(iz, 0, size)
	return _heights[iz * _resolution + ix]


## How much a point is covered by a path: 1 on the centre line, 0 past its edge.
func _path_coverage(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var nearest := INF
	for path in paths:
		for i in path.size() - 1:
			var on_segment := Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])
			nearest = minf(nearest, point.distance_to(on_segment))
	return 1.0 - smoothstep(path_width * 0.3, path_width * 0.6, nearest)


func _gravel_coverage(x: float, z: float) -> float:
	var coverage := 0.0
	for area in gravel_areas:
		var distance := Vector2(x - area.x, z - area.y).length()
		coverage = maxf(coverage, 1.0 - smoothstep(area.z - 1.5, area.z + 1.5, distance))
	return coverage


func _snap_props() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(SNAP_GROUP):
		if node is Node3D:
			var local := to_local(node.global_position)
			local.y = height_at(local.x, local.z) - snap_sink
			node.global_position = to_global(local)
