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
var displayed_changed := GitDiffParser.ChangedLines.new()

var path_label: Label
var position_label: Label
var status_label: Label
var previous_button: Button
var next_button: Button
var previous_change_button: Button
var next_change_button: Button
var change_position_label: Label
var revert_button: Button
var content_panel: PanelContainer
var toolbar_panel: PanelContainer
var heading_container: HBoxContainer
var split_container: HSplitContainer
var left_edit: CodeEdit
var right_edit: CodeEdit
var connector: GitDiffConnector
var heading_labels: Array[Label] = []
var left_heading_panel: PanelContainer
var heading_spacer: PanelContainer
var right_heading_panel: PanelContainer
var displayed_hunks: Array[GitDiffParser.DiffHunk] = []
var selected_hunk := -1


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
	# Embedded Window fonts need the main-window stretch ratio; set once after popup embeds.
	viewer.oversampling_override = DisplayScale.compute_ui_scale()
	viewer.reset_split.call_deferred()
	viewer.right_edit.grab_focus()
	viewer.reset_editor_view.call_deferred()
	pass


func reset_editor_view() -> void:
	left_edit.set_caret_line(0)
	right_edit.set_caret_line(0)
	left_edit.set_caret_column(0)
	right_edit.set_caret_column(0)
	syncing_scroll = true
	left_edit.scroll_vertical = 0.0
	right_edit.scroll_vertical = 0.0
	syncing_scroll = false
	connector.queue_redraw()
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
	previous_change_button = make_button("↑", "Previous difference")
	style_navigation_button_size(previous_change_button)
	previous_change_button.pressed.connect(select_relative_hunk.bind(-1))
	toolbar.add_child(previous_change_button)
	next_change_button = make_button("↓", "Next difference")
	style_navigation_button_size(next_change_button)
	next_change_button.pressed.connect(select_relative_hunk.bind(1))
	toolbar.add_child(next_change_button)
	change_position_label = Label.new()
	toolbar.add_child(change_position_label)
	status_label = Label.new()
	toolbar.add_child(status_label)
	position_label = Label.new()
	toolbar.add_child(position_label)
	revert_button = make_button("Revert", "Restore the right pane to the left pane's version")
	revert_button.pressed.connect(revert_current)
	toolbar.add_child(revert_button)

	# Headings must not be children of the editor SplitContainer. Otherwise its grabber extends up
	# through the heading row; a plain HBox mirrors left edit | connector | right edit widths.
	heading_container = HBoxContainer.new()
	heading_container.add_theme_constant_override("separation", 0)
	root.add_child(heading_container)
	left_heading_panel = add_heading_panel(heading_container, "Original · read only")
	heading_spacer = PanelContainer.new()
	heading_spacer.custom_minimum_size.y = ControlSize.md
	heading_spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN # width set in sync_heading_widths()
	heading_container.add_child(heading_spacer)
	right_heading_panel = add_heading_panel(heading_container, "Current · editable")

	split_container = HSplitContainer.new()
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.split_offset = 0
	# No gap between left edit and connector; drag still works via the transparent grabber.
	split_container.add_theme_constant_override("separation", 0)
	# resized covers both window resize and split dragging once child sizes have settled.
	split_container.resized.connect(sync_heading_widths)
	root.add_child(split_container)
	left_edit = make_code_edit(false)
	right_edit = make_code_edit(true)
	connector = GitDiffConnector.new()
	connector.set_editors(left_edit, right_edit)
	connector.revert_requested.connect(revert_hunk)
	left_edit.get_v_scroll_bar().value_changed.connect(on_left_scroll)
	right_edit.get_v_scroll_bar().value_changed.connect(on_right_scroll)
	right_edit.text_changed.connect(on_right_text_changed)
	split_container.add_child(left_edit)
	var right_side := HBoxContainer.new()
	right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Match left CodeEdit height in the split; HBox children then fill that height by default.
	right_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_side.add_theme_constant_override("separation", 0)
	right_side.add_child(connector)
	right_side.add_child(right_edit)
	split_container.add_child(right_side)

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


