## Text editor. [method set_document] takes the text and a format suffix.
## Markdown suffixes keep the split editor and preview. Other suffixes are a single highlighted editor.
## Edit / split / preview float at the top-right of the content, and only for Markdown.
## Extra controls go in front of the content through [method add_toolbar_leading].
class_name CommonEditor
extends VBoxContainer

const EDIT_ICON_PATH := "res://agent/asset/image/ui/edit.svg"
const SPLIT_ICON_PATH := "res://agent/asset/image/ui/vertical_split.svg"
const PREVIEW_ICON_PATH := "res://agent/asset/image/ui/visibility.svg"
const DEFAULT_SPLIT_RATIO := 0.5

enum ViewMode { EDIT, SPLIT, PREVIEW }

## Emitted after the user edits the text. Assigning [member text] emits this too.
signal text_changed
## Emitted when [method set_view_mode] changes the mode.
signal view_mode_changed(mode: ViewMode)
## Emitted while the user drags the split. [param ratio] is the left pane as a fraction of the width.
signal split_ratio_changed(ratio: float)

var view_mode: ViewMode = ViewMode.SPLIT
## Left-pane width as a fraction of the split (0–1). Restored across resizes via split offset.
var split_ratio: float = DEFAULT_SPLIT_RATIO
## Path or suffix last passed to [method set_suffix]. Empty until the first call.
var source_path: String = ""
var toolbar_panel: PanelContainer
var toolbar: HBoxContainer
var toolbar_spacer: Control
var content: Control
var mode_bar: HBoxContainer
var split_container: HSplitContainer
var text_edit: CodeEdit
var preview_panel: PanelContainer
var preview_label: RichTextLabel
var edit_mode_button: Button
var split_mode_button: Button
var preview_mode_button: Button
var mode_button_group: ButtonGroup

var text: String:
	get:
		return text_edit.text
	set(value):
		if text_edit.text == value:
			if shows_preview():
				refresh_preview()
			return
		# CodeEdit does not emit text_changed for a programmatic assignment.
		text_edit.text = value
		if shows_preview():
			refresh_preview()
		text_changed.emit()
		pass

var placeholder_text: String:
	get:
		return text_edit.placeholder_text
	set(value):
		text_edit.placeholder_text = value
		pass

var editable: bool:
	get:
		return text_edit.editable
	set(value):
		text_edit.editable = value
		text_edit.caret_blink = value
		text_edit.highlight_current_line = value
		pass


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	build_layout()
	apply_theme()
	apply_locale()
	set_view_mode(ViewMode.SPLIT)
	gdf.events.locale_changed.connect(apply_locale)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	pass


## Shows [param body] and switches layout from [param suffix] ([code]md[/code], [code].gd[/code], or a file path).
func set_document(body: String, suffix: String) -> void:
	set_suffix(suffix)
	text = body
	pass


func set_suffix(suffix: String) -> void:
	if suffix == source_path:
		return
	source_path = suffix
	apply_format()
	pass


