class_name MouseGrab


static var _disabled := -1
static var _virtual_captured := false


static func is_disabled() -> bool:
	if _disabled < 0:
		_disabled = 1 if (
			Engine.get_write_movie_path() != ""
			or DisplayServer.get_name() == "headless"
			or "--no-mouse-capture" in OS.get_cmdline_user_args()
		) else 0
	return _disabled == 1


static func capture() -> void:
	if is_disabled():
		_virtual_captured = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func release() -> void:
	if is_disabled():
		_virtual_captured = false
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func is_captured() -> bool:
	if is_disabled():
		return _virtual_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
