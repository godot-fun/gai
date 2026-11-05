## Text editor. [method set_document] takes the text and a format suffix.
## Markdown suffixes keep the split editor and preview. Other suffixes are a single highlighted editor.
## Edit / split / preview float at the top-right of the content, and only for Markdown.
## Ctrl+F floats a find bar at the top-left; Ctrl+R adds replace. Both search the editor text.
## Extra controls go in front of the content through [method add_toolbar_leading].
class_name CommonEditor
extends VBoxContainer

const EDIT_ICON_PATH := "res://agent/asset/image/ui/edit.svg"
const SPLIT_ICON_PATH := "res://agent/asset/image/ui/vertical_split.svg"
const PREVIEW_ICON_PATH := "res://agent/asset/image/ui/visibility.svg"
const FIND_PREVIOUS_ICON_PATH := "res://agent/asset/image/ui/keyboard_arrow_up.svg"
const FIND_NEXT_ICON_PATH := "res://agent/asset/image/ui/keyboard_arrow_down.svg"
const FIND_REPLACE_ICON_PATH := "res://agent/asset/image/ui/find_replace.svg"
const FIND_REPLACE_ALL_ICON_PATH := "res://agent/asset/image/ui/done_all.svg"
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
var find_bar: PanelContainer
var find_row: HBoxContainer
var replace_row: HBoxContainer
var find_edit: LineEdit
var replace_edit: LineEdit
var find_count_label: Label
var find_previous_button: Button
var find_next_button: Button
var replace_button: Button
var replace_all_button: Button
## Caret where this find session started. Typing in the query keeps searching from here.
var find_anchor: Vector2i = Vector2i.ZERO
var selecting_match: bool = false
var replacing_matches: bool = false

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
		update_replace_buttons()
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
	content.resized.connect(position_find_bar)
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
	text_edit.caret_changed.connect(on_editor_caret_changed)
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
	build_find_bar()
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
	find_edit.placeholder_text = I18n.t("markdown.find_placeholder")
	replace_edit.placeholder_text = I18n.t("markdown.replace_placeholder")
	find_previous_button.tooltip_text = I18n.t("markdown.find_previous")
	find_next_button.tooltip_text = I18n.t("markdown.find_next")
	replace_button.tooltip_text = I18n.t("markdown.replace")
	replace_all_button.tooltip_text = I18n.t("markdown.replace_all")
	position_find_bar()
	pass


func apply_theme() -> void:
	split_container.add_theme_icon_override("grabber", make_transparent_grabber())
	style_text_edit()
	style_preview()
	style_toolbar()
	style_find_bar()
	apply_highlighter()
	position_mode_bar()
	position_find_bar()
	pass


func style_text_edit() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.app_background, 0, Margin.ma_4, Margin.ma_3)
	text_edit.add_theme_stylebox_override("normal", style)
	text_edit.add_theme_stylebox_override("focus", style.duplicate())
	text_edit.add_theme_stylebox_override("read_only", style.duplicate())
	text_edit.add_theme_color_override("background_color", Colors.app_background)
	CodeEditStyle.apply_base(text_edit)
	text_edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	text_edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	text_edit.add_theme_color_override("search_result_color", Color(ThemeColor.accent_theme_color(), 0.35))
	text_edit.add_theme_color_override("search_result_border_color", ThemeColor.accent_theme_color())
	text_edit.add_theme_font_size_override("font_size", Typography.body_large_size)
	if not is_markdown():
		text_edit.add_theme_color_override("line_number_color", Colors.secondary_text)
	pass


func style_preview() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Colors.app_background, 0, Margin.ma_4, Margin.ma_3)
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
	if is_instance_valid(find_bar) and find_bar.visible and not replacing_matches:
		update_find_count()
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


func _unhandled_input(event: InputEvent) -> void:
	if handle_find_shortcut(event):
		get_viewport().set_input_as_handled()
	pass


