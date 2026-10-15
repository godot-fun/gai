## Git unified-patch parsing and cached file model tests.

static func parse_changed_lines_test() -> void:
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
	var changed := GitDiffParser.parse(patch).changed_lines
	assert(changed.old_lines == [3, 4])
	assert(changed.new_lines == [3, 4, 5])
	pass


static func parse_hunks_and_lines_test() -> void:
	var patch := """@@ -3,2 +3,3 @@
-old one
-old two
+new one
+new two
+new three
@@ -12,0 +14,1 @@
+inserted
"""
	var parsed := GitDiffParser.parse(patch)
	var hunks := parsed.hunks
	assert(hunks.size() == 2)
	assert(hunks[0].old_start == 3)
	assert(hunks[0].old_count == 2)
	assert(hunks[0].new_count == 3)
	assert(hunks[1].old_count == 0)
	assert(hunks[1].new_start == 14)
	assert(parsed.changed_lines.old_lines == [3, 4])
	assert(parsed.changed_lines.new_lines == [3, 4, 5, 14])
	pass


static func git_diff_texts_test() -> void:
	if not GitHelper.is_git_installed():
		return
	var result := await GitHelper.async_diff_texts("same\nold\ntail", "same\nnew\ntail")
	assert(result.exit_code == 1)
	var changed := GitDiffParser.parse(result.output.build_string()).changed_lines
	assert(changed.old_lines == [2])
	assert(changed.new_lines == [2])
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
	var section := GitDiffParser.extract_file_patch(patch, r"folder\second file.gd")
	assert(section.begins_with("diff --git a/folder/second file.gd"))
	assert(section.contains("+right"))
	assert(not section.contains("+new"))
	assert(GitDiffParser.extract_file_patch(patch, "missing.gd").is_empty())
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


static func code_highlighter_recognizes_gdscript_test() -> void:
	var highlighter := GitCodeHighlighter.create("scripts/player.gd")
	assert(highlighter.get_keyword_color("func").a > 0.0)
	assert(highlighter.get_keyword_color("pass") == CodeColors.keyword)
	assert(highlighter.get_keyword_color("Vector2").a > 0.0)
	assert(highlighter.get_keyword_color("PackedVector4Array") == CodeColors.type)
	assert(highlighter.get_keyword_color("PI") == CodeColors.type)
	assert(highlighter.get_keyword_color("@export_range") == CodeColors.declaration)
	assert(highlighter.get_keyword_color("@abstract") == CodeColors.declaration)
	assert(highlighter.get_keyword_color("@export_tool_button") == CodeColors.declaration)
	assert(highlighter.has_color_region("#"))
	assert(highlighter.has_color_region('&"'))
	assert(highlighter.has_color_region('^"'))
	pass


static func code_highlighter_recognizes_extended_languages_test() -> void:
	var shader := GitCodeHighlighter.create("effects/water.gdshader")
	assert(shader.get_keyword_color("shader_type") == CodeColors.declaration)
	assert(shader.get_keyword_color("sampler2D") == CodeColors.type)
	var sql := GitCodeHighlighter.create("schema.sql")
	assert(sql.get_keyword_color("SELECT") == CodeColors.keyword)
	assert(sql.has_color_region("--"))
	var typescript := GitCodeHighlighter.create("app.ts")
	assert(typescript.get_keyword_color("satisfies") == CodeColors.keyword)
	assert(typescript.get_keyword_color("type") == CodeColors.keyword)
	assert(typescript.get_keyword_color("infer") == CodeColors.keyword)
	assert(typescript.has_color_region("`"))
	assert(not typescript.has_color_region("#"))
	var jsx := GitCodeHighlighter.create("Button.tsx")
	assert(jsx.has_color_region("<"))
	var markdown := GitCodeHighlighter.create("README.md")
	assert(markdown.has_color_region("```"))
	assert(markdown.has_color_region("#"))
	assert(markdown.has_color_region("**"))
	assert(markdown.has_color_region("~~"))
	assert(markdown.has_color_region("<"))
	assert(markdown.get_keyword_color("NOTE") == CodeColors.declaration)
	var mdx := GitCodeHighlighter.create("docs/page.mdx")
	assert(mdx.has_color_region("`"))
	assert(mdx.has_color_region("<"))
	var sconstruct := GitCodeHighlighter.create("SConstruct")
	assert(sconstruct.get_keyword_color("lambda") == CodeColors.keyword)
	assert(sconstruct.has_color_region("#"))
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
