class_name PauseMenu
extends Node3D
## The pause menu is the player's mask. Esc pulls it straight off the face toward the
## camera with its inside already facing the player, and the options are carved into
## that inside: Resume, Save, Load, Settings and Quit. Choosing one carves a groove
## across the word with a spray of chips; Resume (or Esc) puts the mask back on.
##
## While the mask is off the world behind it turns to the bare-face look of
## MaskOffVision (black with flowing grain), drawn on a sheet just behind the mask so the
## mask itself still shows. Lives under the player's camera and keeps running while the
## tree is paused.

## Fixed carve order for Tab, and the index of each word in WORDS.
enum Word { RESUME, SAVE, LOAD, SETTINGS, QUIT }

## Mask 1 (knotted brow) from the concept, in its 256x320 canvas pixels:
## [text, x, y, tilt in radians, size].
const WORDS := [
	["Resume", 128.0, 168.0, -0.10, 34.0],
	["Save", 78.0, 214.0, -0.30, 24.0],
	["Load", 176.0, 218.0, 0.26, 24.0],
	["Settings", 126.0, 262.0, 0.12, 21.0],
	["Quit", 154.0, 58.0, -0.18, 22.0],
]
const CANVAS := Vector2(256, 320)
## Eye holes: centre x, y, radius x, y, tilt.
const EYES := [[88.0, 112.0, 24.0, 13.0, 0.12], [170.0, 106.0, 22.0, 14.0, -0.08]]
const KNOT := Vector2(66, 62)
const CRACK := [Vector2(150, 30), Vector2(146, 80), Vector2(154, 140), Vector2(148, 200), Vector2(156, 260)]

## Size of the mask in metres, and how deep its inside is cupped.
const SIZE := Vector2(0.2, 0.25)
const CUP := 2.4
## Where the mask sits on the face, and where it is held up to read.
const FACE_POS := Vector3(0, 0, -0.02)
const HELD_POS := Vector3(0, -0.03, -0.28)
const HELD_TILT := -0.08
const LIFT_TIME := 0.6
const CARVE_TIME := 0.4
## How long the carved "not yet" note stays on the mask.
const NOTE_TIME := 1.6

const WOOD := Color(0.62, 0.43, 0.25)
const WOOD_DARK := Color(0.36, 0.22, 0.11)
const GROOVE := Color(0.18, 0.09, 0.04)
const LIP := Color(0.93, 0.8, 0.6)
const CANDLE := Color(1.0, 0.68, 0.36)
## How far in front of the camera the grain backdrop hangs: behind the held mask and its
## shell, in front of the world.
const BACKDROP_DEPTH := 0.34
const BACKDROP_SHADER := preload("res://assets/shaders/post/mask_off_backdrop.gdshader")

signal opened
signal closed

## The player's bare-face view. It hides while paused, so the backdrop takes over from
## it: already full when the face was bare, and carrying on its grain's time.
@export var vision: MaskOffVision

## What the second Quit carve does. Swapped out by tests so they don't end the run.
var quit_handler: Callable = func() -> void: get_tree().quit()

## 0 while the mask is on the face, 1 while it is held up to read.
var _lift := 0.0
var _lift_dir := 0
var _selected := Word.RESUME
var _quit_carves := 0
## The carve in flight: which word, and how far along (-1 when idle).
var _carving := -1
var _carve_t := -1.0
var _note_t := 0.0
var _flicker_t := 0.0
var _mask: Node3D
var _words: Array[Node3D] = []
var _grooves: Array[Node3D] = []
var _glow: OmniLight3D
var _chips: CPUParticles3D
var _note: Node3D
var _backdrop: MeshInstance3D
## Bare-face amount the backdrop starts from (1 when no mask was on), and the grain's time.
var _backdrop_floor := 0.0
var _grain_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_lift()


## True from the moment the mask starts coming off until it is back on the face.
func is_open() -> bool:
	return _lift > 0.0 or _lift_dir > 0


func selected() -> int:
	return _selected


func open() -> void:
	if is_open():
		return
	get_tree().paused = true
	MouseGrab.release()
	_quit_carves = 0
	_select(Word.RESUME)
	_lift_dir = 1
	_mask.show()
	if vision != null:
		_backdrop_floor = vision.amount
		_grain_time = vision.grain_time
	_apply_backdrop()
	opened.emit()


