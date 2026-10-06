class_name MouseGrab
## The one place the game captures or frees the mouse.
##
## Automated runs — Movie Maker recordings, headless runs, or anything started with
## `-- --no-mouse-capture` — must never take the OS cursor away from whoever is using
## the desktop. In that mode the capture is only pretended: the state is tracked here
## so the player still counts as "in control" and scripted input keeps driving it.


static var _disabled := -1
static var _virtual_captured := false


## True when the real cursor must be left alone.
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
