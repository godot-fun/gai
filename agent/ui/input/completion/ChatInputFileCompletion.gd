class_name ChatInputFileCompletion
extends ChatInputCompletionProvider

## `@path` file references for the composer list.
##
## An `@` that opens a word starts a mention (`@agent/ui`, `@SKILL.md`) and the rows come from the
## workspace, minus the folders [member GitIgnore.ignore_rules] hides. Folders end in `/` so accepting
## one drills into it; files become the same Markdown link the drop and clipboard paths produce
## ([method MarkdownHelper.format_file_as_markdown]), so bubbles and the agent see one shape no matter
## how the file got in.

const MENTION := "@"
const DIRECTORY_SUFFIX := "/"
const DISPLAY_SEPARATOR := "  ·  "
## Rows handed to one list; the popup scrolls through [constant ChatInputCompletion.POPUP_ROWS] at a time.
const MAX_OPTIONS: int = 200
## Scan cap, so a stray huge folder costs one bounded walk on the first `@` instead of a freeze.
const MAX_ENTRIES: int = 20000
## Characters that end a mention. ASCII `:` stays out so a `@C:/...` drive letter survives; whitespace
## is handled by code point and every bracket, quote and CJK punctuation closes the token.
const TOKEN_BREAKS := ",;!?()[]{}<>\"'，。；：！？、（）【】「」《》“”‘’"

## One path a mention can name: a folder ([member path] keeps its trailing `/`) or a file, both
## relative to the indexed root. [member name] is the last path segment, so the row text can start with
## it and the popup's end ellipsis never eats the part that tells two same-named files apart.
class MentionPath extends RefCounted:
	var path: String = ""
	var name: String = ""
	var dir: bool = false

	func _init(entry_path: String = "", entry_dir: bool = false) -> void:
		path = entry_path
		dir = entry_dir
		name = entry_path.trim_suffix(ChatInputFileCompletion.DIRECTORY_SUFFIX).get_file()
		pass

	## Folders keep the trailing `/`, which is what makes an accepted row drill into them rather than
	## close the mention with a link.
	static func folder(entry_path: String) -> MentionPath:
		return MentionPath.new(entry_path, true)

	static func file(entry_path: String) -> MentionPath:
		return MentionPath.new(entry_path, false)


## Absolute folder to list; empty means the workspace root. Tests point this at a scratch folder.
var root_override: String = ""
var indexed_root: String = ""
var entries: Array[MentionPath] = []
var indexed: bool = false


func is_active() -> bool:
	return mention_start(caret_prefix()) >= 0


func build_options() -> Array[ChatInputCompletionProvider.CompletionRow]:
	refresh_index()
	var options: Array[ChatInputCompletionProvider.CompletionRow] = []
	var matches: Array[MentionPath] = matching_entries(entries, query(), MAX_OPTIONS)
	for entry: MentionPath in matches:
		options.append(ChatInputCompletionProvider.CompletionRow.create(
			build_display_text(entry), build_insert_text(entry)))
	return options


## The whole `@token` is replaced. Live tokens keep the mention open (`@agent/` drills into the next
## level) and files close it with the Markdown link plus a blank.
func token_span() -> Vector2i:
	var line: String = input_field.get_line(input_field.get_caret_line())
	var caret_column: int = input_field.get_caret_column()
	var start: int = mention_start(line.substr(0, caret_column))
	if start < 0:
		return Vector2i(-1, -1)
	return Vector2i(start, token_end(line, caret_column))


## What the user typed after the `@`, with no separator normalization — matching lowercases it.
func query() -> String:
	var prefix: String = caret_prefix()
	var start: int = mention_start(prefix)
	if start < 0:
		return StringUtils.EMPTY
	return prefix.substr(start + MENTION.length())


func caret_prefix() -> String:
	var line: String = input_field.get_line(input_field.get_caret_line())
	return line.substr(0, input_field.get_caret_column())


## Column where the `@` of the mention under the caret sits, or -1 when the caret is not in one.
## The token must be one unbroken run for the caret (`@agent/ui`), and its `@` either opens that run or
## follows a CJK character — Chinese is typed without a blank before a reference. An ASCII word keeps
## its `@` for itself, so `mail@example.com` stays text, while `请看@agent/` still opens the list.
static func mention_start(prefix: String) -> int:
	var start: int = prefix.length()
	while start > 0 and not is_token_break(prefix.unicode_at(start - 1)):
		start -= 1
	var token := prefix.substr(start)
	var mention_at := token.rfind(MENTION)
	if mention_at < 0:
		return -1
	if mention_at > 0 and token.unicode_at(mention_at - 1) < 128:
		return -1
	return start + mention_at


