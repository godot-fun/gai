## Unit coverage for persisted per-session drafts and pending message order.

static func session_queue_json_round_trip_test() -> void:
	var session := AgentSession.new(42)
	session.draft_text = "unfinished draft"
	session.pending_messages.append("second turn")
	session.pending_messages.append("third turn")
	var json := JsonUtils.object_to_json(session)
	var restored: AgentSession = JsonUtils.json_to_object(json, AgentSession)
	assert(restored != null)
	assert(restored.draft_text == "unfinished draft")
	assert(restored.pending_messages.size() == 2)
	assert(restored.pending_messages[0] == "second turn")
	assert(restored.pending_messages[1] == "third turn")
	pass


static func pending_message_delete_keeps_fifo_order_test() -> void:
	var session := AgentSession.new(42)
	session.pending_messages.append("one")
	session.pending_messages.append("two")
	session.pending_messages.append("three")
	session.pending_messages.remove_at(session.pending_messages.find("two"))
	assert(session.pending_messages.size() == 2)
	assert(session.pending_messages[0] == "one")
	assert(session.pending_messages[1] == "three")
	pass


static func duplicate_message_delete_removes_first_match_test() -> void:
	var pending: Array[String] = ["same", "middle", "same"]
	pending.remove_at(pending.find("same"))
	assert(pending == ["middle", "same"])
	pass


static func memory_prompt_reads_workspace_memory_test() -> void:
	assert(MemoryPrompt.MEMORY_README_PATH == ".memory/README.md")
	assert(MemoryPrompt.has_memory_context())
	assert(MemoryPrompt.get_memory_context() == FileUtils.read_file_to_string(AgentWorkspace.resolve_path(MemoryPrompt.MEMORY_README_PATH)))
	pass


static func compaction_keeps_only_context_entries_test() -> void:
	var entries: Array[ChatEntry] = [
		ChatEntry.new(ChatEntry.KIND_SYSTEM, ChatEntry.TITLE_SYSTEM, "system"),
		ChatEntry.new(ChatEntry.KIND_MEMORY, ChatEntry.TITLE_MEMORY, "memory"),
		ChatEntry.new(ChatEntry.KIND_USER, ChatEntry.TITLE_USER, "question"),
		ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "answer"),
		ChatEntry.new(ChatEntry.KIND_COMPACTION, ChatEntry.TITLE_COMPACTION, "old summary"),
	]
	var compacted := AgentCompactionManager.collect_context_entries(entries)
	assert(compacted.size() == 2)
	assert(compacted[0].kind == ChatEntry.KIND_SYSTEM)
	assert(compacted[1].kind == ChatEntry.KIND_MEMORY)
	pass


static func compaction_replaces_previous_summary_message_test() -> void:
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.system(AgentCompactionManager.SUMMARY_PREFIX + "\nold summary"),
		ChatMessage.user("new question"),
	]
	var context := AgentCompactionManager.collect_context_messages(messages)
	assert(context.size() == 1)
	assert(context[0].content == "system")
	pass
