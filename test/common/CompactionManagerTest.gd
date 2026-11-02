static func update_estimated_usage_includes_image_data_url_test() -> void:
	var message := ChatMessage.user("")
	message.image_data_url = "a".repeat(40)
	var session := AgentSession.new(1)
	session.messages.append(message)
	CompactionManager.update_estimated_usage(session)
	assert(session.usage.prompt_tokens == 10)
	pass


static func update_estimated_usage_includes_tool_call_json_test() -> void:
	var tool_call := OpenAiToolCall.new()
	tool_call.id = "call-1"
	tool_call.function.name = "read"
	tool_call.function.arguments = "{}"
	var session := AgentSession.new(1)
	session.messages.append(ChatMessage.assistant_tool_calls([tool_call]))
	CompactionManager.update_estimated_usage(session)
	var json_len := JsonUtils.object_to_json(tool_call).length()
	assert(session.usage.prompt_tokens == maxi(1, int(ceil(float(json_len) / 4.0))))
	pass
