## Markdown note window. Editing and preview live in [CommonEditor]; this window loads the note,
## saves it on close, and keeps the open-on-startup preference.
##
## Window-level controls stay in the window: a toolbar band under the title band holds them, so the
## editor is never asked to host controls that are not about the document.
class_name NoteWindow
extends CommonWindow

var editor: CommonEditor
## Band directly below the title band; same construct as [member GitDiffViewer.toolbar_panel].
var toolbar_panel: PanelContainer
var toolbar: HBoxContainer
var open_on_startup_check: CheckButton


func _init() -> void:
	super()
	gdf.events.locale_changed.connect(apply_locale)
	build_layout()
	apply_theme()
	apply_locale()
	editor.set_split_ratio(NoteSetting.get_split_ratio())
	editor.set_view_mode(NoteSetting.get_view_mode())
	editor.view_mode_changed.connect(on_view_mode_changed)
	editor.split_ratio_changed.connect(on_split_ratio_changed)
	pass


func build_layout() -> void:
	# Keep the title band's bottom hairline visible; the toolbar starts directly below it.
	container.offset_top = 0
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	container.add_child(root)

	toolbar_panel = PanelContainer.new()
	toolbar_panel.custom_minimum_size.y = ControlSize.md
	root.add_child(toolbar_panel)
	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = ControlSize.md
	toolbar.add_theme_constant_override("separation", Margin.ma_2)
	toolbar_panel.add_child(toolbar)

	open_on_startup_check = CheckButton.new()
	open_on_startup_check.focus_mode = Control.FOCUS_NONE
	open_on_startup_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_on_startup_check.button_pressed = NoteSetting.get_open_on_startup()
	open_on_startup_check.toggled.connect(on_open_on_startup_toggled)
	toolbar.add_child(open_on_startup_check)

	editor = CommonEditor.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editor)
	editor.set_suffix("md")
	pass


func apply_locale() -> void:
	title = I18n.t("note.title")
	editor.placeholder_text = I18n.t("note.placeholder")
	open_on_startup_check.text = I18n.t("note.open_on_startup")
	open_on_startup_check.tooltip_text = I18n.t("note.open_on_startup_hint")
	pass


func apply_theme() -> void:
	super()
	container.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.chrome_surface))
	# Same band as the git diff toolbar: chrome fill, no border, the editor below carries the content surface.
	toolbar_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.chrome_surface, 0, Margin.ma_3, Margin.ma_0))
	style_open_on_startup()
	pass


func window_background_color() -> Color:
	return Colors.deep_surface


func window_title_color() -> Color:
	return Colors.primary_text


func window_border_color() -> Color:
	return Colors.primary_text


func style_open_on_startup() -> void:
	open_on_startup_check.add_theme_font_override("font", Fonts.regular())
	open_on_startup_check.add_theme_font_size_override("font_size", Typography.label_medium)
	CheckButtonStyle.apply(open_on_startup_check)
	pass


func on_view_mode_changed(mode: CommonEditor.ViewMode) -> void:
	NoteSetting.set_view_mode(mode)
	pass


func on_split_ratio_changed(ratio: float) -> void:
	NoteSetting.set_split_ratio(ratio)
	pass


func on_open_on_startup_toggled(enabled: bool) -> void:
	NoteSetting.set_open_on_startup(enabled)
	pass


## Open a centered note editor. Width/height are percent of the screen (1–100).
static func show_note(width_percent: int = 60, height_percent: int = 80) -> void:
	close_open_notes()
	var window := NoteWindow.new()
	gdf.gdf_node.add_child(window)
	window.editor.text = NoteSetting.get_note()
	window.present_centered(width_percent, height_percent)
	pass


func present_centered(width_percent: int = 70, height_percent: int = 80) -> void:
	super(width_percent, height_percent)
	editor.reset_split.call_deferred()
	editor.focus_editor()
	pass


func on_close_requested() -> void:
	super()
	var content := editor.text
	if NoteSetting.set_note(content) != OK:
		Alert.alert(I18n.t("note.save_failed"), Colors.error)
	pass


static func close_open_notes() -> void:
	var open: Array[NoteWindow] = []
	for child in gdf.gdf_node.get_children():
		if child is NoteWindow:
			open.push_back(child)
	for window in open:
		window.on_close_requested()
	pass
