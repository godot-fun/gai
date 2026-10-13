## Git unified-patch parsing and cached file model tests.

static func changed_lines_test() -> void:
	var patch := """diff --git a/demo.gd b/demo.gd
--- a/demo.gd
+++ b/demo.gd
@@ -2,4 +2,5 @@
 same
-old one
-old two
+new one
+new two
+new three
 tail
"""
	var changed := GitDiffParser.changed_lines(patch)
	assert(changed["old"] == PackedInt32Array([3, 4]))
	assert(changed["new"] == PackedInt32Array([3, 4, 5]))
	pass


static func parse_hunks_test() -> void:
	var patch := """@@ -3,2 +3,3 @@
-old one
-old two
+new one
+new two
+new three
@@ -12,0 +14,1 @@
+inserted
"""
	var hunks := GitDiffParser.parse_hunks(patch)
	assert(hunks.size() == 2)
	assert(hunks[0].old_start == 3)
	assert(hunks[0].old_count == 2)
	assert(hunks[0].new_count == 3)
	assert(hunks[1].old_count == 0)
	assert(hunks[1].new_start == 14)
	pass


static func git_diff_texts_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var result := await GitHelper.async_diff_texts("same\nold\ntail", "same\nnew\ntail")
	assert(result.exit_code == 1)
	var changed := GitDiffParser.changed_lines(result.output.build_string())
	assert(changed["old"] == PackedInt32Array([2]))
	assert(changed["new"] == PackedInt32Array([2]))
	pass


static func extract_file_patch_test() -> void:
	var patch := """diff --git a/first.gd b/first.gd
--- a/first.gd
+++ b/first.gd
@@ -1 +1 @@
-old
+new
diff --git a/folder/second file.gd b/folder/second file.gd
--- a/folder/second file.gd
+++ b/folder/second file.gd
@@ -1 +1 @@
-left
+right
"""
	var section := GitDiffParser.extract_file_patch(patch, "folder\\second file.gd")
	assert(section.begins_with("diff --git a/folder/second file.gd"))
	assert(section.contains("+right"))
	assert(not section.contains("+new"))
	assert(GitDiffParser.extract_file_patch(patch, "missing.gd").is_empty())
	pass


static func diff_file_round_trip_test() -> void:
	var source := GitDiffFile.new()
	source.old_path = "old.gd"
	source.new_path = "new.gd"
	source.old_text = "old"
	source.new_text = "new"
	source.new_hash = source.new_text.sha256_text()
	source.new_exists = true
	source.old_changed_lines = PackedInt32Array([1])
	source.new_changed_lines = PackedInt32Array([1, 2])
	var restored := GitDiffFile.from_dictionary(source.to_dictionary())
	assert(restored.old_path == source.old_path)
	assert(restored.new_path == source.new_path)
	assert(restored.new_hash == source.new_hash)
	assert(restored.old_changed_lines == source.old_changed_lines)
	assert(restored.new_changed_lines == source.new_changed_lines)
	assert(restored.can_edit())
	pass


static func deleted_file_is_not_editable_test() -> void:
	var file := GitDiffFile.new()
	file.old_path = "deleted.gd"
	file.new_path = ""
	file.status = GitDiffFile.STATUS_DELETED
	assert(not file.can_edit())
	pass


func diff_viewer_builds_test() -> void:
	var viewer := GitDiffViewer.new()
	assert(viewer.left_edit != null)
	assert(viewer.connector != null)
	assert(viewer.connector.clip_contents)
	assert(viewer.previous_change_button.focus_mode == Control.FOCUS_NONE)
	assert(viewer.next_change_button.focus_mode == Control.FOCUS_NONE)
	assert(not viewer.left_edit.editable)
	assert(viewer.right_edit.editable)
	assert(viewer.split_container.split_offset == 0)
	assert(viewer.content_panel.offset_left == -ControlSize.border_xs)
	assert(viewer.content_panel.offset_top == -ControlSize.border_xs)
	assert(viewer.content_panel.offset_right == ControlSize.border_xs)
	assert(viewer.content_panel.offset_bottom == ControlSize.border_xs)
	viewer.free()
	pass


static func code_highlighter_recognizes_gdscript_test() -> void:
	var highlighter := GitCodeHighlighter.create("scripts/player.gd")
	assert(highlighter.get_keyword_color("func").a > 0.0)
	assert(highlighter.get_keyword_color("Vector2").a > 0.0)
	assert(highlighter.has_color_region("#"))
	pass


func diff_viewer_applies_file_highlighter_test() -> void:
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


func diff_viewer_maps_lines_across_hunks_test() -> void:
	var viewer := GitDiffViewer.new()
	var hunk := GitDiffParser.DiffHunk.new(3, 2, 3, 4)
	hunk.old_lines = PackedInt32Array([3, 4])
	hunk.new_lines = PackedInt32Array([3, 4, 5, 6])
	viewer.displayed_hunks = [hunk]
	assert(viewer.map_diff_line(1.0, true) == 1.0)
	assert(viewer.map_diff_line(2.0, true) == 2.0)
	assert(viewer.map_diff_line(4.0, true) == 6.0)
	assert(viewer.map_diff_line(6.0, false) == 4.0)
	viewer.free()
	pass


func diff_viewer_hunk_navigation_moves_caret_test() -> void:
	var viewer := GitDiffViewer.new()
	viewer.right_edit.text = "one\ntwo\nthree\nfour\nfive"
	viewer.displayed_hunks = [GitDiffParser.DiffHunk.new(2, 1, 4, 1)]
	viewer.select_relative_hunk(1)
	assert(viewer.right_edit.get_caret_line() == 3)
	assert(viewer.right_edit.get_caret_column() == 0)
	viewer.free()
	pass


static func diff_viewer_reverts_one_hunk_test() -> void:
	var old_text := "same\nold one\nold two\ntail\nlater old\nend"
	var new_text := "same\nnew one\nnew two\nnew three\ntail\nlater new\nend"
	var first_hunk := GitDiffParser.DiffHunk.new(2, 2, 2, 3)
	var reverted := GitDiffViewer.revert_hunk_text(old_text, new_text, first_hunk)
	assert(reverted == "same\nold one\nold two\ntail\nlater new\nend")
	pass


static func diff_viewer_reverts_insert_and_delete_hunks_test() -> void:
	var insertion := GitDiffParser.DiffHunk.new(1, 0, 2, 1)
	assert(GitDiffViewer.revert_hunk_text("a\nb", "a\ninserted\nb", insertion) == "a\nb")
	var deletion := GitDiffParser.DiffHunk.new(2, 1, 1, 0)
	assert(GitDiffViewer.revert_hunk_text("a\nrestored\nb", "a\nb", deletion) == "a\nrestored\nb")
	pass


func diff_viewer_revert_restores_left_snapshot_test() -> void:
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
