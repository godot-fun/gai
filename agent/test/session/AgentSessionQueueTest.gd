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
	var compacted := CompactionManager.collect_context_entries(entries)
	assert(compacted.size() == 2)
	assert(compacted[0].kind == ChatEntry.KIND_SYSTEM)
	assert(compacted[1].kind == ChatEntry.KIND_MEMORY)
	pass


static func compaction_replaces_previous_summary_message_test() -> void:
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.system(CompactionManager.SUMMARY_PREFIX + "\nold summary"),
		ChatMessage.user("new question"),
	]
	var context := CompactionManager.collect_context_messages(messages)
	assert(context.size() == 1)
	assert(context[0].content == "system")
	pass


static func memory_messages_drop_thinking_and_tool_protocol_test() -> void:
	var tool_call := OpenAiToolCall.new()
	tool_call.id = "call-1"
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.system(CompactionManager.SUMMARY_PREFIX + "\nprevious work"),
		ChatMessage.user("   "),
		ChatMessage.user(" question "),
		ChatMessage.assistant_tool_calls([tool_call], "", "private thinking"),
		ChatMessage.tool_result("call-1", "test passed"),
		ChatMessage.assistant("answer", "more private thinking"),
	]
	var memory_messages := MemoryManager.collect_memory_messages(messages)
	assert(memory_messages.size() == 3)
	assert(memory_messages[0].role == ChatMessage.ROLE_USER)
	assert(memory_messages[0].content == "Previous compacted context:\nprevious work")
	assert(memory_messages[1].role == ChatMessage.ROLE_USER and memory_messages[1].content == "question")
	assert(memory_messages[2].role == ChatMessage.ROLE_ASSISTANT and memory_messages[2].content == "answer")
	assert(memory_messages[2].reasoning_content.is_empty())
	assert(memory_messages[2].tool_calls.is_empty())
	pass
