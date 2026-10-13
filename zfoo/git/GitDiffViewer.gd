class_name GitDiffViewer
extends Window

## Side-by-side source comparison. The left CodeEdit is an immutable snapshot; the right CodeEdit
## edits the complete post-change file and writes only after checking that the workspace did not
## change since the cached diff was created.

const SCREEN_SIZE_RATIO := 0.80
const CHANGED_LINE_ALPHA := 0.22
const BORDER_ALPHA := 0.18
const BORDER_ALPHA_UNFOCUSED := 0.08

var files: Array[GitDiffFile] = []
var workspace_root: String = ""
var selected_index := 0
var baseline_text := ""
var suppress_text_changed := false
var syncing_scroll := false

var path_label: Label
var position_label: Label
var status_label: Label
var previous_button: Button
var next_button: Button
var save_button: Button
var revert_button: Button
var content_panel: PanelContainer
var toolbar_panel: PanelContainer
var heading_container: HBoxContainer
var split_container: HSplitContainer
var left_edit: CodeEdit
var right_edit: CodeEdit
var discard_dialog: ConfirmationDialog
var heading_labels: Array[Label] = []
var left_heading_panel: PanelContainer
var right_heading_panel: PanelContainer


func _init() -> void:
	title = "Git Diff"
	transient = true
	visible = false
	min_size = Vector2i(800, 520)
	close_requested.connect(request_close)
	window_input.connect(on_window_input)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	build_ui()
	pass


static func show_files(diff_files: Array[GitDiffFile], root_path: String, selected_path: String = "") -> void:
	if diff_files.is_empty():
		return
	var viewer := GitDiffViewer.new()
	viewer.files = diff_files
	viewer.workspace_root = FileUtils.normalize_path(root_path)
	for index in diff_files.size():
		if diff_files[index].display_path() == selected_path.replace("\\", "/"):
			viewer.selected_index = index
			break
	gdf.gdf_node.add_child(viewer)
	var viewport_size := gdf.gdf_node.get_tree().root.get_visible_rect().size
	viewer.size = Vector2i(int(viewport_size.x * SCREEN_SIZE_RATIO), int(viewport_size.y * SCREEN_SIZE_RATIO))
	viewer.load_selected_file()
	viewer.popup_centered()
	viewer.reset_split.call_deferred()
	viewer.right_edit.grab_focus()
	pass


func build_ui() -> void:
	content_panel = PanelContainer.new()
	content_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_panel)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	content_panel.add_child(root)

	toolbar_panel = PanelContainer.new()
	toolbar_panel.custom_minimum_size.y = ControlSize.md
	root.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = ControlSize.md
	toolbar.add_theme_constant_override("separation", Margin.ma_2)
	toolbar_panel.add_child(toolbar)
	previous_button = make_button("◀", "Previous changed file")
	style_navigation_button_size(previous_button)
	previous_button.pressed.connect(select_relative.bind(-1))
	toolbar.add_child(previous_button)
	next_button = make_button("▶", "Next changed file")
	style_navigation_button_size(next_button)
	next_button.pressed.connect(select_relative.bind(1))
	toolbar.add_child(next_button)
	path_label = Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(path_label)
	status_label = Label.new()
	toolbar.add_child(status_label)
	position_label = Label.new()
	toolbar.add_child(position_label)
	revert_button = make_button("Revert", "Discard edits in the right pane")
	revert_button.pressed.connect(revert_current)
	toolbar.add_child(revert_button)
	save_button = make_button("Save", "Save the right pane to the workspace (Ctrl+S)")
	save_button.pressed.connect(save_current)
	toolbar.add_child(save_button)

	heading_container = HBoxContainer.new()
	heading_container.add_theme_constant_override("separation", 0)
	root.add_child(heading_container)
	left_heading_panel = add_heading_panel(heading_container, "Original · read only")
	right_heading_panel = add_heading_panel(heading_container, "Updated · editable")

	split_container = HSplitContainer.new()
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.split_offset = 0
	split_container.add_theme_constant_override("separation", ControlSize.border_xs)
	split_container.dragged.connect(on_split_dragged)
	root.add_child(split_container)
	left_edit = make_code_edit(false)
	right_edit = make_code_edit(true)
	left_edit.get_v_scroll_bar().value_changed.connect(on_left_scroll)
	right_edit.get_v_scroll_bar().value_changed.connect(on_right_scroll)
	right_edit.text_changed.connect(on_right_text_changed)
	split_container.add_child(left_edit)
	split_container.add_child(right_edit)

	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Discard changes?"
	discard_dialog.dialog_text = "The right pane has unsaved changes. Discard them and close?"
	discard_dialog.ok_button_text = "Discard"
	discard_dialog.confirmed.connect(queue_free)
	add_child(discard_dialog)
	apply_theme()
	pass


