class_name SkillManager
extends Object

## Skill index for `.agents/skills`: one [SkillSummary] per skill folder, parsed from its `SKILL.md`
## front matter. Pure data — matching, ordering for a popup, and prompt text live elsewhere.

const SKILL_DIR := ".agents/skills"
const SKILL_FILE := "SKILL.md"
const FRONT_MATTER_DELIMITER := "---"
## YAML marks that make `description` continue on the following indented lines.
const BLOCK_SCALAR_MARKS: Array[String] = [">", ">-", ">+", "|", "|-", "|+"]
## Skill rows and prompts are single-line, so descriptions are cut to this many characters.
const MAX_DESCRIPTION_LENGTH: int = 56

## Cached summaries sorted by name, plus the disk state they were read from.
static var summaries: Array[SkillSummary] = []
static var loaded_root: String = ""
static var loaded_signature: String = ""


## Skill summaries sorted by name. Rescans when the workspace root or the skill folders on disk
## changed, so a skill added, renamed, or edited while the app runs appears on the next completion
## request without any file-system watcher.
static func get_summaries() -> Array[SkillSummary]:
	var root := AgentWorkspace.resolve_path(SKILL_DIR)
	if is_stale(root, FileUtils.get_all_directories_in_folder(root)):
		load_summaries(root)
	return summaries


## True when the cached index no longer matches the disk. Extracted so tests can point it at a
## temporary folder instead of the workspace.
static func is_stale(root: String, folders: Array[String]) -> bool:
	return root != loaded_root or build_signature(folders) != loaded_signature


## Cheap disk fingerprint: folder names plus each `SKILL.md` mtime. Adding or renaming a folder
## changes the name list; editing a description changes its mtime. Godot reports mtime in whole
## seconds, so a second edit inside the same second is only noticed by a later change.
static func build_signature(folders: Array[String]) -> String:
	# Directory listing order is not guaranteed, so sort to keep the fingerprint canonical.
	var sorted: Array[String] = folders.duplicate()
	sorted.sort()
	var builder := StringBuilder.new()
	for folder: String in sorted:
		builder.append(StringUtils.format("{}:{}", folder.get_file(), FileAccess.get_modified_time(folder.path_join(SKILL_FILE))))
	return builder.build_joined("|")


## Rebuilds [member summaries] from the skill folders under [param root] and caches their fingerprint.
static func load_summaries(root: String) -> void:
	var folders := FileUtils.get_all_directories_in_folder(root)
	loaded_root = root
	loaded_signature = build_signature(folders)
	summaries.clear()
	for folder: String in folders:
		var summary := load_summary(folder.path_join(SKILL_FILE), folder.get_file())
		if summary != null:
			summaries.append(summary)
	summaries.sort_custom(func(a: SkillSummary, b: SkillSummary) -> bool: return a.name < b.name)
	pass


## A skill folder without readable front matter still shows up, named after its folder.
## Returns null when neither the file nor the folder name yields a usable name.
static func load_summary(path: String, fallback_name: String) -> SkillSummary:
	if not FileAccess.file_exists(path):
		return null
	var front_matter := parse_front_matter(FileUtils.read_file_to_string(path))
	var name := String(front_matter.get("name", "")).strip_edges()
	if name.is_empty():
		name = fallback_name
	if name.is_empty():
		return null
	return SkillSummary.new(name, summarize(String(front_matter.get("description", ""))))


## Reads the `key: value` pairs between the first two `---` lines of a `SKILL.md`. Folded (`>-`)
## and literal (`|`) block scalars are joined into one line: rows are single-line only.
static func parse_front_matter(text: String) -> Dictionary[String, String]:
	var front_matter: Dictionary[String, String] = {}
	var lines := FileUtils.normalize_line_endings_to_lf(text).split(FileUtils.NEWLINE_LF)
	if lines.is_empty() or lines[0].strip_edges() != FRONT_MATTER_DELIMITER:
		return front_matter
	var index := 1
	while index < lines.size() and lines[index].strip_edges() != FRONT_MATTER_DELIMITER:
		var separator := lines[index].find(":")
		if separator <= 0:
			index += 1
			continue
		var key := lines[index].substr(0, separator).strip_edges()
		var value := lines[index].substr(separator + 1).strip_edges()
		index += 1
		if value in BLOCK_SCALAR_MARKS:
			var block: Array[String] = []
			while index < lines.size() and is_block_scalar_line(lines[index]):
				block.append(lines[index].strip_edges())
				index += 1
			value = " ".join(PackedStringArray(block)).strip_edges()
		front_matter[key] = value
	return front_matter


## Block scalar continuation: an indented line, including the indented blank lines inside it.
static func is_block_scalar_line(line: String) -> bool:
	return line.is_empty() or line.begins_with(" ") or line.begins_with("\t")


## First sentence only, cut at a word boundary: one line of room in skill rows and prompts.
static func summarize(description: String) -> String:
	var sentence_end := description.find(". ")
	var summary := description.substr(0, sentence_end) if sentence_end > 0 else description
	if summary.length() > MAX_DESCRIPTION_LENGTH:
		summary = summary.left(MAX_DESCRIPTION_LENGTH - 1)
		var last_space := summary.rfind(" ")
		if last_space > 0:
			summary = summary.left(last_space)
		summary += "…"
	return summary