## Starts putting the mask back on; the game unpauses once it sits on the face again.
func close() -> void:
	if not is_open() or _lift_dir < 0:
		return
	_lift_dir = -1
	_carving = -1
	_carve_t = -1.0


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		# Panels that use Esc themselves handle it first and mark it handled, so this
		# only fires when nothing else is open.
		if event.is_action_pressed("pause") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if _lift_dir < 0:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_focus_next"):
		select_next()
	elif event.is_action_pressed("ui_up"):
		select_toward(Vector2.UP)
	elif event.is_action_pressed("ui_down"):
		select_toward(Vector2.DOWN)
	elif event.is_action_pressed("ui_left"):
		select_toward(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"):
		select_toward(Vector2.RIGHT)
	elif event.is_action_pressed("ui_accept"):
		activate()
	elif event is InputEventMouseMotion:
		var hit := _word_at(event.position)
		if hit >= 0:
			_select(hit)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _word_at(event.position)
		if hit >= 0:
			_select(hit)
			activate()


## Tab walks the fixed order Resume, Save, Load, Settings, Quit.
func select_next() -> void:
	if _carving < 0:
		_select((_selected + 1) % WORDS.size())


## Arrows jump to the nearest word that lies in that direction on the mask.
func select_toward(dir: Vector2) -> void:
	if _carving >= 0:
		return
	var from := _canvas_pos(_selected)
	var best := -1
	var best_score := INF
	for i in WORDS.size():
		if i == _selected:
			continue
		var d := _canvas_pos(i) - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		# Sideways distance counts double, so "down" prefers what is straight below.
		var score := along + absf(d.cross(dir)) * 2.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_select(best)


## Carves the selected word. The outcome follows once the groove is through.
func activate() -> void:
	if _carving >= 0 or _lift < 1.0:
		return
	_carving = _selected
	_carve_t = 0.0
	var groove := _grooves[_carving]
	groove.show()
	groove.scale.x = 0.001
	_chips.global_position = _word_start(_carving)
	_chips.restart()


func _process(delta: float) -> void:
	if _lift_dir != 0:
		_lift = clampf(_lift + _lift_dir * delta / LIFT_TIME, 0.0, 1.0)
		_apply_lift()
		if _lift_dir > 0 and _lift >= 1.0:
			_lift_dir = 0
		elif _lift_dir < 0 and _lift <= 0.0:
			_lift_dir = 0
			_put_on()
	if _carve_t >= 0.0:
		_carve_t = minf(_carve_t + delta / CARVE_TIME, 1.0)
		var groove := _grooves[_carving]
		groove.scale.x = maxf(_carve_t, 0.001)
		_chips.global_position = _word_start(_carving).lerp(_word_end(_carving), _carve_t)
		if _carve_t >= 1.0:
			_carve_t = -1.0
			_chips.emitting = false
			var word := _carving
			_carving = -1
			_carved(word)
	if _note_t > 0.0:
		_note_t -= delta
		_note.visible = _note_t > 0.0
	if is_open():
		_grain_time += delta
		_apply_backdrop()
	# The candle over the selected word never burns quite still.
	_flicker_t += delta
	_glow.light_energy = 0.55 + 0.12 * sin(_flicker_t * 13.0) + 0.08 * sin(_flicker_t * 31.0 + 1.3)


func _carved(word: int) -> void:
	match word:
		Word.RESUME:
			close()
		Word.QUIT:
			_quit_carves += 1
			if _quit_carves >= 2:
				quit_handler.call()
			else:
				_show_note("again to quit", word)
		_:
			_show_note("not yet", word)
			# Only Quit keeps its groove, as the count toward the second carve.
			_grooves[word].hide()


func _put_on() -> void:
	_mask.hide()
	for groove in _grooves:
		groove.hide()
	_note.hide()
	_note_t = 0.0
	_backdrop.hide()
	if vision != null:
		vision.grain_time = _grain_time
	get_tree().paused = false
	MouseGrab.capture()
	closed.emit()


func _select(word: int) -> void:
	_selected = word as Word
	for i in _words.size():
		var groove_label: Label3D = _words[i].get_child(1)
		groove_label.modulate = GROOVE.lerp(CANDLE, 0.55) if i == word else GROOVE
	_glow.position = _surface(_canvas_pos(word)) + Vector3(0, 0, 0.05)


func _show_note(text: String, word: int) -> void:
	for label: Label3D in _note.get_children():
		label.text = text
	var at := _canvas_pos(word) + Vector2(0, 22)
	_note.position = _flat_over(word, at) + Vector3(0, 0, 0.002)
	_note.show()
	_note_t = NOTE_TIME


# --- Pose --------------------------------------------------------------------------

## Straight off the face along the view axis, a little down, settling a few degrees.
func _apply_lift() -> void:
	var t := _lift * _lift * (3.0 - 2.0 * _lift)
	_mask.position = FACE_POS.lerp(HELD_POS, t)
	_mask.rotation = Vector3(HELD_TILT * t, 0, 0.03 * (1.0 - t))
	_mask.visible = _lift > 0.0


## How far the world behind the mask has gone to black and grain: follows the mask off
## and back on, never below what the bare face already showed.
func backdrop_amount() -> float:
	return maxf(_lift, _backdrop_floor) if _backdrop.visible else 0.0


func _apply_backdrop() -> void:
	var amount := maxf(_lift, _backdrop_floor)
	_backdrop.visible = is_open() and amount > 0.0
	var material := _backdrop.material_override as ShaderMaterial
	material.set_shader_parameter("fade", amount)
	material.set_shader_parameter("time", _grain_time)


# --- Picking -----------------------------------------------------------------------

func _word_at(screen: Vector2) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -1
	var best := -1
	var best_d := INF
	for i in WORDS.size():
		var a := camera.unproject_position(_word_start(i))
		var b := camera.unproject_position(_word_end(i))
		var d := Geometry2D.get_closest_point_to_segment(screen, a, b).distance_to(screen)
		# Half the word height on screen, plus a little slack, counts as a hit.
		var reach := a.distance_to(b) / float(String(WORDS[i][0]).length()) * 0.9 + 6.0
		if d < reach and d < best_d:
			best_d = d
			best = i
	return best


func _canvas_pos(word: int) -> Vector2:
	return Vector2(WORDS[word][1], WORDS[word][2])


func _word_half_width(word: int) -> float:
	return String(WORDS[word][0]).length() * WORDS[word][4] * 0.29


func _word_start(word: int) -> Vector3:
	var dir := Vector2.from_angle(WORDS[word][3])
	return _mask.to_global(_surface(_canvas_pos(word) - dir * _word_half_width(word)))


func _word_end(word: int) -> Vector3:
	var dir := Vector2.from_angle(WORDS[word][3])
	return _mask.to_global(_surface(_canvas_pos(word) + dir * _word_half_width(word)))


## Where a flat label or groove for a word goes: at `px`, raised to the highest point of
## the cupped surface under the word, so the curve never swallows its ends.
func _flat_over(word: int, px: Vector2) -> Vector3:
	var dir := Vector2.from_angle(WORDS[word][3]) * _word_half_width(word)
	var c := _canvas_pos(word)
	var top := maxf(_surface(c - dir).z, maxf(_surface(c + dir).z, _surface(c).z))
	var p := _surface(px)
	return Vector3(p.x, p.y, top + 0.001)


## A canvas pixel on the inside surface of the mask, in mask space.
func _surface(px: Vector2) -> Vector3:
	var x := (px.x / CANVAS.x - 0.5) * SIZE.x
	var y := (0.5 - px.y / CANVAS.y) * SIZE.y
	return Vector3(x, y, CUP * (x * x + y * y * 0.3))


# --- Building ----------------------------------------------------------------------

func _build() -> void:
	_mask = Node3D.new()
	_mask.name = "Mask"
	add_child(_mask)
	var outline := _outline()
	var inside := _paint_inside(outline)
	_mask.add_child(_cupped_plane(inside, Color.WHITE, 0.0, 1.0))
	# The outer shell: the same cut, a shade darker and a hair bigger, just behind.
	_mask.add_child(_cupped_plane(inside, Color(0.45, 0.32, 0.22), -0.004, 1.03))

	# A warm candle key light below the mask so the carving reads.
	var key := OmniLight3D.new()
	key.light_color = CANDLE
	key.light_energy = 0.8
	key.omni_range = 0.6
	key.position = Vector3(0, -0.16, 0.12)
	_mask.add_child(key)
	_glow = OmniLight3D.new()
	_glow.light_color = CANDLE
	_glow.omni_range = 0.12
	_mask.add_child(_glow)

	for i in WORDS.size():
		var word := _carved_label(WORDS[i][0], WORDS[i][4] * 1.9)
		word.position = _flat_over(i, _canvas_pos(i))
		word.rotation.z = -WORDS[i][3]
		_mask.add_child(word)
		_words.append(word)
		var groove := Node3D.new()
		var cut := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(_word_half_width(i) * 2.0 / CANVAS.x * SIZE.x, 0.0018, 0.0005)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = GROOVE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material = mat
		# The pivot sits at the word's start, so scaling it in x draws the cut from left to right.
		cut.position.x = bar.size.x * 0.5
		cut.mesh = bar
		groove.add_child(cut)
		var start := _canvas_pos(i) - Vector2.from_angle(WORDS[i][3]) * _word_half_width(i)
		groove.position = _flat_over(i, start) + Vector3(0, 0, 0.002)
		groove.rotation.z = -WORDS[i][3]
		groove.hide()
		_mask.add_child(groove)
		_grooves.append(groove)

	_note = _carved_label("not yet", 30.0)
	_note.hide()
	_mask.add_child(_note)
	_chips = _make_chips()
	add_child(_chips)
	_backdrop = _make_backdrop()
	add_child(_backdrop)
	_select(Word.RESUME)


## Two labels for a two-tone carving: a pale lip offset down-right, the dark groove on top.
func _carved_label(text: String, font_size: float) -> Node3D:
	var root := Node3D.new()
	for tone in [LIP, GROOVE]:
		var label := Label3D.new()
		label.text = text
		label.font_size = int(font_size)
		label.pixel_size = 0.0004
		label.modulate = tone
		label.outline_size = 0
		label.double_sided = false
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		if tone == LIP:
			label.position = Vector3(0.0005, -0.0006, 0)
		else:
			label.position = Vector3(0, 0, 0.0004)
		root.add_child(label)
	return root


func _make_chips() -> CPUParticles3D:
	var chips := CPUParticles3D.new()
	chips.emitting = false
	chips.one_shot = false
	chips.amount = 24
	chips.lifetime = 0.45
	chips.explosiveness = 0.0
	chips.direction = Vector3(0, 0.6, 1)
	chips.spread = 55.0
	chips.initial_velocity_min = 0.15
	chips.initial_velocity_max = 0.35
	chips.gravity = Vector3(0, -1.2, 0)
	var chip := BoxMesh.new()
	chip.size = Vector3(0.004, 0.002, 0.001)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LIP
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chip.material = mat
	chips.mesh = chip
	chips.local_coords = false
	return chips


## A sheet across the whole view, depth-tested so the mask in front of it still draws.
func _make_backdrop() -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.name = "GrainBackdrop"
	var quad := QuadMesh.new()
	# Far wider than any field of view at this depth; the shader works in screen pixels.
	quad.size = Vector2(4.0, 4.0)
	sheet.mesh = quad
	sheet.position = Vector3(0, 0, -BACKDROP_DEPTH)
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.hide()
	return sheet


## The concept's outline of mask 1 (knotted brow, chipped right cheek) as a polygon.
func _outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cur := Vector2(128, 18)
	pts.append(cur)
	var segs := [
		["c", Vector2(70, 14), Vector2(40, 40), Vector2(42, 72)],
		["c", Vector2(22, 80), Vector2(20, 120), Vector2(36, 150)],
		["c", Vector2(30, 220), Vector2(62, 290), Vector2(128, 304)],
		["c", Vector2(182, 296), Vector2(214, 250), Vector2(212, 210)],
		["l", Vector2(226, 196)],
		["l", Vector2(214, 182)],
		["l", Vector2(228, 166)],
		["c", Vector2(238, 90), Vector2(212, 20), Vector2(128, 18)],
	]
	for seg in segs:
		if seg[0] == "l":
			cur = seg[1]
			pts.append(cur)
			continue
		for k in range(1, 9):
			pts.append(cur.bezier_interpolate(seg[1], seg[2], seg[3], k / 8.0))
		cur = seg[3]
	return pts


func _paint_inside(outline: PackedVector2Array) -> ImageTexture:
	var w := int(CANVAS.x) / 2
	var h := int(CANVAS.y) / 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2(x * 2 + 1, y * 2 + 1)
			if not Geometry2D.is_point_in_polygon(p, outline) or _in_eye(p):
				continue
			# Wavy grain lines that swirl around the knot on the brow.
			var bulge := maxf(0.0, 22.0 - p.distance_to(KNOT)) * 0.7
			var grain := sin((p.y + sin(p.x * 0.04 + p.y * 0.11) * 3.0 + bulge) * 0.4)
			var c := WOOD.lerp(WOOD_DARK, 0.18 + 0.14 * grain)
			var k := p.distance_to(KNOT)
			if k < 12.0:
				c = WOOD_DARK
			elif k < 17.0:
				c = c.lerp(WOOD_DARK, 0.5)
			if _crack_distance(p) < 1.6:
				c = GROOVE
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _in_eye(p: Vector2) -> bool:
	for eye in EYES:
		var d := (p - Vector2(eye[0], eye[1])).rotated(-eye[4])
		if pow(d.x / eye[2], 2) + pow(d.y / eye[3], 2) < 1.0:
			return true
	return false


func _crack_distance(p: Vector2) -> float:
	var best := INF
	for i in CRACK.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, CRACK[i], CRACK[i + 1]).distance_to(p))
	return best


## A low-poly grid bent into a cup, with the painted inside alpha-cut to the mask shape.
func _cupped_plane(tex: Texture2D, tint: Color, z_off: float, grow: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 8
	var rows := 10
	for r in rows:
		for c in cols:
			var quad := [Vector2(c, r), Vector2(c + 1, r), Vector2(c + 1, r + 1), Vector2(c, r), Vector2(c + 1, r + 1), Vector2(c, r + 1)]
			for q in quad:
				var uv := Vector2(q.x / cols, q.y / rows)
				var v := _surface(uv * CANVAS)
				st.set_uv(Vector2(0.5, 0.5) + (uv - Vector2(0.5, 0.5)) / grow)
				st.add_vertex(Vector3(v.x, v.y, v.z + z_off))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