## Ctrl+F opens find. Ctrl+R opens replace. Esc closes the bar.
func handle_find_shortcut(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.keycode == KEY_ESCAPE and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed and not key.shift_pressed:
		if find_bar.visible:
			close_find()
			return true
		return false
	if key.alt_pressed or key.shift_pressed or not (key.ctrl_pressed or key.meta_pressed):
		return false
	if key.keycode == KEY_F:
		open_find(false)
		return true
	if key.keycode == KEY_R:
		open_find(true)
		return true
	return false


func build_find_bar() -> void:
	find_bar = PanelContainer.new()
	find_bar.visible = false
	find_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	find_bar.anchor_left = 0.0
	find_bar.anchor_top = 0.0
	find_bar.anchor_right = 0.0
	find_bar.anchor_bottom = 0.0
	find_bar.grow_horizontal = Control.GROW_DIRECTION_END
	find_bar.grow_vertical = Control.GROW_DIRECTION_END
	content.add_child(find_bar)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Margin.ma_1)
	grid.add_theme_constant_override("v_separation", Margin.ma_1)
	find_bar.add_child(grid)

	find_edit = make_find_line_edit()
	find_edit.text_changed.connect(on_find_query_changed)
	find_edit.gui_input.connect(on_find_edit_gui_input)
	grid.add_child(find_edit)

	find_row = HBoxContainer.new()
	find_row.add_theme_constant_override("separation", Margin.ma_1)
	find_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(find_row)

	find_count_label = Label.new()
	find_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	find_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	find_count_label.custom_minimum_size = Vector2(ControlSize.xl, ControlSize.sm)
	find_row.add_child(find_count_label)

	find_previous_button = make_find_icon_button(FIND_PREVIOUS_ICON_PATH)
	find_previous_button.pressed.connect(find_previous)
	find_row.add_child(find_previous_button)

	find_next_button = make_find_icon_button(FIND_NEXT_ICON_PATH)
	find_next_button.pressed.connect(find_next)
	find_row.add_child(find_next_button)

	replace_edit = make_find_line_edit()
	replace_edit.visible = false
	replace_edit.gui_input.connect(on_replace_edit_gui_input)
	grid.add_child(replace_edit)

	replace_row = HBoxContainer.new()
	replace_row.visible = false
	replace_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replace_row.add_theme_constant_override("separation", Margin.ma_1)
	replace_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(replace_row)

	var replace_spacer := Control.new()
	replace_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replace_row.add_child(replace_spacer)

	replace_button = make_find_icon_button(FIND_REPLACE_ICON_PATH)
	replace_button.pressed.connect(replace_current)
	replace_row.add_child(replace_button)

	replace_all_button = make_find_icon_button(FIND_REPLACE_ALL_ICON_PATH)
	replace_all_button.pressed.connect(replace_all_matches)
	replace_row.add_child(replace_all_button)
	pass


func make_find_line_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(ControlSize.image_md, ControlSize.sm)
	return edit


func make_find_icon_button(icon_path: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.add_theme_constant_override("icon_max_width", ControlSize.icon_sm)
	button.add_theme_constant_override("icon_max_height", ControlSize.icon_sm)
	button.set_meta("find_icon_path", icon_path)
	return button


func style_find_bar() -> void:
	var panel := StyleBoxHelper.create_style_box_flat(Colors.elevated_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_2, Colors.border, ControlSize.border_xs)
	find_bar.add_theme_stylebox_override("panel", panel)
	LineEditStyle.apply(find_edit)
	LineEditStyle.apply(replace_edit)
	style_find_line_edit(find_edit)
	style_find_line_edit(replace_edit)
	find_count_label.add_theme_font_override("font", Fonts.regular())
	find_count_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	find_count_label.add_theme_color_override("font_color", Colors.secondary_text)
	style_find_icon_button(find_previous_button)
	style_find_icon_button(find_next_button)
	style_find_icon_button(replace_button)
	style_find_icon_button(replace_all_button)
	pass


func style_find_line_edit(edit: LineEdit) -> void:
	edit.add_theme_font_override("font", Fonts.regular())
	edit.add_theme_font_size_override("font_size", Typography.label_large_size)
	pass


func style_find_icon_button(button: Button) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_sm)
	var accent := ThemeColor.accent_theme_color()
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Color(accent, 0.16))
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, Color(accent, 0.28))
	ButtonStyle.apply_style(button, normal, hover, pressed)
	var icon_path := str(button.get_meta("find_icon_path", ""))
	button.icon = ImageHelper.tint_svg(icon_path, Colors.primary_text)
	pass


func position_find_bar() -> void:
	if not is_inside_tree() or not is_instance_valid(find_bar):
		return
	var bar_size := find_bar.get_combined_minimum_size()
	find_bar.offset_left = Margin.ma_3
	find_bar.offset_top = Margin.ma_3
	find_bar.offset_right = Margin.ma_3 + bar_size.x
	find_bar.offset_bottom = Margin.ma_3 + bar_size.y
	pass


