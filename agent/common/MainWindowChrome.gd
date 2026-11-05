class_name MainWindowChrome
extends Object

## Main-window title bar (Windows DWM) and deferred title / borderless chrome.

const DEFAULT_APP_TITLE := "GAI"


## Boot starts borderless (see project.godot) so the splash phase has no title bar.
## Windows: DWM title bar matches [ThemeColor]. All platforms: title + [code]borderless = false[/code] (deferred).
## [param title] empty → [code]application/config/name[/code] from project settings, then [constant DEFAULT_APP_TITLE].
static func apply_main_window_chrome(window: Window, title: String = "") -> void:
	var window_title := title
	if window_title.is_empty():
		window_title = str(ProjectSettings.get_setting("application/config/name", DEFAULT_APP_TITLE))
	if OSUtils.is_windows():
		NativeOS.apply_title_bar_dark_mode(DisplayServer.MAIN_WINDOW_ID, ThemeColor.is_dark_theme())
	gdf.callable_deferred(apply_standard_window.bind(window, window_title))
	pass


static func apply_standard_window(window: Window, title: String, window_id: int = DisplayServer.MAIN_WINDOW_ID) -> void:
	DisplayServer.window_set_title(title, window_id)
	window.borderless = false
	pass
