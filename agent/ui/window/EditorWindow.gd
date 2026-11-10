## Native OS shell for the workspace editor. Not [CommonWindow] — stays movable outside the agent frame.
class_name EditorWindow
extends Window

const EDITOR_SCENE := preload("res://agent/app/editor/Editor.tscn")
const GROUP_NAME: StringName = &"editor_window"

var editor: PanelContainer


func _init() -> void:
	visible = false
	force_native = true
	exclusive = false
	transient = false
	min_size = AgentLayout.window_min_size
	close_requested.connect(on_close_requested)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	gdf.events.ui_scale_changed.connect(on_ui_scale_changed)
	add_to_group(GROUP_NAME)
	editor = EDITOR_SCENE.instantiate()
	editor.host_window = self
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(editor)
	apply_locale()
	pass


func on_ui_scale_changed(_scale: float) -> void:
	min_size = AgentLayout.window_min_size
	editor.configure_layout()
	editor.apply_theme()
	pass


func apply_locale() -> void:
	title = I18n.t("editor.title")
	pass


func apply_theme() -> void:
	if not visible or not OSUtils.is_windows():
		return
	NativeOS.apply_title_bar_dark_mode(get_window_id(), ThemeColor.is_dark_theme())
	pass


func on_close_requested() -> void:
	if editor != null and editor.handle_host_close_request():
		return
	commit_focus_and_free()
	pass


func commit_focus_and_free() -> void:
	var focus_owner := gui_get_focus_owner()
	if focus_owner is Control and is_ancestor_of(focus_owner):
		var focused_node: Node = focus_owner
		while focused_node != self:
			if focused_node is SpinBox:
				(focused_node as SpinBox).apply()
				break
			focused_node = focused_node.get_parent()
		(focus_owner as Control).release_focus()
	queue_free()
	pass


func present(width_percent: int = 92, height_percent: int = 88) -> void:
	var initial_size := size_from_viewport_percent(width_percent, height_percent)
	min_size = AgentLayout.window_min_size
	size = initial_size
	popup_centered()
	apply_theme()
	editor.focus_active_editor.call_deferred()
	pass


## Restores and raises this native window. `grab_focus()` alone only changes Godot's input focus
## and does not reliably bring a covered or minimized native window to the front on Windows.
func activate() -> void:
	var window_id := get_window_id()
	var mode := DisplayServer.window_get_mode(window_id)
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		var restored := DisplayServer.WINDOW_MODE_MAXIMIZED if covered_usable_screen(window_id) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(restored, window_id)
	DisplayServer.window_move_to_foreground(window_id)
	editor.focus_active_editor.call_deferred()
	pass


static func size_from_viewport_percent(width_percent: int, height_percent: int) -> Vector2i:
	var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
	return Vector2i(
		int(viewport.x * clampf(width_percent, 1.0, 100.0) / 100.0),
		int(viewport.y * clampf(height_percent, 1.0, 100.0) / 100.0),
	)


####################################################################################################
# Static methods



static func is_open() -> bool:
	return gdf.is_ready() and not gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME).is_empty()


static func show_editor() -> void:
	var existing := find_open_window()
	if existing != null:
		existing.activate()
		return
	var window := EditorWindow.new()
	gdf.gdf_node.add_child(window)
	window.present()
	pass


## Opens a supported file in the built-in editor and brings its native window to the front.
## Returns false when the path should be handled by the host OS.
static func show_file(path: String) -> bool:
	var normalized := FileUtils.normalize_path(ProjectSettings.globalize_path(path))
	if not EditorDocument.can_open(normalized):
		return false
	var window := find_open_window()
	if window == null:
		window = EditorWindow.new()
		gdf.gdf_node.add_child(window)
		window.present()
	else:
		window.activate()
	AgentEvents.events.editor_file_selected.emit(normalized)
	return true


static func find_open_window() -> EditorWindow:
	if not gdf.is_ready():
		return null
	for node: Node in gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME):
		if node is EditorWindow:
			return node as EditorWindow
	return null


static func covered_usable_screen(window_id: int) -> bool:
	var window_size := Vector2(DisplayServer.window_get_size_with_decorations(window_id))
	var screen := DisplayServer.window_get_current_screen(window_id)
	var usable_size := Vector2(DisplayServer.screen_get_usable_rect(screen).size)
	return window_size.x >= usable_size.x and window_size.y >= usable_size.y
