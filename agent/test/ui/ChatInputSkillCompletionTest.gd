extends RefCounted

## `/skill` popup behavior: name matching, row text and the token an accepted row replaces. Parsing
## lives in SkillManagerTest; the popup itself lives in ChatInputCompletionTest.


func matching_summaries_test() -> void:
	var summaries: Array[SkillSummary] = [
		SkillSummary.new("audio-trim", ""),
		SkillSummary.new("audio-to-wav", ""),
		SkillSummary.new("video-merge", ""),
	]
	assert(ChatInputSkillCompletion.matching_summaries(summaries, "/").size() == 3)
	assert(ChatInputSkillCompletion.matching_summaries(summaries, "/audio").size() == 2)
	assert(ChatInputSkillCompletion.matching_summaries(summaries, "/audio-t").size() == 2)
	# No name starts with `/tr`, so the contains fallback finds the trim skill only.
	var loose: Array[SkillSummary] = ChatInputSkillCompletion.matching_summaries(summaries, "/tr")
	assert(loose.size() == 1)
	assert(loose[0].name == "audio-trim")
	var empty: Array[SkillSummary] = []
	assert(ChatInputSkillCompletion.matching_summaries(empty, "/audio").is_empty())
	pass


func display_text_test() -> void:
	assert(ChatInputSkillCompletion.build_display_text(SkillSummary.new("audio-trim", "")) == "/audio-trim")
	assert(ChatInputSkillCompletion.build_display_text(SkillSummary.new("audio-trim", "Trims silence"))
		== "/audio-trim" + ChatInputSkillCompletion.DISPLAY_SEPARATOR + "Trims silence")
	pass


## Accepting an option leaves `/git-commit-message ` in the field. The list must not reopen there,
## otherwise the next Enter inserts the same skill again and the field ends up with two commands.
func accepted_skill_closes_the_list_test() -> void:
	var completion := ChatInputSkillCompletion.new()
	assert(slash_command_at(completion, "/git"))
	assert(not slash_command_at(completion, "/git-commit-message "))
	assert(not slash_command_at(completion, "/audio-trim file.wav"))
	assert(not slash_command_at(completion, "hello /git"))
	# Indentation before the command is fine, and so is a caret parked before an argument.
	assert(slash_command_at(completion, "   /git"))
	assert(slash_command_at(completion, "/audio-trim more", "/audio-trim".length()))
	pass


## The row replaces the whole command — indentation included — and leaves `/name ` behind.
func token_span_covers_the_whole_command_test() -> void:
	assert(token_span_at("   /audio-t") == Vector2i(3, 11))
	assert(token_span_at("/agent") == Vector2i(0, 6))
	assert(token_span_at("/audio-trim more", "/audio-trim".length()) == Vector2i(0, 11))
	pass


## Types [param text] into a real [CodeEdit] at [param caret_column] and asks whether the caret commands
## the list. The caret sits at the end of the text by default.
func slash_command_at(completion: ChatInputSkillCompletion, text: String, caret_column: int = -1) -> bool:
	var field := CodeEdit.new()
	field.text = text
	field.set_caret_line(0, false)
	field.set_caret_column(text.length() if caret_column < 0 else caret_column, false)
	completion.input_field = field
	var result := completion.is_slash_command()
	completion.input_field = null
	field.free()
	return result


func token_span_at(text: String, caret_column: int = -1) -> Vector2i:
	var field := CodeEdit.new()
	field.text = text
	field.set_caret_line(0, false)
	field.set_caret_column(text.length() if caret_column < 0 else caret_column, false)
	var completion := ChatInputSkillCompletion.new()
	completion.input_field = field
	var span := completion.token_span()
	completion.input_field = null
	field.free()
	return span