func build_layout() -> void:
	toolbar_panel = PanelContainer.new()
	toolbar_panel.visible = false
	toolbar_panel.custom_minimum_size.y = ControlSize.sm
	add_child(toolbar_panel)

	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = ControlSize.sm
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", Margin.ma_1)
	toolbar_panel.add_child(toolbar)

	toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	content = Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.resized.connect(position_mode_bar)
	add_child(content)

	split_container = HSplitContainer.new()
	split_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split_container.add_theme_constant_override("separation", 0)
	split_container.dragged.connect(on_split_dragged)
	content.add_child(split_container)

	text_edit = CodeEdit.new()
	text_edit.editable = true
	text_edit.caret_blink = true
	text_edit.highlight_current_line = true
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	text_edit.gutters_draw_line_numbers = false
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(on_text_changed)
	split_container.add_child(text_edit)

	preview_panel = PanelContainer.new()
	preview_panel.visible = false
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_child(preview_panel)

	preview_label = MarkdownHelper.create_rich_text_label(Colors.primary_text, "", true)
	preview_label.fit_content = false
	preview_label.scroll_active = true
	preview_label.clip_contents = true
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.clip_contents = true
	preview_panel.add_child(preview_label)

	mode_button_group = ButtonGroup.new()
	edit_mode_button = make_mode_button(ViewMode.EDIT, EDIT_ICON_PATH)
	split_mode_button = make_mode_button(ViewMode.SPLIT, SPLIT_ICON_PATH)
	preview_mode_button = make_mode_button(ViewMode.PREVIEW, PREVIEW_ICON_PATH)
	mode_bar = HBoxContainer.new()
	mode_bar.visible = false
	mode_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_bar.add_theme_constant_override("separation", Margin.ma_1)
	mode_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_bar.anchor_left = 1.0
	mode_bar.anchor_top = 0.0
	mode_bar.anchor_right = 1.0
	mode_bar.anchor_bottom = 0.0
	mode_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mode_bar.grow_vertical = Control.GROW_DIRECTION_END
	mode_bar.add_child(edit_mode_button)
	mode_bar.add_child(split_mode_button)
	mode_bar.add_child(preview_mode_button)
	content.add_child(mode_bar)
	pass


## Insert [param control] on the left side of the top bar, above the content.
func add_toolbar_leading(control: Control) -> void:
	toolbar_panel.visible = true
	toolbar.add_child(control)
	toolbar.move_child(control, toolbar_spacer.get_index())
	pass


func make_mode_button(mode: ViewMode, icon_path: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = mode_button_group
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.add_theme_constant_override("icon_max_width", ControlSize.icon_sm)
	button.add_theme_constant_override("icon_max_height", ControlSize.icon_sm)
	button.set_meta("markdown_edit_icon_path", icon_path)
	button.pressed.connect(func() -> void: set_view_mode(mode))
	return button


func apply_locale() -> void:
	edit_mode_button.tooltip_text = I18n.t("markdown.mode_edit")
	split_mode_button.tooltip_text = I18n.t("markdown.mode_split")
	preview_mode_button.tooltip_text = I18n.t("markdown.mode_preview")
	pass


func apply_theme() -> void:
	split_container.add_theme_icon_override("grabber", make_transparent_grabber())
	style_text_edit()
	style_preview()
	style_toolbar()
	apply_highlighter()
	position_mode_bar()
	pass


func style_text_edit() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.control_surface, 0, Margin.ma_4, Margin.ma_3)
	text_edit.add_theme_stylebox_override("normal", style)
	text_edit.add_theme_stylebox_override("focus", style.duplicate())
	text_edit.add_theme_stylebox_override("read_only", style.duplicate())
	text_edit.add_theme_color_override("background_color", Colors.control_surface)
	CodeEditStyle.apply_base(text_edit)
	text_edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	text_edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	text_edit.add_theme_font_size_override("font_size", Typography.body_large_size)
	if not is_markdown():
		text_edit.add_theme_color_override("line_number_color", Colors.secondary_text)
	pass


func style_preview() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.control_surface, 0, Margin.ma_4, Margin.ma_3)
	if view_mode == ViewMode.SPLIT and is_markdown():
		style.border_color = Colors.border
		style.set_border_width(SIDE_LEFT, ControlSize.border_xs)
	preview_panel.add_theme_stylebox_override("panel", style)
	preview_label.add_theme_color_override("default_color", Colors.primary_text)
	MarkdownHelper.apply_selection_theme(preview_label)
	ScrollBarStyle.apply(preview_label.get_v_scroll_bar(), ScrollBarStyle.Thickness.LG)
	pass


func style_toolbar() -> void:
	var toolbar_style := StyleBoxHelper.create_style_box_flat(Colors.surface, 0, Margin.ma_1, Margin.ma_0)
	toolbar_panel.add_theme_stylebox_override("panel", toolbar_style)
	style_mode_button(edit_mode_button)
	style_mode_button(split_mode_button)
	style_mode_button(preview_mode_button)
	pass


