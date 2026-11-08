## Markdown note window. Editing and preview live in [CommonEditor]; this window loads the note,
## saves it on close, and keeps the open-on-startup preference.
class_name NoteWindow
extends CommonWindow

var editor: CommonEditor
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
	# Keep the toolbar below the title band; other CommonWindow content covers all fractional edges.
	container.offset_top = 0
	editor = CommonEditor.new()
	container.add_child(editor)
	editor.set_suffix("md")

	open_on_startup_check = CheckButton.new()
	open_on_startup_check.focus_mode = Control.FOCUS_NONE
	open_on_startup_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_on_startup_check.button_pressed = NoteSetting.get_open_on_startup()
	open_on_startup_check.toggled.connect(on_open_on_startup_toggled)
	editor.add_toolbar_leading(open_on_startup_check)
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
	ButtonStyle.apply_check_button(open_on_startup_check)
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