func sync_heading_widths() -> void:
	# Mirror left edit | split separation + connector | right edit so "Current" starts on the
	# right editor, not over the connector lane.
	var left_width := left_edit.size.x
	var middle_width := float(split_container.get_theme_constant("separation")) + connector.size.x
	var right_width := right_edit.size.x
	if left_width <= 0.0 or right_width <= 0.0:
		return
	heading_spacer.custom_minimum_size.x = middle_width
	left_heading_panel.size_flags_stretch_ratio = left_width
	right_heading_panel.size_flags_stretch_ratio = right_width
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
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	pass


func load_selected_file() -> void:
	if files.is_empty():
		return
	var file := files[selected_index]
	apply_syntax_highlighting(file.display_path())
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
	left_edit.set_caret_line(0)
	right_edit.set_caret_line(0)
	left_edit.set_caret_column(0)
	right_edit.set_caret_column(0)
	baseline_text = current_text
	suppress_text_changed = false
	left_edit.editable = false
	right_edit.editable = file.can_edit()
	connector.set_revert_enabled(file.can_edit())
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
	displayed_hunks.clear()
	selected_hunk = -1
	refresh_hunk_controls()
	connector.set_hunks(displayed_hunks, selected_hunk)
	refresh_actions()
	paint_changed_lines()
	pass


## Both panes use independently-owned highlighters because a SyntaxHighlighter can belong to only
## one TextEdit. Rebuilding on theme changes also refreshes every syntax color.
func apply_syntax_highlighting(file_path: String) -> void:
	left_edit.syntax_highlighter = GitCodeHighlighter.create(file_path)
	right_edit.syntax_highlighter = GitCodeHighlighter.create(file_path)
	pass


## Full snapshots are compared by Git. Legacy partial patches retain their cached display-relative
## line numbers because they do not contain enough source to run a meaningful complete-file diff.
func paint_changed_lines() -> void:
	var file := files[selected_index]
	if file.complete and not file.binary:
		run_current_git_diff()
	else:
		displayed_changed = file.changed_lines
		apply_changed_lines(displayed_changed)
	pass


func apply_changed_lines(changed: GitDiffParser.ChangedLines) -> void:
	for line in left_edit.get_line_count():
		left_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for line in right_edit.get_line_count():
		right_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for line_number: int in changed.old_lines:
		var index := line_number - 1
		if index >= 0 and index < left_edit.get_line_count():
			left_edit.set_line_background_color(index, Color(Colors.error, CHANGED_LINE_ALPHA))
	for line_number: int in changed.new_lines:
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
	var parsed_diff := GitDiffParser.parse(result.output.build_string())
	displayed_changed = parsed_diff.changed_lines
	displayed_hunks = parsed_diff.hunks
	selected_hunk = -1 if displayed_hunks.is_empty() else clampi(selected_hunk, 0, displayed_hunks.size() - 1)
	apply_changed_lines(displayed_changed)
	refresh_hunk_controls()
	connector.set_hunks(displayed_hunks, selected_hunk)
	pass


func refresh_hunk_controls() -> void:
	var has_hunks := not displayed_hunks.is_empty()
	previous_change_button.disabled = not has_hunks
	next_change_button.disabled = not has_hunks
	change_position_label.text = "0 differences" if not has_hunks else str(selected_hunk + 1) + " / " + str(displayed_hunks.size()) + " differences"
	pass


func select_relative_hunk(offset: int) -> void:
	if displayed_hunks.is_empty():
		return
	selected_hunk = posmod(selected_hunk + offset, displayed_hunks.size())
	var hunk := displayed_hunks[selected_hunk]
	var target_line := clampi(hunk.new_start - 1, 0, right_edit.get_line_count() - 1)
	right_edit.set_caret_line(target_line)
	right_edit.set_caret_column(0)
	syncing_scroll = true
	left_edit.scroll_vertical = maxf(float(hunk.old_start) - 3.0, 0.0)
	right_edit.scroll_vertical = maxf(float(hunk.new_start) - 3.0, 0.0)
	syncing_scroll = false
	refresh_hunk_controls()
	connector.set_hunks(displayed_hunks, selected_hunk)
	# Button clicks must hand keyboard input straight back to the editable pane.
	right_edit.grab_focus.call_deferred()
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


