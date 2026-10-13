class_name GitDiffViewer
extends Window

## Side-by-side source comparison. The left CodeEdit is an immutable snapshot; the right CodeEdit
## loads the current workspace file and saves only if it has not changed again while being edited.

const SCREEN_SIZE_RATIO := 0.80
const CHANGED_LINE_ALPHA := 0.22
const BORDER_ALPHA := 0.18
const BORDER_ALPHA_UNFOCUSED := 0.08

var files: Array[GitDiffFile] = []
var workspace_root: String = ""
var selected_index := 0
## Exact workspace text loaded when the current file was selected.
var baseline_text := ""
## Programmatic text replacement emits CodeEdit.text_changed too; suppress it while loading/reverting.
var suppress_text_changed := false
## Both scrollbars emit when assigned, so this guard prevents left/right signal recursion.
var syncing_scroll := false
var displayed_changed := {"old": PackedInt32Array(), "new": PackedInt32Array()}

var path_label: Label
var position_label: Label
var status_label: Label
var previous_button: Button
var next_button: Button
var revert_button: Button
var content_panel: PanelContainer
var toolbar_panel: PanelContainer
var heading_container: HBoxContainer
var split_container: HSplitContainer
var left_edit: CodeEdit
var right_edit: CodeEdit
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


## Opens one viewer for a cached run. There is deliberately no file sidebar: navigation stays in
## the compact toolbar, while [param selected_path] lets a clicked chat-bubble path open directly.
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
	# Cover fractional canvas-scaling remainders on every edge. The Window viewport clips the
	# one-pixel overlap so its clear color cannot show through at particular viewer sizes.
	content_panel.offset_left = -ControlSize.border_xs
	content_panel.offset_top = -ControlSize.border_xs
	content_panel.offset_right = ControlSize.border_xs
	content_panel.offset_bottom = ControlSize.border_xs
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
	revert_button = make_button("Revert", "Restore the right pane to the left pane's version")
	revert_button.pressed.connect(revert_current)
	toolbar.add_child(revert_button)

	# Headings must not be children of the editor SplitContainer. Otherwise its grabber extends up
	# through the heading row; a plain HBox mirrors the editor widths without drawing a divider.
	heading_container = HBoxContainer.new()
	heading_container.add_theme_constant_override("separation", 0)
	root.add_child(heading_container)
	left_heading_panel = add_heading_panel(heading_container, "Original · read only")
	right_heading_panel = add_heading_panel(heading_container, "Current · editable")

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

	apply_theme()
	pass


func reset_split() -> void:
	# Split offset is relative to the center, not the left edge. Run after popup layout so zero
	# reliably produces two equal panes at the final 80%-of-screen window size.
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
	# Split child sizes settle after the dragged signal; defer before reading them.
	sync_heading_widths.call_deferred()
	pass


func sync_heading_widths() -> void:
	# Stretch ratios keep heading labels aligned with their editors without adding a second grabber.
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
	# The left side remains the historical pre-run snapshot. For complete editable entries, the right
	# side follows the live workspace so reopening an old chat diff never presents stale file content.
	var current_text := file.new_text
	if file.complete and not file.binary and not file.new_path.is_empty():
		var target := FileUtils.normalize_path(workspace_root.path_join(file.new_path))
		if FileUtils.is_relative_to(target, workspace_root):
			file.new_exists = FileAccess.file_exists(target)
			current_text = FileUtils.read_file_to_string(target) if file.new_exists else StringUtils.EMPTY
			file.new_text = current_text
			file.new_hash = current_text.sha256_text()
	suppress_text_changed = true
	left_edit.text = file.old_text
	right_edit.text = current_text
	baseline_text = current_text
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


## Full snapshots are compared by Git. Legacy partial patches retain their cached display-relative
## line numbers because they do not contain enough source to run a meaningful complete-file diff.
func paint_changed_lines() -> void:
	var file := files[selected_index]
	if file.complete and not file.binary:
		run_current_git_diff()
	else:
		displayed_changed = {"old": file.old_changed_lines, "new": file.new_changed_lines}
		apply_changed_lines(displayed_changed)
	pass


