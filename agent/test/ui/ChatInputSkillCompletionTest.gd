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
