extends Node

@export_dir var items_dir := "res://resources/items"
@export_dir var output_dir := "res://assets/ui/icons/items"
@export var pixels_per_cell := 22
@export_range(1, 8) var supersample := 4
@export var camera_yaw := 45.0
@export var camera_pitch := 30.0
@export var padding := 1
@export var outline := true
@export var outline_color := Color(0.051, 0.031, 0.071, 1.0)
@export_range(0.0, 1.0) var alpha_cutoff := 0.5
@export_range(0.0, 1.0) var pose_tolerance := 0.35

const SHEET_SCALE := 4

var _only: PackedStringArray = []
var _force := false
var _assign := true
var _sheet_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--force":
			_force = true
		elif arg == "--no-assign":
			_assign = false
		elif arg.begins_with("--sheet="):
			_sheet_path = arg.trim_prefix("--sheet=")
	_bake_all.call_deferred()


func _bake_all() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Icon baker: nothing renders under --headless; run it in a window.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var baked: Dictionary[String, ItemData] = {}
	var icons: Array[Image] = []
	for file in DirAccess.get_files_at(items_dir):
		if not file.ends_with(".tres"):
			continue
		var item_name := file.get_basename()
		if not _only.is_empty() and not _only.has(item_name):
			continue
		var data := load(items_dir.path_join(file)) as ItemData
		if data == null or data.world_scene_path.is_empty():
			print("skip %s: no ItemData or no world scene" % item_name)
			continue
		var image := await _bake(data)
		if image == null:
			print("skip %s: the world scene has no meshes" % item_name)
			continue
		image.save_png(_png_path(item_name))
		print("baked %s  %dx%d" % [item_name, image.get_width(), image.get_height()])
		baked[item_name] = data
		icons.append(image)
	if not _sheet_path.is_empty() and not icons.is_empty():
		_contact_sheet(icons).save_png(_sheet_path)
	if _assign and not baked.is_empty():
		_import()
		for item_name in baked:
			_assign_icon(baked[item_name], item_name)
	get_tree().quit()


func _bake(data: ItemData) -> Image:
	for child in %Pivot.get_children():
		%Pivot.remove_child(child)
		child.free()
	var meshes := _copy_meshes(data.world_scene_path)
	if meshes.is_empty():
		return null
	for mesh in meshes:
		%Pivot.add_child(mesh)

	var view := Basis.from_euler(Vector3(deg_to_rad(-camera_pitch), deg_to_rad(camera_yaw), 0.0))
	var size := data.grid_size * pixels_per_cell
	var reserve := padding + (1 if outline else 0)
	var inner := Vector2(size - Vector2i(reserve, reserve) * 2).max(Vector2.ONE)
	var points := _points(meshes)
	var pose: Variant = _authored_pose(data.world_scene_path)
	%Pivot.basis = view * pose if pose is Basis else _choose_pose(points, view, inner)

	var lo := Vector3.INF
	var hi := -Vector3.INF
	for point in points:
		var p: Vector3 = %Pivot.basis * point
		var seen := Vector3(p.dot(view.x), p.dot(view.y), p.dot(view.z))
		lo = lo.min(seen)
		hi = hi.max(seen)
	var extent := (hi - lo).max(Vector3.ONE * 0.001)
	var pixels_per_unit := minf(inner.x / extent.x, inner.y / extent.y)
	var centre := (lo + hi) * 0.5

	%Rig.basis = view
	%Rig.position = view.x * centre.x + view.y * centre.y + view.z * (hi.z + 1.0)
	%Camera.size = size.y / pixels_per_unit
	%Camera.far = extent.z + 2.0
	%Viewport.size = size * supersample
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot: Image = %Viewport.get_texture().get_image()
	var icon := _shrink(shot, size)
	if outline:
		_outline(icon)
	return icon


func _copy_meshes(scene_path: String) -> Array[MeshInstance3D]:
	var copies: Array[MeshInstance3D] = []
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return copies
	var root := scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if source.mesh == null:
			continue
		var xform := Transform3D.IDENTITY
		var visible := true
		var at: Node = source
		while at != root:
			if at is Node3D:
				xform = (at as Node3D).transform * xform
				visible = visible and (at as Node3D).visible
			at = at.get_parent()
		if not visible:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.skin = source.skin
		copy.material_override = source.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in source.mesh.get_surface_count():
			copy.set_surface_override_material(surface, source.get_surface_override_material(surface))
		copy.transform = xform
		copies.append(copy)
	root.free()
	return copies


func _authored_pose(scene_path: String) -> Variant:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var pose: Variant = root.get_meta(&"icon_pose", null)
	root.free()
	return pose if pose is Basis else null


func _points(meshes: Array[MeshInstance3D]) -> PackedVector3Array:
	var points := PackedVector3Array()
	for mesh in meshes:
		for vertex in mesh.mesh.get_faces():
			points.append(mesh.transform * vertex)
	return points