func apply_changed_lines(changed: Dictionary) -> void:
	for line in left_edit.get_line_count():
		left_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for line in right_edit.get_line_count():
		right_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for line_number: int in changed["old"]:
		var index := line_number - 1
		if index >= 0 and index < left_edit.get_line_count():
			left_edit.set_line_background_color(index, Color(Colors.error, CHANGED_LINE_ALPHA))
	for line_number: int in changed["new"]:
		var index := line_number - 1
		if index >= 0 and index < right_edit.get_line_count():
			right_edit.set_line_background_color(index, Color(Colors.success, CHANGED_LINE_ALPHA))
	pass


func run_current_git_diff() -> void:
	if not is_inside_tree():
		return
	var old_text := left_edit.text
	var new_text := right_edit.text
	var result := await GitHelper.async_diff_texts(old_text, new_text)
	if not is_inside_tree() or old_text != left_edit.text or new_text != right_edit.text:
		return
	if result.exit_code != 0 and result.exit_code != 1:
		Log.error("live git diff failed exit:[{}] output:[{}]", result.exit_code, result.output.build_string())
		return
	displayed_changed = GitDiffParser.changed_lines(result.output.build_string())
	apply_changed_lines(displayed_changed)
	pass


func is_dirty() -> bool:
	return right_edit.text != baseline_text


func refresh_actions() -> void:
	var editable := files[selected_index].can_edit()
	revert_button.disabled = not editable or right_edit.text == left_edit.text
	pass


func on_right_text_changed() -> void:
	if not suppress_text_changed:
		var line := right_edit.get_caret_line()
		if line >= 0 and line < right_edit.get_line_count():
			right_edit.set_line_background_color(line, Color(Colors.success, CHANGED_LINE_ALPHA))
		refresh_actions()
		run_current_git_diff()
	pass


func select_relative(offset: int) -> void:
	if not save_current():
		return
	selected_index = posmod(selected_index + offset, files.size())
	load_selected_file()
	pass


func revert_current() -> void:
	suppress_text_changed = true
	right_edit.text = left_edit.text
	suppress_text_changed = false
	refresh_actions()
	paint_changed_lines()
	pass


## Writes the editable snapshot only when the workspace still matches the post-run cache. This is
## optimistic concurrency control: an older chat diff must never overwrite a later agent/user edit.
func save_current() -> bool:
	var file := files[selected_index]
	if not file.can_edit() or not is_dirty():
		return true
	var target := FileUtils.normalize_path(workspace_root.path_join(file.new_path))
	if not FileUtils.is_relative_to(target, workspace_root):
		Alert.alert("Cannot save outside the workspace", Colors.error)
		return false
	var exists_now := FileAccess.file_exists(target)
	var current_text := FileUtils.read_file_to_string(target) if exists_now else StringUtils.EMPTY
	if exists_now != file.new_exists or current_text.sha256_text() != file.new_hash:
		Alert.alert("Workspace file changed after this diff was created; save was cancelled", Colors.warning)
		return false
	if not FileUtils.write_string_to_file(target, right_edit.text):
		Alert.alert("Cannot save file: " + file.new_path, Colors.error)
		return false
	baseline_text = right_edit.text
	file.new_text = baseline_text
	file.new_hash = baseline_text.sha256_text()
	file.new_exists = true
	refresh_actions()
	Alert.alert("Saved successfully", Colors.success)
	return true


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
	# Old/new files may have different line counts. Syncing their raw values would pin or overscroll
	# one side, so map the source's normalized progress onto the target's scrollable range.
	var source_range := maxf(source_bar.max_value - source_bar.page, 0.0)
	var target_range := maxf(target_bar.max_value - target_bar.page, 0.0)
	syncing_scroll = true
	target.scroll_vertical = 0.0 if source_range <= 0.0 else value / source_range * target_range
	syncing_scroll = false
	pass


func request_close() -> void:
	if not save_current():
		return
	queue_free()
	pass


func _notification(what: int) -> void:
	# Match PopupWindow: clicking outside closes the viewer after saving any right-pane edits.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible:
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


## Repaints every native Window/CodeEdit/Dialog surface. Theme changes happen while the viewer is
## open, so no control should retain a color captured only during construction.
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
	for button in [previous_button, next_button, revert_button]:
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
	if not files.is_empty():
		apply_changed_lines(displayed_changed)
	pass


func tint_theme_icon(icon_name: String, color: Color) -> ImageTexture:
	var image := get_theme_icon(icon_name).get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


func make_transparent_grabber() -> ImageTexture:
	# SplitContainer's stock grabber has its own minimum width. A 1px transparent icon leaves only
	# the configured separation visible while preserving the native drag interaction.
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
