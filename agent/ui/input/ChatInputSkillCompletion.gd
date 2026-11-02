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
	input_field.code_completion_prefixes = ["/"]
	input_field.code_completion_requested.connect(on_code_completion_requested)
	pass


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
func is_slash_command() -> bool:
	var token: String = current_token()
	if not token.begins_with("/"):
		return false
	return not token.contains(" ") and not token.contains("\t")


## The text between the start of the caret line and the caret, without surrounding blanks.
func current_token() -> String:
	var line: int = input_field.get_caret_line()
	return input_field.get_line(line).substr(0, input_field.get_caret_column()).strip_edges()


func on_code_completion_requested() -> void:
	# Ctrl+Space and plain word typing also request completion; keep the list to slash commands.
	if not is_slash_command():
		input_field.cancel_code_completion()
		return
	for summary: SkillSummary in matching_summaries(SkillManager.get_summaries(), current_token().to_lower()):
		input_field.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT,
			build_display_text(summary), StringUtils.format("/{} ", summary.name), Colors.primary_text)
	input_field.update_code_completion_options(false)
	pass


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