func position_mode_bar() -> void:
	var size := mode_bar.get_combined_minimum_size()
	mode_bar.offset_top = Margin.ma_3
	mode_bar.offset_right = -Margin.ma_8
	mode_bar.offset_left = -Margin.ma_8 - size.x
	mode_bar.offset_bottom = Margin.ma_3 + size.y
	pass


func style_mode_button(button: Button) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_sm)
	var accent := ThemeColor.accent_theme_color()
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Color(accent, 0.16))
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, Color(accent, 0.28))
	ButtonStyle.apply_style(button, normal, hover, pressed)
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	var icon_path := str(button.get_meta("markdown_edit_icon_path", ""))
	var icon_color := ThemeColor.accent_theme_color() if button.button_pressed else Colors.primary_text
	button.icon = ImageHelper.tint_svg(icon_path, icon_color)
	pass


func make_transparent_grabber() -> ImageTexture:
	var image := Image.create(ControlSize.border_xs, ControlSize.border_xs, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func set_view_mode(mode: ViewMode) -> void:
	var changed := view_mode != mode
	view_mode = mode
	apply_view_visibility()
	edit_mode_button.set_pressed_no_signal(mode == ViewMode.EDIT)
	split_mode_button.set_pressed_no_signal(mode == ViewMode.SPLIT)
	preview_mode_button.set_pressed_no_signal(mode == ViewMode.PREVIEW)
	style_preview()
	style_mode_button(edit_mode_button)
	style_mode_button(split_mode_button)
	style_mode_button(preview_mode_button)
	if shows_preview():
		refresh_preview()
	if is_markdown() and mode == ViewMode.SPLIT:
		reset_split.call_deferred()
	focus_editor()
	if changed:
		view_mode_changed.emit(mode)
	pass


func focus_editor() -> void:
	if is_markdown() and view_mode == ViewMode.PREVIEW:
		return
	if is_inside_tree() and is_visible_in_tree():
		text_edit.grab_focus()
	pass


func on_text_changed() -> void:
	if shows_preview():
		refresh_preview()
	text_changed.emit()
	pass


func refresh_preview() -> void:
	MarkdownHelper.update_rich_text_label_text(preview_label, text_edit.text, true)
	pass


func on_split_dragged(_offset: int) -> void:
	var width := split_container.size.x
	if width <= 0.0:
		return
	# split_offset is center-relative; convert back to a left-pane ratio.
	split_ratio = float(split_container.split_offset) / width + 0.5
	split_ratio_changed.emit(split_ratio)
	pass


func set_split_ratio(ratio: float) -> void:
	split_ratio = ratio
	reset_split()
	pass


func reset_split() -> void:
	if not split_container.visible:
		return
	if not text_edit.visible or not preview_panel.visible:
		return
	var width := split_container.size.x
	if width <= 0.0:
		return
	split_container.split_offset = roundi(width * (split_ratio - 0.5))
	pass


func is_markdown() -> bool:
	return text_edit.syntax_highlighter is MarkdownHighlighter


func shows_preview() -> bool:
	return is_markdown() and view_mode != ViewMode.EDIT


func apply_format() -> void:
	apply_highlighter()
	var markdown := is_markdown()
	mode_bar.visible = markdown
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if markdown else TextEdit.LINE_WRAPPING_NONE
	text_edit.gutters_draw_line_numbers = not markdown and not source_path.is_empty()
	apply_view_visibility()
	style_text_edit()
	style_preview()
	if shows_preview():
		refresh_preview()
	if markdown and view_mode == ViewMode.SPLIT:
		reset_split.call_deferred()
	position_mode_bar()
	pass


func apply_view_visibility() -> void:
	if not is_markdown():
		text_edit.visible = true
		preview_panel.visible = false
		return
	text_edit.visible = view_mode != ViewMode.PREVIEW
	preview_panel.visible = view_mode != ViewMode.EDIT
	pass


func apply_highlighter() -> void:
	text_edit.syntax_highlighter = CommonHighlighter.create(source_path)
	pass
