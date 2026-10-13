class_name GitDiffParser
extends Object

## Parses line locations from unified patches produced by Git.

class DiffHunk extends RefCounted:
	var old_start: int
	var old_count: int
	var new_start: int
	var new_count: int

	func _init(p_old_start: int = 0, p_old_count: int = 0, p_new_start: int = 0, p_new_count: int = 0) -> void:
		old_start = p_old_start
		old_count = p_old_count
		new_start = p_new_start
		new_count = p_new_count
		pass


class ChangedLines extends RefCounted:
	var old_lines: Array[int]
	var new_lines: Array[int]

	func _init(p_old_lines: Array[int] = [], p_new_lines: Array[int] = []) -> void:
		old_lines = p_old_lines
		new_lines = p_new_lines
		pass


class ParsedDiff extends RefCounted:
	var hunks: Array[DiffHunk]
	var changed_lines: ChangedLines

	func _init(p_hunks: Array[DiffHunk], p_changed_lines: ChangedLines) -> void:
		hunks = p_hunks
		changed_lines = p_changed_lines
		pass

static var hunk_regex: RegEx


static func _static_init() -> void:
	hunk_regex = RegEx.new()
	hunk_regex.compile("^@@ -([0-9]+)(?:,([0-9]+))? \\+([0-9]+)(?:,([0-9]+))? @@")
	pass


## Parses hunk geometry and one-based changed line numbers in one pass. Header markers (`---` /
## `+++`) are outside hunks and therefore never get mistaken for deleted/added source lines.
static func parse(file_patch: String) -> ParsedDiff:
	var hunks: Array[DiffHunk] = []
	var old_changed_lines: Array[int] = []
	var new_changed_lines: Array[int] = []
	var current: DiffHunk
	var old_line := 0
	var new_line := 0
	for raw_line in FileUtils.normalize_line_endings_to_lf(file_patch).split(FileUtils.NEWLINE_LF, true):
		var match := hunk_regex.search(raw_line)
		if match != null:
			if current != null:
				hunks.append(current)
			old_line = int(match.get_string(1))
			new_line = int(match.get_string(3))
			current = DiffHunk.new(
				old_line, 1 if match.get_string(2).is_empty() else int(match.get_string(2)),
				new_line, 1 if match.get_string(4).is_empty() else int(match.get_string(4)))
			continue
		if current == null or raw_line.is_empty():
			continue
		var marker := raw_line[0]
		# Context advances both cursors; deletion/addition advances only its corresponding side.
		if marker == " ":
			old_line += 1
			new_line += 1
		elif marker == "-":
			old_changed_lines.append(old_line)
			old_line += 1
		elif marker == "+":
			new_changed_lines.append(new_line)
			new_line += 1
		elif marker != "\\":
			hunks.append(current)
			current = null
	if current != null:
		hunks.append(current)
	return ParsedDiff.new(hunks, ChangedLines.new(old_changed_lines, new_changed_lines))


## Extracts one `diff --git` section. Checking file markers and rename metadata covers additions,
## deletions, and renames where the two paths in the section header are not identical.
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
