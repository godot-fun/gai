extends RefCounted

## `/skill` popup behavior: name matching and row text. Parsing lives in SkillManagerTest.


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


## Godot replaces only the trailing word run on accept, so the row must insert just the remainder:
## on `/audio-t` the engine owns `t`, so `trim ` completes the command.
func completion_insert_text_keeps_typed_prefix_test() -> void:
	assert(ChatInputSkillCompletion.completion_insert_text("audio-trim", "/audio") == "/audio-trim ")
	assert(ChatInputSkillCompletion.completion_insert_text("audio-trim", "/audio-") == "trim ")
	assert(ChatInputSkillCompletion.completion_insert_text("audio-trim", "/audio-t") == "trim ")
	assert(ChatInputSkillCompletion.completion_insert_text("audio-to-wav", "/audio-t") == "to-wav ")
	assert(ChatInputSkillCompletion.completion_insert_text("audio-trim", "/trim") == "/audio-trim ")
	# The typed tail is not part of the name, but everything before the hyphen still is.
	assert(ChatInputSkillCompletion.completion_insert_text("audio-trim", "/audio-x") == "trim ")
	# A loose match that does not share the kept prefix cannot be completed without corrupting the line.
	assert(ChatInputSkillCompletion.completion_insert_text("x-audio-trim", "/audio-t").is_empty())
	pass


func completion_base_length_follows_the_engine_test() -> void:
	assert(ChatInputSkillCompletion.completion_base_length("/audio") == 6)
	assert(ChatInputSkillCompletion.completion_base_length("/audio-") == 0)
	assert(ChatInputSkillCompletion.completion_base_length("/audio-t") == 1)
	assert(ChatInputSkillCompletion.completion_base_length("/audio-to-") == 0)
	assert(ChatInputSkillCompletion.completion_base_length("/audio-to-wav") == 3)
	# `_` and non-ASCII are word characters, so they stay inside the base.
	assert(ChatInputSkillCompletion.completion_base_length("/audio_trim") == 11)
	assert(ChatInputSkillCompletion.completion_base_length("/音频") == 3)
	assert(ChatInputSkillCompletion.completion_base_length("") == 0)
	pass


## A skill name may contain any ASCII punctuation; the engine cancels the list right after a symbol
## unless it is a declared prefix, so every symbol must be one.
func completion_prefixes_cover_every_symbol_test() -> void:
	var prefixes: Array[String] = ChatInputSkillCompletion.completion_prefixes()
	assert(prefixes.size() == 31)
	for symbol in ["/", "-", ".", "_", ":", "@", "#", "+", "~"]:
		if symbol == "_":
			# Word character for the engine, so it never breaks completion.
			assert(not prefixes.has(symbol))
			continue
		assert(prefixes.has(symbol))
	assert(not prefixes.has("a"))
	assert(not prefixes.has(" "))
	pass
