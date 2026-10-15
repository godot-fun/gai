## Git unified-patch parser tests.

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


static func parse_crlf_default_counts_and_no_newline_marker_test() -> void:
	var patch := "@@ -7 +7 @@\r\n-old\r\n+new\r\n\\ No newline at end of file\r\n"
	var parsed := GitDiffParser.parse(patch)
	assert(parsed.hunks.size() == 1)
	assert(parsed.hunks[0].old_start == 7)
	assert(parsed.hunks[0].old_count == 1)
	assert(parsed.hunks[0].new_start == 7)
	assert(parsed.hunks[0].new_count == 1)
	assert(parsed.changed_lines.old_lines == [7])
	assert(parsed.changed_lines.new_lines == [7])
	pass


static func parse_context_advances_both_sides_test() -> void:
	var patch := """@@ -10,4 +20,4 @@
 context
-old
+new
 tail
"""
	var changed := GitDiffParser.parse(patch).changed_lines
	assert(changed.old_lines == [11])
	assert(changed.new_lines == [21])
	pass


static func parse_empty_and_header_only_input_test() -> void:
	var empty := GitDiffParser.parse("")
	assert(empty.hunks.is_empty())
	assert(empty.changed_lines.old_lines.is_empty())
	assert(empty.changed_lines.new_lines.is_empty())
	var header_only := GitDiffParser.parse("diff --git a/a.gd b/a.gd\n--- a/a.gd\n+++ b/a.gd\n")
	assert(header_only.hunks.is_empty())
	assert(header_only.changed_lines.old_lines.is_empty())
	assert(header_only.changed_lines.new_lines.is_empty())
	pass


static func parse_pure_insert_and_delete_hunks_test() -> void:
	var patch := """@@ -3,0 +4,2 @@
+first
+second
@@ -10,2 +12,0 @@
-third
-fourth
"""
	var parsed := GitDiffParser.parse(patch)
	assert(parsed.hunks.size() == 2)
	assert(parsed.hunks[0].old_count == 0)
	assert(parsed.hunks[0].new_count == 2)
	assert(parsed.hunks[1].old_count == 2)
	assert(parsed.hunks[1].new_count == 0)
	assert(parsed.changed_lines.old_lines == [10, 11])
	assert(parsed.changed_lines.new_lines == [4, 5])
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


static func extract_added_deleted_and_renamed_file_patches_test() -> void:
	var patch := """diff --git a/old.gd b/new.gd
similarity index 100%
rename from old.gd
rename to new.gd
diff --git a/created.gd b/created.gd
new file mode 100644
--- /dev/null
+++ b/created.gd
@@ -0,0 +1 @@
+created
diff --git a/removed.gd b/removed.gd
deleted file mode 100644
--- a/removed.gd
+++ /dev/null
@@ -1 +0,0 @@
-removed
"""
	var renamed_from := GitDiffParser.extract_file_patch(patch, "old.gd")
	var renamed_to := GitDiffParser.extract_file_patch(patch, "new.gd")
	assert(renamed_from == renamed_to)
	assert(renamed_from.contains("rename from old.gd"))
	assert(GitDiffParser.extract_file_patch(patch, "created.gd").contains("+created"))
	assert(GitDiffParser.extract_file_patch(patch, "removed.gd").contains("-removed"))
	pass


static func extract_file_patch_normalizes_windows_path_test() -> void:
	var patch := "diff --git a/folder/demo.gd b/folder/demo.gd\n--- a/folder/demo.gd\n+++ b/folder/demo.gd\n@@ -1 +1 @@\n-old\n+new\n"
	assert(GitDiffParser.extract_file_patch(patch, r"folder\demo.gd").contains("+new"))
	pass