func reset_split() -> void:
	# Split offset is relative to the center, so zero produces two equal panes after layout.
	split_container.split_offset = 0
	sync_heading_widths()
	pass


func add_heading_panel(parent: Container, heading: String) -> PanelContainer:
	var heading_panel := PanelContainer.new()
	heading_panel.custom_minimum_size.y = ControlSize.md
	heading_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(heading_panel)
	var label := Label.new()
	label.text = heading
	label.custom_minimum_size.y = ControlSize.md
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ThemeColor.body_color)
	label.add_theme_font_override("font", Fonts.medium())
	label.add_theme_font_size_override("font_size", Typography.label_large_size)
	heading_labels.append(label)
	heading_panel.add_child(label)
	return heading_panel


func on_split_dragged(_offset: int) -> void:
	sync_heading_widths.call_deferred()
	pass


func sync_heading_widths() -> void:
	var total_width := left_edit.size.x + right_edit.size.x
	if total_width <= 0.0:
		return
	left_heading_panel.size_flags_stretch_ratio = left_edit.size.x / total_width
	right_heading_panel.size_flags_stretch_ratio = right_edit.size.x / total_width
	pass


func make_code_edit(editable: bool) -> CodeEdit:
	var edit := CodeEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.editable = editable
	edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	edit.gutters_draw_line_numbers = true
	edit.highlight_current_line = editable
	edit.caret_blink = editable
	return edit


func make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = ControlSize.xs
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	return button


func style_navigation_button_size(button: Button) -> void:
	button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	pass


func load_selected_file() -> void:
	if files.is_empty():
		return
	var file := files[selected_index]
	suppress_text_changed = true
	left_edit.text = file.old_text
	right_edit.text = file.new_text
	baseline_text = file.new_text
	suppress_text_changed = false
	left_edit.editable = false
	right_edit.editable = file.can_edit()
	left_edit.scroll_vertical = 0
	right_edit.scroll_vertical = 0
	path_label.text = file.old_path + " → " + file.new_path if file.old_path != file.new_path and not file.old_path.is_empty() and not file.new_path.is_empty() else file.display_path()
	position_label.text = str(selected_index + 1) + " / " + str(files.size())
	status_label.text = file.status.capitalize()
	if file.binary:
		status_label.text = "Binary file"
	elif not file.complete:
		status_label.text = "Historical patch · read only"
	previous_button.disabled = files.size() <= 1
	next_button.disabled = files.size() <= 1
	refresh_actions()
	paint_changed_lines()
	pass


func paint_changed_lines() -> void:
	for line in left_edit.get_line_count():
		left_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for line in right_edit.get_line_count():
		right_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	var file := files[selected_index]
	for line_number in file.old_changed_lines:
		var index := line_number - 1
		if index >= 0 and index < left_edit.get_line_count():
			left_edit.set_line_background_color(index, Color(Colors.error, CHANGED_LINE_ALPHA))
	for line_number in file.new_changed_lines:
		var index := line_number - 1
		if index >= 0 and index < right_edit.get_line_count():
			right_edit.set_line_background_color(index, Color(Colors.success, CHANGED_LINE_ALPHA))
	pass


func is_dirty() -> bool:
	return right_edit.text != baseline_text


func refresh_actions() -> void:
	var editable := files[selected_index].can_edit()
	save_button.disabled = not editable or not is_dirty()
	revert_button.disabled = not editable or not is_dirty()
	pass


func on_right_text_changed() -> void:
	if not suppress_text_changed:
		var line := right_edit.get_caret_line()
		if line >= 0 and line < right_edit.get_line_count():
			right_edit.set_line_background_color(line, Color(Colors.success, CHANGED_LINE_ALPHA))
		refresh_actions()
	pass


func select_relative(offset: int) -> void:
	if is_dirty():
		Alert.alert("Save or revert the current file before switching", Colors.warning)
		return
	selected_index = posmod(selected_index + offset, files.size())
	load_selected_file()
	pass


