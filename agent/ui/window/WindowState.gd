class_name WindowState
extends RefCounted

const FILE_PATH := "user://window_state.json"


class State extends RefCounted:
	var screen: int = 0
	var mode: int = Window.MODE_WINDOWED
	var position_x: int = 0
	var position_y: int = 0
	var width: int = 1152
	var height: int = 648


var window: Window
var state := State.new()


func setup(target: Window) -> void:
	if Engine.is_embedded_in_editor():
		return
	window = target
	gdf.callable_deferred(finish_setup)
	pass


func finish_setup() -> void:
	restore()
	window.size_changed.connect(on_window_changed)
	window.nonclient_window_input.connect(on_window_input)
	gdf.events.application_exit.connect(on_application_exit)
	pass


func capture() -> bool:
	if window == null:
		return false
	if window.mode == Window.MODE_MINIMIZED:
		return false
	var changed := state.screen != window.current_screen or state.mode != window.mode
	state.screen = window.current_screen
	state.mode = window.mode
	if window.mode == Window.MODE_WINDOWED:
		var position := window.position
		var size := window.size
		changed = changed or state.position_x != position.x or state.position_y != position.y
		changed = changed or state.width != size.x or state.height != size.y
		state.position_x = position.x
		state.position_y = position.y
		state.width = size.x
		state.height = size.y
	return changed


func on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		on_window_changed()
	pass


func on_window_changed() -> void:
	if not capture() or RateLimitUtils.limit_second_1():
		return
	SchedulerBus.schedule(save, TimeUtils.MILLIS_PER_SECOND)
	pass


func on_application_exit() -> void:
	capture()
	save()
	pass


func restore() -> void:
	if window == null or not FileAccess.file_exists(FILE_PATH):
		return
	var restored: Variant = JsonUtils.json_to_object(FileUtils.read_file_to_string(FILE_PATH), State)
	if restored is not State:
		return
	state = restored as State
	state.screen = clampi(state.screen, 0, DisplayServer.get_screen_count() - 1)
	window.mode = Window.MODE_WINDOWED
	window.current_screen = state.screen
	if state.mode == Window.MODE_MAXIMIZED or state.mode == Window.MODE_FULLSCREEN:
		window.mode = state.mode as Window.Mode
	else:
		window.size = Vector2i(state.width, state.height)
		window.position = Vector2i(state.position_x, state.position_y)
	pass


func save() -> void:
	if window == null:
		return
	var error := FileUtils.write_string_to_file(FILE_PATH, JsonUtils.object_to_json(state))
	if error != OK:
		Log.error("window state save failed path:[{}] err:[{}]", FILE_PATH, error)
	pass