## Column after the last mention character, used on accept so a caret parked in the middle of
## `@agent|/ui` still leaves a single clean reference behind.
static func token_end(line: String, caret_column: int) -> int:
	var end: int = caret_column
	while end < line.length() and not is_token_break(line.unicode_at(end)):
		end += 1
	return end


static func is_token_break(code: int) -> bool:
	if code <= 32:
		return true
	return TOKEN_BREAKS.contains(String.chr(code))


## Prefix matches first, then rows whose name starts with the query, then anything containing it — the
## same widening order as [method ChatInputSkillCompletion.matching_summaries]. Inside a bucket the
## shallowest path wins, so `@not` offers `notes.md` before `docs/notes.md`, and the folder just drilled
## into is left out because its whole path is the query.
static func matching_entries(entries: Array[MentionPath], query_text: String, limit: int = MAX_OPTIONS) -> Array[MentionPath]:
	var needle := query_text.strip_edges().replace("\\", "/").to_lower()
	if needle.is_empty():
		# Browsing, not searching: the alphabetical index head is the top of the tree.
		return entries.slice(0, limit)
	var name_needle := needle.substr(needle.rfind("/") + 1)
	var prefix_matches: Array[MentionPath] = []
	var name_matches: Array[MentionPath] = []
	var loose_matches: Array[MentionPath] = []
	for entry: MentionPath in entries:
		var path := entry.path.to_lower()
		if path == needle:
			continue
		if path.begins_with(needle):
			prefix_matches.append(entry)
		elif not name_needle.is_empty() and entry.name.to_lower().begins_with(name_needle):
			name_matches.append(entry)
		elif path.contains(needle):
			loose_matches.append(entry)
	var matches: Array[MentionPath] = []
	for bucket: Array[MentionPath] in [prefix_matches, name_matches, loose_matches]:
		bucket.sort_custom(entry_order_before)
		for entry: MentionPath in bucket:
			if matches.size() >= limit:
				return matches
			matches.append(entry)
	return matches


## File name first so the popup's end ellipsis never eats it, folder second for orientation.
static func build_display_text(entry: MentionPath) -> String:
	var suffix := DIRECTORY_SUFFIX if entry.dir else StringUtils.EMPTY
	var parent := entry.path.trim_suffix(DIRECTORY_SUFFIX).get_base_dir()
	if parent.is_empty() or parent == ".":
		return entry.name + suffix
	return StringUtils.format("{}{}{}{}", entry.name, suffix, DISPLAY_SEPARATOR, parent + DIRECTORY_SUFFIX)


func build_insert_text(entry: MentionPath) -> String:
	if entry.dir:
		return MENTION + entry.path
	return MarkdownHelper.format_file_as_markdown(indexed_root.path_join(entry.path)) + " "


## Shallowest first, then alphabetical: a root file beats the same name nested in a folder.
static func entry_order_before(left: MentionPath, right: MentionPath) -> bool:
	if left.path.length() != right.path.length():
		return left.path.length() < right.path.length()
	return left.path < right.path


## Workspace-relative [member entries], sorted by path so rows stay stable. [method GlobUtils.glob] walks
## [member indexed_root] with directories on — folders keep their trailing `/`, matching agent glob/grep
## — and [member GitIgnore.ignore_rules] as skip rules. [constant MAX_ENTRIES] caps the walk; breadth-first
## order keeps the shallowest paths.
func refresh_index() -> void:
	var root := resolve_root()
	if indexed and root == indexed_root:
		return
	indexed_root = root
	entries = []
	if root.is_empty():
		indexed = true
		return
	var root_prefix := root.replace("\\", "/")
	root_prefix = root_prefix if root_prefix.ends_with(DIRECTORY_SUFFIX) else root_prefix + DIRECTORY_SUFFIX
	var paths := GlobUtils.glob(root, StringUtils.EMPTY, true, 0, GitIgnore.ignore_rules, true, MAX_ENTRIES)
	for path: String in paths:
		var relative := path.replace("\\", "/").substr(root_prefix.length())
		entries.append(MentionPath.folder(relative) if relative.ends_with(DIRECTORY_SUFFIX) else MentionPath.file(relative))
	indexed = true
	pass


func resolve_root() -> String:
	if not root_override.is_empty():
		return FileUtils.normalize_path(root_override)
	return AgentWorkspace.get_root()
