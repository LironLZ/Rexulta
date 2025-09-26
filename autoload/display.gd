extends Node

var _prev_size: Vector2i = Vector2i(960, 540)
var _prev_pos: Vector2i = Vector2i(100, 100)

func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func toggle_fullscreen() -> void:
	if is_fullscreen():
		# restore previous windowed size/pos
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(_prev_size)
		DisplayServer.window_set_position(_prev_pos)
	else:
		# cache current windowed size/pos, then go fullscreen
		_prev_size = DisplayServer.window_get_size()
		_prev_pos  = DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_window_size(new_size: Vector2i) -> void:
	if new_size.x <= 0 or new_size.y <= 0:
		return
	var was_fullscreen := is_fullscreen()
	if was_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(new_size)
	_prev_size = new_size
	if !was_fullscreen:
		_prev_pos = DisplayServer.window_get_position()
