## Verifies that background serialization can mutate/read a clone independently of the live session.


static func agent_session_deep_clone_is_independent_test() -> void:
	var tool_call := OpenAiToolCall.new()
	tool_call.id = "call-1"
	tool_call.function.name = "read_file"
	tool_call.function.arguments = "{\"path\":\"before\"}"
	var message := ChatMessage.assistant_tool_calls([tool_call], "answer", "reasoning")
	var entry := ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "body", {"key": "before"})
	var session := AgentSession.new(42)
	session.messages.append(message)
	session.chat_entries.append(entry)
	session.pending_messages.append("pending")
	session.draft_text = "draft"
	session.usage.prompt_tokens = 100

	var cloned := session.deep_clone()
	assert(JsonUtils.object_to_json(cloned) == JsonUtils.object_to_json(session))
	session.messages[0].content = "changed"
	session.messages[0].tool_calls[0].function.arguments = "changed"
	session.chat_entries[0].body = "changed"
	session.chat_entries[0].details["key"] = "changed"
	session.pending_messages[0] = "changed"
	session.usage.prompt_tokens = 200

	assert(cloned != session)
	assert(cloned.messages[0] != session.messages[0])
	assert(cloned.messages[0].content == "answer")
	assert(cloned.messages[0].tool_calls[0] != session.messages[0].tool_calls[0])
	assert(cloned.messages[0].tool_calls[0].function.arguments == "{\"path\":\"before\"}")
	assert(cloned.chat_entries[0] != session.chat_entries[0])
	assert(cloned.chat_entries[0].body == "body")
	assert(cloned.chat_entries[0].details["key"] == "before")
	assert(cloned.pending_messages[0] == "pending")
	assert(cloned.usage.prompt_tokens == 100)
	pass
