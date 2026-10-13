class_name GitDiffParser
extends Object

## Parses the line locations from a unified Git patch. Full source text is stored separately in the
## diff bundle; the patch is used only to paint changed lines in the two CodeEdit panes.

static var hunk_regex: RegEx


static func _static_init() -> void:
	hunk_regex = RegEx.new()
	hunk_regex.compile("^@@ -([0-9]+)(?:,[0-9]+)? \\+([0-9]+)(?:,[0-9]+)? @@")
	pass


static func changed_lines(file_patch: String) -> Dictionary:
	var old_lines := PackedInt32Array()
	var new_lines := PackedInt32Array()
	var old_line := 0
	var new_line := 0
	var in_hunk := false
	for raw_line in FileUtils.normalize_line_endings_to_lf(file_patch).split(FileUtils.NEWLINE_LF, true):
		var match := hunk_regex.search(raw_line)
		if match != null:
			old_line = int(match.get_string(1))
			new_line = int(match.get_string(2))
			in_hunk = true
			continue
		if not in_hunk or raw_line.is_empty():
			continue
		var marker := raw_line[0]
		if marker == " ":
			old_line += 1
			new_line += 1
		elif marker == "-":
			old_lines.append(old_line)
			old_line += 1
		elif marker == "+":
			new_lines.append(new_line)
			new_line += 1
		elif marker != "\\":
			in_hunk = false
	return {"old": old_lines, "new": new_lines}


static func extract_file_patch(patch: String, relative_path: String) -> String:
	var normalized_path := relative_path.replace("\\", "/")
	for section in FileUtils.normalize_line_endings_to_lf(patch).split("diff --git ", false):
		var candidate := "diff --git " + section
		if candidate.begins_with("diff --git a/" + normalized_path + " b/" + normalized_path + FileUtils.NEWLINE_LF) \
				or candidate.contains(FileUtils.NEWLINE_LF + "--- a/" + normalized_path + FileUtils.NEWLINE_LF) \
				or candidate.contains(FileUtils.NEWLINE_LF + "+++ b/" + normalized_path + FileUtils.NEWLINE_LF) \
				or candidate.contains(FileUtils.NEWLINE_LF + "rename from " + normalized_path + FileUtils.NEWLINE_LF) \
				or candidate.contains(FileUtils.NEWLINE_LF + "rename to " + normalized_path + FileUtils.NEWLINE_LF):
			return candidate
	return StringUtils.EMPTY