## Restores only one right-side hunk from the immutable left snapshot.
func revert_hunk(hunk_index: int) -> void:
	if hunk_index < 0 or hunk_index >= displayed_hunks.size() or not files[selected_index].can_edit():
		return
	var hunk := displayed_hunks[hunk_index]
	suppress_text_changed = true
	right_edit.text = revert_hunk_text(left_edit.text, right_edit.text, hunk)
	suppress_text_changed = false
	var caret_line := maxi(hunk.new_start - 1, 0)
	right_edit.set_caret_line(mini(caret_line, right_edit.get_line_count() - 1))
	right_edit.set_caret_column(0)
	refresh_actions()
	paint_changed_lines()
	pass


static func revert_hunk_text(old_text: String, new_text: String, hunk: GitDiffParser.DiffHunk) -> String:
	var old_lines := old_text.split(FileUtils.NEWLINE_LF, true)
	var new_lines := new_text.split(FileUtils.NEWLINE_LF, true)
	var old_count := hunk.old_count
	var new_count := hunk.new_count
	var old_start := hunk.old_start - 1 if old_count > 0 else hunk.old_start
	var new_start := hunk.new_start - 1 if new_count > 0 else hunk.new_start
	var result := PackedStringArray()
	for index in clampi(new_start, 0, new_lines.size()):
		result.append(new_lines[index])
	for offset in old_count:
		var index := old_start + offset
		if index >= 0 and index < old_lines.size():
			result.append(old_lines[index])
	for index in range(clampi(new_start + new_count, 0, new_lines.size()), new_lines.size()):
		result.append(new_lines[index])
	return FileUtils.NEWLINE_LF.join(result)


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
	syncing_scroll = true
	target.scroll_vertical = map_diff_line(value, source == left_edit)
	syncing_scroll = false
	connector.queue_redraw()
	pass


## Maps a visible source line through each hunk instead of syncing unrelated file percentages.
func map_diff_line(source_line: float, old_to_new: bool) -> float:
	var delta := 0.0
	for hunk: GitDiffParser.DiffHunk in displayed_hunks:
		var source_start := float(hunk.old_start if old_to_new else hunk.new_start) - 1.0
		var source_count := float(hunk.old_count if old_to_new else hunk.new_count)
		var target_start := float(hunk.new_start if old_to_new else hunk.old_start) - 1.0
		var target_count := float(hunk.new_count if old_to_new else hunk.old_count)
		if source_line < source_start:
			return maxf(source_line + delta, 0.0)
		if source_count > 0.0 and source_line < source_start + source_count:
			var progress := (source_line - source_start) / source_count
			return maxf(target_start + progress * target_count, 0.0)
		delta = target_start + target_count - (source_start + source_count)
	return maxf(source_line + delta, 0.0)


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
	for panel in [left_heading_panel, heading_spacer, right_heading_panel]:
		panel.add_theme_stylebox_override("panel", header_style.duplicate())
	for label in [path_label, position_label, status_label, change_position_label]:
		label.add_theme_color_override("font_color", ThemeColor.title_color)
		label.add_theme_font_override("font", Fonts.regular())
	for label in heading_labels:
		label.add_theme_color_override("font_color", ThemeColor.body_color)
	for button in [previous_button, next_button, previous_change_button, next_change_button, revert_button]:
		style_compact_button(button)
	# Horizontal margins stay 0 so line highlights meet the connector and the VScrollBar sits flush
	# (TextEdit insets the bar by content_margin_right). Keep a little vertical padding only.
	var editor_style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, 0, Margin.ma_2)
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
		apply_syntax_highlighting(files[selected_index].display_path())
	if not files.is_empty():
		apply_changed_lines(displayed_changed)
	connector.queue_redraw()
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