func revert_current() -> void:
	suppress_text_changed = true
	right_edit.text = baseline_text
	suppress_text_changed = false
	refresh_actions()
	paint_changed_lines()
	pass


func save_current() -> void:
	var file := files[selected_index]
	if not file.can_edit() or not is_dirty():
		return
	var target := FileUtils.normalize_path(workspace_root.path_join(file.new_path))
	if not FileUtils.is_relative_to(target, workspace_root):
		Alert.alert("Cannot save outside the workspace", Colors.error)
		return
	var exists_now := FileAccess.file_exists(target)
	var current_text := FileUtils.read_file_to_string(target) if exists_now else StringUtils.EMPTY
	if exists_now != file.new_exists or current_text.sha256_text() != file.new_hash:
		Alert.alert("Workspace file changed after this diff was created; save was cancelled", Colors.warning)
		return
	if not FileUtils.write_string_to_file(target, right_edit.text):
		Alert.alert("Cannot save file: " + file.new_path, Colors.error)
		return
	baseline_text = right_edit.text
	file.new_text = baseline_text
	file.new_hash = baseline_text.sha256_text()
	file.new_exists = true
	refresh_actions()
	Alert.alert("Saved successfully", Colors.success)
	pass


func on_left_scroll(value: float) -> void:
	sync_vertical_scroll(left_edit, right_edit, value)
	pass


func on_right_scroll(value: float) -> void:
	sync_vertical_scroll(right_edit, left_edit, value)
	pass


func sync_vertical_scroll(source: CodeEdit, target: CodeEdit, value: float) -> void:
	if syncing_scroll:
		return
	var source_bar := source.get_v_scroll_bar()
	var target_bar := target.get_v_scroll_bar()
	var source_range := maxf(source_bar.max_value - source_bar.page, 0.0)
	var target_range := maxf(target_bar.max_value - target_bar.page, 0.0)
	syncing_scroll = true
	target.scroll_vertical = 0.0 if source_range <= 0.0 else value / source_range * target_range
	syncing_scroll = false
	pass


func request_close() -> void:
	if is_dirty():
		discard_dialog.popup_centered()
		return
	queue_free()
	pass


func _notification(what: int) -> void:
	# Match PopupWindow: clicking outside dismisses a clean viewer. Dirty edits still go through the
	# discard confirmation so focus loss can never destroy work silently.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible and not discard_dialog.visible:
		request_close.call_deferred()
	pass


func on_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		save_current()
		set_input_as_handled()
	pass


func apply_theme() -> void:
	add_theme_stylebox_override("embedded_border", make_embedded_border(BORDER_ALPHA))
	add_theme_stylebox_override("embedded_unfocused_border", make_embedded_border(BORDER_ALPHA_UNFOCUSED))
	add_theme_color_override("title_color", ThemeColor.title_color)
	add_theme_font_override("title_font", Fonts.semibold())
	add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	add_theme_icon_override("close_pressed", tint_theme_icon("close_pressed", Colors.error))
	content_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ThemeColor.accent_surface))
	split_container.add_theme_icon_override("grabber", make_transparent_grabber())
	var header_style := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, 0, Margin.ma_1, Margin.ma_0)
	toolbar_panel.add_theme_stylebox_override("panel", header_style)
	for panel in [left_heading_panel, right_heading_panel]:
		panel.add_theme_stylebox_override("panel", header_style.duplicate())
	for label in [path_label, position_label, status_label]:
		label.add_theme_color_override("font_color", ThemeColor.title_color)
		label.add_theme_font_override("font", Fonts.regular())
	for label in heading_labels:
		label.add_theme_color_override("font_color", ThemeColor.body_color)
	for button in [previous_button, next_button, save_button, revert_button]:
		style_compact_button(button)
	var editor_style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, Margin.ma_2, Margin.ma_2)
	for edit in [left_edit, right_edit]:
		edit.add_theme_stylebox_override("normal", editor_style.duplicate())
		edit.add_theme_stylebox_override("focus", editor_style.duplicate())
		edit.add_theme_stylebox_override("read_only", editor_style.duplicate())
		edit.add_theme_color_override("background_color", ThemeColor.inset_surface)
		edit.add_theme_color_override("font_color", ThemeColor.title_color)
		edit.add_theme_color_override("font_readonly_color", ThemeColor.title_color)
		edit.add_theme_color_override("font_selected_color", ThemeColor.title_color)
		edit.add_theme_color_override("line_number_color", ThemeColor.body_color)
		edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
		edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
		edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
		edit.add_theme_font_override("font", Fonts.regular())
		edit.add_theme_font_size_override("font_size", Typography.body_medium_size)
		ScrollBarStyle.apply(edit.get_v_scroll_bar())
		ScrollBarStyle.apply(edit.get_h_scroll_bar())
	style_discard_dialog()
	if not files.is_empty():
		paint_changed_lines()
	pass


