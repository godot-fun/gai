class_name ChatInputSkillCompletion
extends ChatInputCompletionProvider

## `/skill` rows for the composer list. [ChatInputCompletion] owns the popup; this class decides when
## the caret commands a slash command and which skills the row list offers. Skill parsing itself lives
## in [SkillManager].

const DISPLAY_SEPARATOR := "  ·  "


## True while the caret sits in a `/` token that starts the current line, e.g. `/audio-tr|`.
## A blank after the command means the argument phase started, so the list stays closed.
func is_active() -> bool:
	var token: String = current_token()
	return token.begins_with("/") and not token.contains(" ") and not token.contains("\t")


## The text between the start of the caret line and the caret, left-trimmed only.
## Trailing blanks stay on purpose: after an accepted option the field reads `/audio-trim `, and
## stripping that space made the token look like a live command, which reopened the list and made
## the next Enter insert the same skill again.
func current_token() -> String:
	var line: int = input_field.get_caret_line()
	return input_field.get_line(line).substr(0, input_field.get_caret_column()).strip_edges(true, false)


func build_options() -> Array[ChatInputCompletionProvider.CompletionRow]:
	var options: Array[ChatInputCompletionProvider.CompletionRow] = []
	var summaries: Array[SkillSummary] = matching_summaries(SkillManager.get_summaries(), current_token().to_lower())
	for summary: SkillSummary in summaries:
		options.append(ChatInputCompletionProvider.CompletionRow.new(build_display_text(summary), StringUtils.format("/{} ", summary.name.to_lower())))
	return options


## The command starts after the line's indentation and ends under the caret; the accepted row replaces
## all of it and leaves `/name ` behind, which is what keeps the list closed afterwards.
func token_span() -> Vector2i:
	var line: String = input_field.get_line(input_field.get_caret_line())
	var start: int = line.length() - line.strip_edges(true, false).length()
	return Vector2i(start, input_field.get_caret_column())


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
