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
	min_size = Vector2i(720, 480)
	close_requested.connect(on_close_requested)
	window_input.connect(on_window_input)
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


func on_ui_scale_changed(scale: float) -> void:
	content_scale_factor = scale
	pass


func on_window_input(event: InputEvent) -> void:
	DisplayScale.handle_window_input(self, event)
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
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	content_scale_size = initial_size
	content_scale_factor = DisplayScale.get_ui_scale()
	size = initial_size
	popup_centered()
	apply_theme()
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
	if is_open():
		for node: Node in gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME):
			if node is EditorWindow:
				(node as EditorWindow).grab_focus()
		return
	var window := EditorWindow.new()
	gdf.gdf_node.add_child(window)
	window.present()
	pass
