## Markdown note editor. Left pane edits raw text; right pane previews Markdown. A toolbar under
## the title bar toggles edit / split / preview and whether the note opens on startup. Content is
## loaded on open and saved when the window closes.
class_name NoteWindow
extends CommonWindow

const EDIT_ICON_PATH := "res://agent/asset/image/icon/edit.svg"
const SPLIT_ICON_PATH := "res://agent/asset/image/icon/split.svg"
const PREVIEW_ICON_PATH := "res://agent/asset/image/icon/eye.svg"

var view_mode: NoteSetting.ViewMode = NoteSetting.ViewMode.SPLIT
var root: VBoxContainer
var toolbar_panel: PanelContainer
var toolbar: HBoxContainer
var split_container: HSplitContainer
var text_edit: TextEdit
var preview_panel: PanelContainer
var preview_label: RichTextLabel
var open_on_startup_check: CheckButton
var edit_mode_button: Button
var split_mode_button: Button
var preview_mode_button: Button
var mode_button_group: ButtonGroup


func _init() -> void:
	super()
	gdf.events.locale_changed.connect(apply_locale)
	build_layout()
	apply_theme()
	apply_locale()
	set_view_mode(NoteSetting.get_view_mode())
	pass


func build_layout() -> void:
	# Keep the toolbar below the title band; other CommonWindow content covers all fractional edges.
	container.offset_top = 0
	root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	container.add_child(root)

	toolbar_panel = PanelContainer.new()
	toolbar_panel.custom_minimum_size.y = ControlSize.sm
	root.add_child(toolbar_panel)

	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = ControlSize.sm
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", Margin.ma_1)
	toolbar_panel.add_child(toolbar)

	open_on_startup_check = CheckButton.new()
	open_on_startup_check.focus_mode = Control.FOCUS_NONE
	open_on_startup_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_on_startup_check.button_pressed = NoteSetting.get_open_on_startup()
	open_on_startup_check.toggled.connect(on_open_on_startup_toggled)
	toolbar.add_child(open_on_startup_check)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	mode_button_group = ButtonGroup.new()
	edit_mode_button = make_mode_button(NoteSetting.ViewMode.EDIT, EDIT_ICON_PATH)
	split_mode_button = make_mode_button(NoteSetting.ViewMode.SPLIT, SPLIT_ICON_PATH)
	preview_mode_button = make_mode_button(NoteSetting.ViewMode.PREVIEW, PREVIEW_ICON_PATH)
	toolbar.add_child(edit_mode_button)
	toolbar.add_child(split_mode_button)
	toolbar.add_child(preview_mode_button)

	split_container = HSplitContainer.new()
	split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_theme_constant_override("separation", 0)
	split_container.dragged.connect(on_split_dragged)
	root.add_child(split_container)

	text_edit = TextEdit.new()
	text_edit.editable = true
	text_edit.caret_blink = true
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(on_text_changed)
	split_container.add_child(text_edit)

	preview_panel = PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_child(preview_panel)

	preview_label = MarkdownHelper.create_rich_text_label(Colors.primary_text, "", true)
	preview_label.fit_content = false
	preview_label.scroll_active = true
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_label)
	pass


func make_mode_button(mode: NoteSetting.ViewMode, icon_path: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = mode_button_group
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.set_meta("note_icon_path", icon_path)
	button.pressed.connect(func() -> void: set_view_mode(mode))
	return button


func apply_locale() -> void:
	title = I18n.t("note.title")
	text_edit.placeholder_text = I18n.t("note.placeholder")
	open_on_startup_check.text = I18n.t("note.open_on_startup")
	open_on_startup_check.tooltip_text = I18n.t("note.open_on_startup_hint")
	edit_mode_button.tooltip_text = I18n.t("note.mode_edit")
	split_mode_button.tooltip_text = I18n.t("note.mode_split")
	preview_mode_button.tooltip_text = I18n.t("note.mode_preview")
	pass


## Palette matches [GitDiffViewer]: frame/toolbar on [member Colors.surface], editors on
## [member Colors.app_background], title and body text on [member Colors.primary_text].
func apply_theme() -> void:
	super()
	container.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.surface))
	split_container.add_theme_icon_override("grabber", make_transparent_grabber())
	style_text_edit()
	style_preview()
	style_toolbar()
	pass


func window_background_color() -> Color:
	return Colors.surface


func window_title_color() -> Color:
	return Colors.primary_text


func window_border_color() -> Color:
	return Colors.primary_text


func style_text_edit() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.app_background, 0, Margin.ma_4, Margin.ma_3)
	text_edit.add_theme_stylebox_override("normal", style)
	text_edit.add_theme_stylebox_override("focus", style.duplicate())
	text_edit.add_theme_stylebox_override("read_only", style.duplicate())
	text_edit.add_theme_color_override("background_color", Colors.app_background)
	text_edit.add_theme_color_override("font_color", Colors.primary_text)
	text_edit.add_theme_color_override("font_readonly_color", Colors.primary_text)
	text_edit.add_theme_color_override("font_selected_color", Colors.primary_text)
	text_edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	text_edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	text_edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	text_edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	text_edit.add_theme_font_override("font", Fonts.regular())
	text_edit.add_theme_font_size_override("font_size", Typography.body_large_size)
	ScrollBarStyle.apply(text_edit.get_v_scroll_bar())
	ScrollBarStyle.apply(text_edit.get_h_scroll_bar())
	pass


