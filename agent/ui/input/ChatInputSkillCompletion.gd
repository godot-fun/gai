class_name ChatInputSkillCompletion
extends RefCounted

## `/skill` completion for the chat composer. [CodeEdit]'s built-in completion list owns the popup,
## keyboard handling and insertion; this class decides when the popup belongs to a slash command and
## feeds it the [SkillManager] index. Skill parsing itself lives in [SkillManager].

const DISPLAY_SEPARATOR := "  ·  "
## Rows the list tries to show at once; the composer is grown to match while it is open.
const POPUP_ROWS: int = 8

var input_field: CodeEdit


func setup(p_input_field: CodeEdit) -> void:
	input_field = p_input_field
	input_field.code_completion_enabled = true
	input_field.code_completion_prefixes = completion_prefixes()
	input_field.code_completion_requested.connect(on_code_completion_requested)
	pass


## Every ASCII punctuation mark breaks the engine's completion word, and the list is cancelled when the
## caret sits right after such a break unless the character is a declared prefix — which is what hid
## `/audio-` in the first place. Declaring all of them keeps `/name-`, `/name.`, … alive for any future
## skill name; [method is_slash_command] still decides whether the list may show at all.
static func completion_prefixes() -> Array[String]:
	var prefixes: Array[String] = []
	for code in range(33, 127):
		if is_ascii_symbol(code):
			prefixes.append(String.chr(code))
	return prefixes


## Typing decides visibility: a `/` token opens the list, anything else closes it. The list is
## rebuilt on every keystroke because rows are pre-filtered by skill name — the engine only sees
## rows that already match, so their descriptions cannot widen the match by accident.
func refresh_on_text_change() -> void:
	if not is_slash_command():
		input_field.cancel_code_completion()
		return
	input_field.request_code_completion(true)
	pass


## True while the caret sits in a `/` token that starts the current line, e.g. `/audio-tr|`.
## A blank after the command means the argument phase started, so the list stays closed.
func is_slash_command() -> bool:
	var token: String = current_token()
	if not token.begins_with("/"):
		return false
	return not token.contains(" ") and not token.contains("\t")


## The text between the start of the caret line and the caret, left-trimmed only.
## Trailing blanks stay on purpose: after an accepted option the field reads `/audio-trim `, and
## stripping that space made the token look like a live command, which reopened the list and made
## the next Enter insert the same skill again.
func current_token() -> String:
	var line: int = input_field.get_caret_line()
	return input_field.get_line(line).substr(0, input_field.get_caret_column()).strip_edges(true, false)


func on_code_completion_requested() -> void:
	# Ctrl+Space and plain word typing also request completion; keep the list to slash commands.
	if not is_slash_command():
		input_field.cancel_code_completion()
		return
	var token := current_token().to_lower()
	for summary: SkillSummary in matching_summaries(SkillManager.get_summaries(), token):
		var insert_text := completion_insert_text(summary.name.to_lower(), token)
		if insert_text.is_empty():
			continue
		input_field.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT,
			build_display_text(summary), insert_text, Colors.primary_text)
	input_field.update_code_completion_options(false)
	pass


## Text to insert for [param name] so the field ends up as `/name `. [CodeEdit] keeps everything before
## its own completion base and replaces only that base, so we hand over just the remainder: on
## `/audio-t` it replaces `t`, and inserting `rim ` yields `/audio-trim `. Returns empty when the typed
## token disagrees with the name before the base, where keep/replace cannot produce `/name `.
static func completion_insert_text(name: String, token: String) -> String:
	var target := StringUtils.format("/{} ", name)
	var offset := token.length() - completion_base_length(token)
	if not target.begins_with(token.substr(0, offset)):
		return StringUtils.EMPTY
	return target.substr(offset)


## Length of the trailing run [CodeEdit] treats as the completion base and replaces on accept. Godot
## walks back while the character is above a space and is either `/` or not a symbol, where a symbol is
## ASCII punctuation except `_` (see `char_utils.h`; `text_edit.cpp` uses it for the same walk).
## So `/audio-t` only owns `t`, `/audio-to-w` owns `w`, and `/audio-` owns nothing.
static func completion_base_length(token: String) -> int:
	var start := token.length()
	while start > 0:
		var code := token.unicode_at(start - 1)
		if code <= 32 or (code != 47 and is_ascii_symbol(code)):
			break
		start -= 1
	return token.length() - start


## ASCII punctuation, which the engine splits words on; `_` stays a word character.
static func is_ascii_symbol(code: int) -> bool:
	if code == 95:
		return false
	return (code >= 33 and code <= 47) or (code >= 58 and code <= 64) \
		or (code >= 91 and code <= 96) or (code >= 123 and code <= 126)


## Skill names that start with [param token]; names that merely contain it are the fallback, so
## `/trim` still finds `audio-trim`. Prefix-first is a popup preference, not a skill fact, which is
## why it lives here instead of in [SkillManager].
static func matching_summaries(summaries: Array[SkillSummary], token: String) -> Array[SkillSummary]:
	var prefix_matches: Array[SkillSummary] = []
	var loose_matches: Array[SkillSummary] = []
	var needle := token.trim_prefix("/")
	for summary: SkillSummary in summaries:
		var name := summary.name.to_lower()
		if ("/" + name).begins_with(token):
			prefix_matches.append(summary)
		elif name.contains(needle):
			loose_matches.append(summary)
	return prefix_matches if not prefix_matches.is_empty() else loose_matches


static func build_display_text(summary: SkillSummary) -> String:
	if summary.description.is_empty():
		return StringUtils.format("/{}", summary.name)
	return StringUtils.format("/{}{}{}", summary.name, DISPLAY_SEPARATOR, summary.description)


## True while the list is on screen, i.e. CodeEdit has options after filtering.
func is_popup_open() -> bool:
	return input_field.get_code_completion_selected_index() >= 0


## Height the composer needs while the list is open. CodeEdit draws its list inside its own rect,
## so a short composer would only fit one or two rows; the extra rows keep the list readable.
func get_popup_height() -> float:
	var rows: int = clampi(input_field.get_code_completion_options().size(), 1, POPUP_ROWS)
	return input_field.get_line_height() * (rows + 2) + Margin.ma_6