func tint_theme_icon(icon_name: String, color: Color) -> ImageTexture:
	var image := get_theme_icon(icon_name).get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


func make_transparent_grabber() -> ImageTexture:
	var image := Image.create(ControlSize.border_xs, ControlSize.border_xs, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func make_embedded_border(border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("embedded_border").duplicate() as StyleBoxFlat
	style.bg_color = ThemeColor.accent_surface
	style.set_corner_radius_all(ControlSize.radius_md)
	style.border_color = Color(ThemeColor.title_color, border_alpha)
	style.set_border_width_all(ControlSize.border_xs)
	return style


func style_compact_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.body_color)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, ControlSize.radius_sm, Margin.ma_1, Margin.ma_0, Color(ThemeColor.title_color, 0.16), ControlSize.border_xs)
	var hover := ButtonStyle.filled(normal, ThemeColor.selected_surface, ThemeColor.accent_theme_color())
	var pressed := ButtonStyle.filled(normal, ThemeColor.accent_surface, ThemeColor.accent_theme_color())
	var disabled := ButtonStyle.filled(normal, ThemeColor.inset_surface)
	ButtonStyle.apply(button, normal, hover, pressed, disabled)
	pass


func style_discard_dialog() -> void:
	if discard_dialog == null:
		return
	var panel_style := StyleBoxHelper.create_style_box_flat(Colors.elevated_surface, ControlSize.radius_md, Margin.ma_4, Margin.ma_3, Colors.warning, ControlSize.border_sm)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34 if ThemeColor.is_dark_theme() else 0.22)
	panel_style.shadow_size = Margin.ma_3
	panel_style.shadow_offset = Vector2(0, Margin.ma_1)
	discard_dialog.add_theme_stylebox_override("panel", panel_style)
	discard_dialog.add_theme_stylebox_override("embedded_border", make_discard_dialog_border(BORDER_ALPHA))
	discard_dialog.add_theme_stylebox_override("embedded_unfocused_border", make_discard_dialog_border(BORDER_ALPHA_UNFOCUSED))
	discard_dialog.add_theme_color_override("title_color", Colors.primary_text)
	discard_dialog.add_theme_font_override("title_font", Fonts.semibold())
	discard_dialog.add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	discard_dialog.add_theme_icon_override("close_pressed", tint_theme_icon("close_pressed", Colors.error))
	var body_label := discard_dialog.get_label()
	body_label.add_theme_color_override("font_color", Colors.primary_text)
	body_label.add_theme_font_override("font", Fonts.regular())
	body_label.add_theme_font_size_override("font_size", Typography.body_medium_size)
	style_discard_button(discard_dialog.get_ok_button())
	style_compact_button(discard_dialog.get_cancel_button())
	pass


func make_discard_dialog_border(border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("embedded_border").duplicate() as StyleBoxFlat
	# The embedded border also paints the native title band. A semantic surface keeps that band
	# distinct from the elevated content panel below it in both light and dark themes.
	style.bg_color = Colors.warning_surface
	style.set_corner_radius_all(ControlSize.radius_md)
	style.border_color = Color(Colors.warning, maxf(border_alpha, 0.55))
	style.set_border_width_all(ControlSize.border_sm)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34 if ThemeColor.is_dark_theme() else 0.22)
	style.shadow_size = Margin.ma_3
	style.shadow_offset = Vector2(0, Margin.ma_1)
	return style


func style_discard_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, Colors.error, Colors.primary_text, Colors.primary_text)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.warning_surface, ControlSize.radius_sm, Margin.ma_2, Margin.ma_1, Colors.error, ControlSize.border_xs)
	var hover := ButtonStyle.filled(normal, ButtonStyle.hover_color(Colors.warning_surface, Colors.am_2), Colors.error)
	var pressed := ButtonStyle.filled(normal, Colors.error, Colors.error)
	ButtonStyle.apply(button, normal, hover, pressed)
	pass
