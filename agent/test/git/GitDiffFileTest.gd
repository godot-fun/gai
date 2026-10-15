## Cached diff file model tests.

static func display_path_and_editability_test() -> void:
	var file := GitDiffFile.new()
	file.old_path = "before.gd"
	file.new_path = "after.gd"
	assert(file.display_path() == "after.gd")
	assert(file.can_edit())
	file.binary = true
	assert(not file.can_edit())
	file.binary = false
	file.new_path = ""
	assert(file.display_path() == "before.gd")
	assert(not file.can_edit())
	pass


static func deleted_file_is_not_editable_test() -> void:
	var file := GitDiffFile.new()
	file.old_path = "deleted.gd"
	file.new_path = ""
	file.status = GitDiffFile.STATUS_DELETED
	assert(not file.can_edit())
	pass


static func added_and_modified_text_files_are_editable_test() -> void:
	for status in [GitDiffFile.STATUS_ADDED, GitDiffFile.STATUS_MODIFIED]:
		var file := GitDiffFile.new()
		file.new_path = "current.gd"
		file.status = status
		assert(file.can_edit())
	pass


static func changed_lines_are_independent_per_file_test() -> void:
	var first := GitDiffFile.new()
	var second := GitDiffFile.new()
	first.changed_lines.old_lines.append(3)
	assert(first.changed_lines.old_lines == [3])
	assert(second.changed_lines.old_lines.is_empty())
	pass