## Shows the top-left find bar. [param replace_mode] also shows the replace row.
## A single-line selection seeds the query only when the bar was closed.
## Preview mode switches to split so the match is visible.
func open_find(replace_mode: bool) -> void:
	if is_markdown() and view_mode == ViewMode.PREVIEW:
		set_view_mode(ViewMode.SPLIT)
	var opening := not find_bar.visible
	if opening:
		# Caret sits at the end of a selection, so anchor on the selection start.
		if text_edit.has_selection():
			find_anchor = Vector2i(text_edit.get_selection_from_line(), text_edit.get_selection_from_column())
		else:
			find_anchor = Vector2i(text_edit.get_caret_line(), text_edit.get_caret_column())
	find_bar.visible = true
	set_replace_visible(replace_mode)
	if opening:
		seed_query_from_selection()
	update_replace_buttons()
	var origin := current_match_origin(find_edit.text)
	position_find_bar()
	# Focusing the field clears the editor selection, so restore it afterwards.
	focus_find_input(replace_mode)
	if opening:
		select_nearest_match()
	elif origin.x >= 0:
		select_match(origin, find_edit.text.length())
	else:
		update_find_count()
	pass


func close_find() -> void:
	find_bar.visible = false
	set_replace_visible(false)
	clear_find_highlight()
	focus_editor()
	pass


## LineEdit.text assignment does not emit text_changed, so callers refresh the match explicitly.
func set_find_query(query: String) -> void:
	find_edit.text = query
	on_find_query_changed(query)
	pass


func set_replace_visible(show_replace: bool) -> void:
	replace_edit.visible = show_replace
	replace_row.visible = show_replace
	pass


func seed_query_from_selection() -> bool:
	if not text_edit.has_selection():
		return false
	var selected := text_edit.get_selected_text()
	if selected.is_empty() or selected.contains("\n"):
		return false
	set_find_query(selected)
	return true


func focus_find_input(replace_mode: bool) -> void:
	if not is_inside_tree():
		return
	var edit := replace_edit if replace_mode else find_edit
	if not edit.is_visible_in_tree():
		return
	edit.grab_focus()
	edit.select_all()
	pass


func on_find_query_changed(_query: String) -> void:
	update_replace_buttons()
	select_nearest_match()
	pass


func on_editor_caret_changed() -> void:
	if selecting_match or replacing_matches or not is_instance_valid(find_bar) or not find_bar.visible:
		return
	find_anchor = Vector2i(text_edit.get_caret_line(), text_edit.get_caret_column())
	pass


func on_find_edit_gui_input(event: InputEvent) -> void:
	var key := find_line_key(event)
	if key == null:
		return
	if key.keycode == KEY_ESCAPE:
		close_find()
	elif key.shift_pressed:
		find_previous()
	else:
		find_next()
	find_edit.accept_event()
	pass


func on_replace_edit_gui_input(event: InputEvent) -> void:
	var key := find_line_key(event)
	if key == null:
		return
	if key.keycode == KEY_ESCAPE:
		close_find()
	else:
		replace_current()
	replace_edit.accept_event()
	pass


func find_line_key(event: InputEvent) -> InputEventKey:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return null
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return null
	if key.keycode == KEY_ESCAPE and not key.shift_pressed:
		return key
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		return key
	return null


## Selects the next match after the current one, wrapping to the first.
func find_next() -> void:
	var query := find_edit.text
	if query.is_empty():
		clear_find_highlight()
		return
	var matches := collect_matches(query)
	if matches.is_empty():
		show_find_count(0, 0)
		return
	var origin := current_match_origin(query)
	var index := index_of_match(matches, origin)
	if index >= 0:
		index = (index + 1) % matches.size()
	else:
		index = nearest_match_index(matches, find_anchor)
	select_match(matches[index], query.length())
	pass


## Selects the previous match, wrapping to the last.
func find_previous() -> void:
	var query := find_edit.text
	if query.is_empty():
		clear_find_highlight()
		return
	var matches := collect_matches(query)
	if matches.is_empty():
		show_find_count(0, 0)
		return
	var origin := current_match_origin(query)
	var index := index_of_match(matches, origin)
	if index >= 0:
		index = (index - 1 + matches.size()) % matches.size()
	else:
		index = match_at_or_before(matches, find_anchor)
	select_match(matches[index], query.length())
	pass