func style_preview() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.app_background, 0, Margin.ma_4, Margin.ma_3)
	if view_mode == NoteSetting.ViewMode.SPLIT:
		style.border_color = Colors.border
		style.set_border_width(SIDE_LEFT, ControlSize.border_xs)
	preview_panel.add_theme_stylebox_override("panel", style)
	preview_label.add_theme_color_override("default_color", Colors.primary_text)
	MarkdownHelper.apply_selection_theme(preview_label)
	ScrollBarStyle.apply(preview_label.get_v_scroll_bar())
	pass


func style_toolbar() -> void:
	var toolbar_style := StyleBoxHelper.create_style_box_flat(Colors.surface, 0, Margin.ma_1, Margin.ma_0)
	toolbar_panel.add_theme_stylebox_override("panel", toolbar_style)
	open_on_startup_check.add_theme_font_override("font", Fonts.regular())
	open_on_startup_check.add_theme_font_size_override("font_size", Typography.label_medium_size)
	ButtonStyle.apply_check_button(open_on_startup_check, Colors.primary_text, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Margin.ma_1,
		Margin.ma_0, Margin.ma_0, Margin.ma_1, Margin.ma_0)
	style_mode_button(edit_mode_button)
	style_mode_button(split_mode_button)
	style_mode_button(preview_mode_button)
	pass


## Square icon button; selection uses the same surface treatment as [GitDiffViewer].
func style_mode_button(button: Button) -> void:
	button.text = ""
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.add_theme_constant_override("icon_max_width", Margin.ma_4)
	button.add_theme_constant_override("icon_max_height", Margin.ma_4)
	var normal := StyleBoxHelper.create_style_box_flat(
		Colors.control_surface, ControlSize.radius_sm, Margin.ma_1, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)
	var hover := ButtonStyle.filled(normal, ThemeColor.selected_surface, ThemeColor.accent_theme_color())
	var pressed := ButtonStyle.filled(
		normal, ThemeColor.selected_surface.lerp(ThemeColor.accent_theme_color(), Colors.am_2),
		ThemeColor.accent_theme_color())
	var disabled := ButtonStyle.filled(normal, Colors.surface, Colors.subtle_border)
	ButtonStyle.apply_style(button, normal, hover, pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	var icon_path := str(button.get_meta("note_icon_path", ""))
	var icon_color := ThemeColor.accent_theme_color() if button.button_pressed else Colors.primary_text
	button.icon = make_icon(icon_path, icon_color)
	pass


func make_icon(path: String, color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(path)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


func make_transparent_grabber() -> ImageTexture:
	var image := Image.create(ControlSize.border_xs, ControlSize.border_xs, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func set_view_mode(mode: NoteSetting.ViewMode) -> void:
	view_mode = mode
	NoteSetting.set_view_mode(mode)
	text_edit.visible = mode != NoteSetting.ViewMode.PREVIEW
	preview_panel.visible = mode != NoteSetting.ViewMode.EDIT
	edit_mode_button.set_pressed_no_signal(mode == NoteSetting.ViewMode.EDIT)
	split_mode_button.set_pressed_no_signal(mode == NoteSetting.ViewMode.SPLIT)
	preview_mode_button.set_pressed_no_signal(mode == NoteSetting.ViewMode.PREVIEW)
	style_preview()
	style_mode_button(edit_mode_button)
	style_mode_button(split_mode_button)
	style_mode_button(preview_mode_button)
	if mode != NoteSetting.ViewMode.EDIT:
		refresh_preview()
	if mode == NoteSetting.ViewMode.SPLIT:
		reset_split.call_deferred()
	if mode != NoteSetting.ViewMode.PREVIEW and is_inside_tree() and visible:
		text_edit.grab_focus()
	pass


func on_text_changed() -> void:
	if view_mode != NoteSetting.ViewMode.EDIT:
		refresh_preview()
	pass


func refresh_preview() -> void:
	MarkdownHelper.update_rich_text_label_text(preview_label, text_edit.text, true)
	pass


func on_open_on_startup_toggled(enabled: bool) -> void:
	NoteSetting.set_open_on_startup(enabled)
	pass


func on_split_dragged(_offset: int) -> void:
	var width := split_container.size.x
	if width <= 0.0:
		return
	# split_offset is center-relative; convert back to a left-pane ratio for persistence.
	NoteSetting.set_split_ratio(float(split_container.split_offset) / width + 0.5)
	pass


func reset_split() -> void:
	if not split_container.visible:
		return
	if not text_edit.visible or not preview_panel.visible:
		return
	var width := split_container.size.x
	if width <= 0.0:
		return
	split_container.split_offset = roundi(width * (NoteSetting.get_split_ratio() - 0.5))
	pass


## Open a centered note editor. Width/height are percent of the screen (1–100).
static func show_note(width_percent: int = 60, height_percent: int = 80) -> void:
	close_open_notes()
	var window := NoteWindow.new()
	gdf.gdf_node.add_child(window)
	window.text_edit.text = NoteSetting.get_note()
	window.refresh_preview()
	window.present_centered(width_percent, height_percent)
	pass


func present_centered(width_percent: int = 70, height_percent: int = 80) -> void:
	super(width_percent, height_percent)
	reset_split.call_deferred()
	if view_mode != NoteSetting.ViewMode.PREVIEW:
		text_edit.grab_focus()
	pass


func on_close_requested() -> void:
	var content := text_edit.text
	if NoteSetting.set_note(content) != OK:
		Alert.alert(I18n.t("note.save_failed"), Colors.error)
	queue_free()
	pass


static func close_open_notes() -> void:
	var open: Array[NoteWindow] = []
	for child in gdf.gdf_node.get_children():
		if child is NoteWindow:
			open.push_back(child)
	for window in open:
		window.on_close_requested()
	pass
