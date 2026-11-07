## Native OS shell for the workflow editor. Keeps the workflow separate from the agent frame.
class_name WorkflowWindow
extends Window

const WORKFLOW_SCENE := preload("res://agent/app/workflow/Workflow.tscn")
const GROUP_NAME: StringName = &"workflow_window"

var workflow: PanelContainer


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
	gdf.events.ui_scale_changed.connect(on_ui_scale_changed)
	add_to_group(GROUP_NAME)
	workflow = WORKFLOW_SCENE.instantiate()
	workflow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workflow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workflow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(workflow)
	pass


func on_ui_scale_changed(scale: float) -> void:
	content_scale_factor = scale
	pass


func on_window_input(event: InputEvent) -> void:
	DisplayScale.handle_window_input(self, event)
	pass


func apply_theme() -> void:
	if not visible or not OSUtils.is_windows():
		return
	NativeOS.apply_title_bar_dark_mode(get_window_id(), ThemeColor.is_dark_theme())
	pass


func on_close_requested() -> void:
	queue_free()
	pass


func present(width_percent: int = 92, height_percent: int = 88) -> void:
	var initial_size := EditorWindow.size_from_viewport_percent(width_percent, height_percent)
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	content_scale_size = initial_size
	content_scale_factor = DisplayScale.get_ui_scale()
	size = initial_size
	popup_centered()
	apply_theme()
	pass


## Restores and raises an existing native workflow window.
func activate() -> void:
	var window_id := get_window_id()
	var mode := DisplayServer.window_get_mode(window_id)
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		var restored := DisplayServer.WINDOW_MODE_MAXIMIZED if EditorWindow.covered_usable_screen(window_id) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(restored, window_id)
	DisplayServer.window_move_to_foreground(window_id)
	pass


####################################################################################################
# Static methods


static func is_open() -> bool:
	return gdf.is_ready() and not gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME).is_empty()


static func show_workflow() -> void:
	var existing := find_open_window()
	if existing != null:
		existing.activate()
		return
	var window := WorkflowWindow.new()
	gdf.gdf_node.add_child(window)
	window.present()
	pass


static func find_open_window() -> WorkflowWindow:
	if not gdf.is_ready():
		return null
	for node: Node in gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME):
		if node is WorkflowWindow:
			return node as WorkflowWindow
	return null