## Replaces the selected match and selects the next one.
## When the selection is not the query, selects the next match and leaves the text unchanged.
func replace_current() -> void:
	if not editable:
		return
	var query := find_edit.text
	if query.is_empty():
		return
	if current_match_origin(query).x < 0:
		find_next()
		return
	var replacement := replace_edit.text
	replacing_matches = true
	text_edit.begin_complex_operation()
	text_edit.insert_text_at_caret(replacement)
	text_edit.end_complex_operation()
	replacing_matches = false
	find_next()
	pass


## Replaces every match in one undo step, then reports how many were replaced.
func replace_all_matches() -> void:
	if not editable:
		return
	var query := find_edit.text
	if query.is_empty():
		return
	var matches := collect_matches(query)
	var replacement := replace_edit.text
	if not matches.is_empty():
		replacing_matches = true
		text_edit.begin_complex_operation()
		for index in range(matches.size() - 1, -1, -1):
			var origin := matches[index]
			text_edit.select(origin.x, origin.y, origin.x, origin.y + query.length())
			text_edit.insert_text_at_caret(replacement)
		text_edit.end_complex_operation()
		replacing_matches = false
	find_count_label.text = StringUtils.format(I18n.t("markdown.replaced_count"), matches.size())
	apply_find_highlight(query)
	position_find_bar()
	pass


func select_nearest_match() -> void:
	var query := find_edit.text
	if query.is_empty():
		clear_find_highlight()
		return
	var matches := collect_matches(query)
	if matches.is_empty():
		show_find_count(0, 0)
		return
	select_match(matches[nearest_match_index(matches, find_anchor)], query.length())
	pass


func select_match(origin: Vector2i, length: int) -> void:
	selecting_match = true
	text_edit.select(origin.x, origin.y, origin.x, origin.y + length)
	text_edit.center_viewport_to_caret()
	selecting_match = false
	update_find_count()
	pass


func update_find_count() -> void:
	var query := find_edit.text
	if query.is_empty() or not find_bar.visible:
		clear_find_highlight()
		return
	var matches := collect_matches(query)
	var index := index_of_match(matches, current_match_origin(query))
	var current := index + 1 if index >= 0 else 0
	show_find_count(current, matches.size())
	pass


func show_find_count(current: int, total: int) -> void:
	apply_find_highlight(find_edit.text)
	find_count_label.text = StringUtils.format(I18n.t("markdown.find_count"), current, total)
	position_find_bar()
	pass


func clear_find_highlight() -> void:
	text_edit.set_search_text("")
	find_count_label.text = ""
	pass


func apply_find_highlight(query: String) -> void:
	text_edit.set_search_flags(TextEdit.SEARCH_MATCH_CASE)
	text_edit.set_search_text(query)
	pass


func update_replace_buttons() -> void:
	if replace_button == null:
		return
	var enabled := editable and not find_edit.text.is_empty()
	replace_button.disabled = not enabled
	replace_all_button.disabled = not enabled
	pass


## Match positions are [code](line, column)[/code]. [method TextEdit.search] returns the opposite axis order and wraps, so matches are collected per line.
func collect_matches(query: String) -> Array[Vector2i]:
	var matches: Array[Vector2i] = []
	if query.is_empty():
		return matches
	for line in text_edit.get_line_count():
		var line_text := text_edit.get_line(line)
		var column := line_text.find(query)
		while column >= 0:
			matches.append(Vector2i(line, column))
			column = line_text.find(query, column + query.length())
	return matches


func current_match_origin(query: String) -> Vector2i:
	if query.is_empty() or not text_edit.has_selection():
		return Vector2i(-1, -1)
	if text_edit.get_selection_from_line() != text_edit.get_selection_to_line():
		return Vector2i(-1, -1)
	if text_edit.get_selected_text() != query:
		return Vector2i(-1, -1)
	return Vector2i(text_edit.get_selection_from_line(), text_edit.get_selection_from_column())


func index_of_match(matches: Array[Vector2i], origin: Vector2i) -> int:
	for index in matches.size():
		if matches[index] == origin:
			return index
	return -1


func nearest_match_index(matches: Array[Vector2i], anchor: Vector2i) -> int:
	for index in matches.size():
		if not is_match_before(matches[index], anchor):
			return index
	return 0


func match_at_or_before(matches: Array[Vector2i], anchor: Vector2i) -> int:
	var index := -1
	for match_index in matches.size():
		if is_match_before(anchor, matches[match_index]):
			break
		index = match_index
	if index < 0:
		return matches.size() - 1
	return index


func is_match_before(point: Vector2i, other: Vector2i) -> bool:
	if point.x != other.x:
		return point.x < other.x
	return point.y < other.y
