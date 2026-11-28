class_name WindowState
extends RefCounted

## Saved window geometry belongs to this machine (its monitors), so it lives in the data folder
## shared by every workspace ([method Workspace.get_shared_data_dir]) — switching project must not
## move the window, and the folder is not Steam Cloud synced where another machine would read it.
const FILE_NAME := "window_state.gai"


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
	await ensure_on_screen()
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


## Saved geometry belongs to the monitors of that session: with the second screen gone, a window
## saved on it would be restored outside every monitor - created, but unreachable. The saved screen
## index is clamped into the screens that exist and the saved corner into its usable area.
func restore() -> void:
	var path := Workspace.get_shared_data_dir(FILE_NAME)
	if window == null or not FileAccess.file_exists(path):
		return
	var restored: Variant = JsonUtils.json_to_object(FileUtils.read_file_to_string(path), State)
	if restored is not State:
		return
	state = restored as State
	state.screen = clampi(state.screen, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	window.mode = Window.MODE_WINDOWED
	window.current_screen = state.screen
	if state.mode == Window.MODE_MAXIMIZED or state.mode == Window.MODE_FULLSCREEN:
		window.mode = state.mode as Window.Mode
	else:
		window.size = Vector2i(state.width, state.height)
		var position := Vector2i(state.position_x, state.position_y)
		window.position = ScreenUtils.clamp_rect_to_usable(position, window.size, 0, state.screen)
	pass


## The restore is only a request — a scaled desktop or a grown minimum content size can still leave the
## window outside its screen. One frame later, read the geometry actually applied and pull it back in.
func ensure_on_screen() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	if window.mode != Window.MODE_WINDOWED:
		return
	var usable := ScreenUtils.usable_rect(window.current_screen)
	if not usable.has_area() or usable.encloses(Rect2i(window.position, window.size)):
		return
	var size := Vector2i(mini(window.size.x, usable.size.x), mini(window.size.y, usable.size.y))
	window.size = size
	window.position = ScreenUtils.clamp_rect_to_usable(window.position, size, 0, window.current_screen)
	pass


func save() -> void:
	if window == null:
		return
	var path := Workspace.get_shared_data_dir(FILE_NAME)
	var error := FileUtils.write_string_to_file(path, JsonUtils.object_to_json(state))
	if error != OK:
		Log.error("window state save failed path:[{}] err:[{}]", path, error)
	pass
