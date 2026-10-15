## Side-by-side Git diff viewer tests.

func builds_test() -> void:
	var viewer := GitDiffViewer.new()
	assert(viewer.left_edit != null)
	assert(viewer.connector != null)
	assert(viewer.heading_spacer != null)
	assert(viewer.connector.clip_contents)
	assert(viewer.previous_change_button.focus_mode == Control.FOCUS_NONE)
	assert(viewer.next_change_button.focus_mode == Control.FOCUS_NONE)
	assert(viewer.revert_button.custom_minimum_size.y == viewer.previous_change_button.custom_minimum_size.y)
	assert((viewer.content_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Colors.surface)
	assert((viewer.left_heading_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Colors.chrome_surface)
	assert((viewer.left_edit.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Colors.app_background)
	assert((viewer.revert_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Colors.control_surface)
	assert((viewer.revert_button.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == ThemeColor.selected_surface)
	assert((viewer.revert_button.get_theme_stylebox("hover") as StyleBoxFlat).border_color == ThemeColor.accent_theme_color())
	assert(not viewer.left_edit.editable)
	assert(viewer.right_edit.editable)
	assert(GitDiffViewer.initial_split_offset(1000.0) == -50)
	assert(viewer.content_panel.offset_left == -ControlSize.border_xs)
	assert(viewer.content_panel.offset_top == -ControlSize.border_xs)
	assert(viewer.content_panel.offset_right == ControlSize.border_xs)
	assert(viewer.content_panel.offset_bottom == ControlSize.border_xs)
	viewer.free()
	pass


func applies_file_highlighter_test() -> void:
	var file := GitDiffFile.new()
	file.old_path = "demo.gd"
	file.new_path = "demo.gd"
	file.old_text = "func old() -> void:\n\tpass"
	file.new_text = "func current() -> void:\n\tpass"
	var viewer := GitDiffViewer.new()
	viewer.files = [file]
	viewer.load_selected_file()
	assert(viewer.left_edit.syntax_highlighter is CodeHighlighter)
	assert(viewer.right_edit.syntax_highlighter is CodeHighlighter)
	assert(viewer.left_edit.syntax_highlighter != viewer.right_edit.syntax_highlighter)
	viewer.free()
	pass


func maps_lines_across_hunks_test() -> void:
	var viewer := GitDiffViewer.new()
	var hunk := GitDiffParser.DiffHunk.new(3, 2, 3, 4)
	viewer.displayed_hunks = [hunk]
	assert(viewer.map_diff_line(1.0, true) == 1.0)
	assert(viewer.map_diff_line(2.0, true) == 2.0)
	assert(viewer.map_diff_line(4.0, true) == 6.0)
	assert(viewer.map_diff_line(6.0, false) == 4.0)
	viewer.free()
	pass


func maps_lines_across_multiple_hunks_test() -> void:
	var viewer := GitDiffViewer.new()
	viewer.displayed_hunks = [
		GitDiffParser.DiffHunk.new(2, 1, 2, 3),
		GitDiffParser.DiffHunk.new(8, 2, 10, 1),
	]
	assert(viewer.map_diff_line(0.0, true) == 0.0)
	assert(viewer.map_diff_line(4.0, true) == 6.0)
	assert(viewer.map_diff_line(10.0, true) == 11.0)
	assert(viewer.map_diff_line(6.0, false) == 4.0)
	assert(viewer.map_diff_line(11.0, false) == 10.0)
	viewer.free()
	pass


func maps_lines_inside_expanded_and_collapsed_hunks_test() -> void:
	var viewer := GitDiffViewer.new()
	viewer.displayed_hunks = [GitDiffParser.DiffHunk.new(3, 2, 3, 4)]
	assert(viewer.map_diff_line(2.0, true) == 2.0)
	assert(viewer.map_diff_line(3.0, true) == 4.0)
	assert(viewer.map_diff_line(2.0, false) == 2.0)
	assert(viewer.map_diff_line(4.0, false) == 3.0)
	viewer.free()
	pass


func hunk_navigation_moves_caret_test() -> void:
	var viewer := GitDiffViewer.new()
	viewer.right_edit.text = "one\ntwo\nthree\nfour\nfive"
	viewer.displayed_hunks = [GitDiffParser.DiffHunk.new(2, 1, 4, 1)]
	viewer.select_relative_hunk(1)
	assert(viewer.right_edit.get_caret_line() == 3)
	assert(viewer.right_edit.get_caret_column() == 0)
	viewer.free()
	pass


static func reverts_one_hunk_test() -> void:
	var old_text := "same\nold one\nold two\ntail\nlater old\nend"
	var new_text := "same\nnew one\nnew two\nnew three\ntail\nlater new\nend"
	var first_hunk := GitDiffParser.DiffHunk.new(2, 2, 2, 3)
	var reverted := GitDiffViewer.revert_hunk_text(old_text, new_text, first_hunk)
	assert(reverted == "same\nold one\nold two\ntail\nlater new\nend")
	pass


static func reverts_insert_and_delete_hunks_test() -> void:
	var insertion := GitDiffParser.DiffHunk.new(1, 0, 2, 1)
	assert(GitDiffViewer.revert_hunk_text("a\nb", "a\ninserted\nb", insertion) == "a\nb")
	var deletion := GitDiffParser.DiffHunk.new(2, 1, 1, 0)
	assert(GitDiffViewer.revert_hunk_text("a\nrestored\nb", "a\nb", deletion) == "a\nrestored\nb")
	pass


static func reverts_changes_at_file_boundaries_test() -> void:
	var replace_first := GitDiffParser.DiffHunk.new(1, 1, 1, 1)
	assert(GitDiffViewer.revert_hunk_text("old\ntail", "new\ntail", replace_first) == "old\ntail")
	var append_last := GitDiffParser.DiffHunk.new(2, 0, 3, 1)
	assert(GitDiffViewer.revert_hunk_text("a\nb", "a\nb\nextra", append_last) == "a\nb")
	var delete_last := GitDiffParser.DiffHunk.new(3, 1, 2, 0)
	assert(GitDiffViewer.revert_hunk_text("a\nb\nrestored", "a\nb", delete_last) == "a\nb\nrestored")
	pass


func revert_restores_left_snapshot_test() -> void:
	var file := GitDiffFile.new()
	file.old_path = "demo.gd"
	file.new_path = "demo.gd"
	file.old_text = "left version"
	file.new_text = "right version"
	file.new_exists = true
	var viewer := GitDiffViewer.new()
	viewer.files = [file]
	viewer.load_selected_file()
	assert(not viewer.revert_button.disabled)
	viewer.revert_current()
	assert(viewer.right_edit.text == file.old_text)
	assert(viewer.revert_button.disabled)
	viewer.free()
	pass
