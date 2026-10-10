class_name SpeechPlank
extends CanvasLayer

const TYPE_SPEED := 45.0
const BLIP_EVERY := 3

var dialogue: Dialogue

var _name_label: Label
var _text_label: Label
var _hint: Label
var _voice: SoundBank
var _voice_pitch := 1.0
var _shown := 0.0
var _last_blip := 0


func _ready() -> void:
	layer = 20
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -170.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var plank := PanelContainer.new()
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color(0.36, 0.24, 0.14, 0.96)
	wood.border_color = Color(0.2, 0.12, 0.06)
	wood.set_border_width_all(4)
	wood.border_width_top = 6
	wood.set_corner_radius_all(3)
	wood.set_content_margin_all(14)
	wood.content_margin_left = 22
	wood.content_margin_right = 22
	plank.add_theme_stylebox_override("panel", wood)
	margin.add_child(plank)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	plank.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
	_name_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size.y = 52.0
	_text_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	_text_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_text_label)
	_hint = Label.new()
	_hint.text = "E ▸"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	_hint.add_theme_font_size_override("font_size", 13)
	column.add_child(_hint)


func show_line(speaker: String, text: String, voice: SoundBank, voice_pitch := 1.0) -> void:
	_name_label.text = speaker
	_name_label.visible = not speaker.is_empty()
	_text_label.text = text
	_text_label.visible_characters = 0
	_voice = voice
	_voice_pitch = voice_pitch
	_shown = 0.0
	_last_blip = -BLIP_EVERY
	_hint.modulate.a = 0.0


func is_typing() -> bool:
	return _text_label.visible_characters >= 0 \
			and _text_label.visible_characters < _text_label.text.length()


func _process(delta: float) -> void:
	if not is_typing():
		return
	_shown += delta * TYPE_SPEED
	var count := mini(int(_shown), _text_label.text.length())
	_text_label.visible_characters = count
	if _voice and count - _last_blip >= BLIP_EVERY and count < _text_label.text.length() \
			and _text_label.text[count - 1] != " ":
		_last_blip = count
		Sfx.play(_voice, 0.0, _voice_pitch)
	if not is_typing():
		_hint.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	var press := event.is_action_pressed("interact") \
			or event.is_action_pressed("grab_left") or event.is_action_pressed("grab_right")
	var release := event.is_action_released("grab_left") \
			or event.is_action_released("grab_right")
	if not (press or release):
		return
	get_viewport().set_input_as_handled()
	if not press:
		return
	if is_typing():
		_text_label.visible_characters = -1
		_hint.modulate.a = 1.0
	elif dialogue:
		dialogue.advance()