func _choose_pose(points: PackedVector3Array, view: Basis, inner: Vector2) -> Basis:
	var poses: Array[Basis] = []
	for yaw: float in [0.0, 90.0]:
		poses.append(Basis(Vector3.UP, deg_to_rad(yaw)))
	for tilt: Basis in [Basis(Vector3.BACK, PI / 2.0), Basis(Vector3.RIGHT, PI / 2.0)]:
		for yaw: float in [0.0, 45.0, 90.0, 135.0]:
			poses.append(Basis(Vector3.UP, deg_to_rad(yaw)) * tilt)
	var fills: Array[float] = []
	var best := 0.0
	for pose in poses:
		var lo := Vector2.INF
		var hi := -Vector2.INF
		for point in points:
			var p := pose * point
			var seen := Vector2(p.dot(view.x), p.dot(view.y))
			lo = lo.min(seen)
			hi = hi.max(seen)
		var extent := (hi - lo).max(Vector2.ONE * 0.001)
		var scale := minf(inner.x / extent.x, inner.y / extent.y)
		var fill := extent.x * extent.y * scale * scale / (inner.x * inner.y)
		fills.append(fill)
		best = maxf(best, fill)
	for i in poses.size():
		if fills[i] >= best * (1.0 - pose_tolerance):
			return poses[i]
	return poses[0]


func _shrink(shot: Image, size: Vector2i) -> Image:
	var icon := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var samples := float(supersample * supersample)
	for y in size.y:
		for x in size.x:
			var colour := Color(0, 0, 0, 0)
			var cover := 0.0
			for sy in supersample:
				for sx in supersample:
					var c := shot.get_pixel(x * supersample + sx, y * supersample + sy)
					colour += Color(c.r * c.a, c.g * c.a, c.b * c.a, 0.0)
					cover += c.a
			if cover / samples < alpha_cutoff:
				continue
			icon.set_pixel(x, y, Color(colour.r / cover, colour.g / cover, colour.b / cover, 1.0))
	return icon


func _outline(icon: Image) -> void:
	var edge: Array[Vector2i] = []
	var w := icon.get_width()
	var h := icon.get_height()
	for y in h:
		for x in w:
			if icon.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + step
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and icon.get_pixelv(n).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for pixel in edge:
		icon.set_pixelv(pixel, outline_color)


func _import() -> void:
	var output := []
	var project := ProjectSettings.globalize_path("res://")
	print("importing the PNGs...")
	OS.execute(OS.get_executable_path(), ["--headless", "--path", project, "--import"], output, true)


func _assign_icon(data: ItemData, item_name: String) -> void:
	var png := _png_path(item_name)
	var texture := ResourceLoader.load(png, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if texture == null:
		push_error("Icon baker: %s was not imported; is the editor build on the path?" % png)
		return
	var current := data.icon
	var ours := current is CanvasTexture and (current as CanvasTexture).diffuse_texture != null \
			and (current as CanvasTexture).diffuse_texture.resource_path == png
	if current != null and not ours and not _force:
		print("kept the hand-made icon of %s (use --force to replace it)" % item_name)
		return
	var canvas := current as CanvasTexture if ours else CanvasTexture.new()
	canvas.diffuse_texture = texture
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data.icon = canvas
	var uid := ResourceLoader.get_resource_uid(data.resource_path)
	ResourceSaver.save(data, data.resource_path)
	_restore_uids(data.resource_path, uid)
	print("assigned %s" % png)


func _restore_uids(path: String, own_uid: int) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var ref_path := RegEx.create_from_string(" path=\"([^\"]+)\"")
	for i in lines.size():
		var line := lines[i]
		if line.contains(" uid=\""):
			continue
		if line.begins_with("[gd_resource ") and own_uid != ResourceUID.INVALID_ID:
			lines[i] = line.trim_suffix("]") + " uid=\"%s\"]" % ResourceUID.id_to_text(own_uid)
		elif line.begins_with("[ext_resource "):
			var found := ref_path.search(line)
			var ref_uid := ResourceLoader.get_resource_uid(found.get_string(1)) if found else ResourceUID.INVALID_ID
			if ref_uid != ResourceUID.INVALID_ID:
				lines[i] = line.replace(" path=", " uid=\"%s\" path=" % ResourceUID.id_to_text(ref_uid))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))


func _png_path(item_name: String) -> String:
	return output_dir.path_join(item_name + ".png")


func _contact_sheet(icons: Array[Image]) -> Image:
	var gap := 4
	var width := gap
	var height := 0
	for icon in icons:
		width += icon.get_width() + gap
		height = maxi(height, icon.get_height())
	var sheet := Image.create_empty(width, height + gap * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.12, 0.2))
	var x := gap
	for icon in icons:
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(x, gap + height - icon.get_height()))
		x += icon.get_width() + gap
	sheet.resize(sheet.get_width() * SHEET_SCALE, sheet.get_height() * SHEET_SCALE, Image.INTERPOLATE_NEAREST)
	return sheet
