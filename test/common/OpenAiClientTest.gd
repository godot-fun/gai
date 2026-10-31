var client := OpenAiClient.new("test-key", "https://api.example.com/v1/chat/completions", "test-model")


func consume_sse_buffer_test() -> void:
	var deltas: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append(delta)
		pass
	var remainder := client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n",
		on_delta
	)
	assert(deltas == ["Hel", "lo"])
	assert(remainder == StringUtils.EMPTY)
	pass


func consume_sse_buffer_without_callback_test() -> void:
	var remainder := client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"content\":\"compact summary\"}}]}\n"
	)
	assert(remainder == StringUtils.EMPTY)
	pass


func consume_sse_buffer_partial_line_test() -> void:
	var deltas: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append(delta)
		pass
	var remainder := client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}",
		on_delta
	)
	assert(deltas.is_empty())
	assert(remainder.begins_with("data:"))
	var remainder2 := client.consume_sse_buffer(remainder + "\n", on_delta)
	assert(deltas == ["Hi"])
	assert(remainder2 == StringUtils.EMPTY)
	pass


func consume_sse_buffer_on_delta_test() -> void:
	var deltas := StringBuilder.new()
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append_if_not_empty(delta)
		pass
	client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n",
		on_delta
	)
	assert(deltas.build_string() == "Hello")
	pass


func consume_sse_buffer_reasoning_one_arg_on_delta_test() -> void:
	var deltas: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append(delta)
		pass
	client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"think\"}}]}\n"
		+ "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n",
		on_delta
	)
	assert(deltas.size() == 2)
	assert(deltas[1] == "OK")
	pass


func consume_sse_buffer_reasoning_on_delta_test() -> void:
	var kinds: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		kinds.append(stream_kind)
		pass
	client.consume_sse_buffer(
		"data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"think\"}}]}\n"
		+ "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n",
		on_delta
	)
	assert(kinds.size() == 2)
	assert(kinds[0] == OpenAiClient.STREAM_KIND_REASONING)
	assert(kinds[1] == OpenAiClient.STREAM_KIND_CONTENT)
	pass


func extract_finish_reason_test() -> void:
	var body := "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n"
	assert(client.extract_finish_reason(client.parse_stream_chunks(body)) == "stop")
	pass


func consume_sse_buffer_multichunk_test() -> void:
	var pending_build := StringBuilder.new()
	var deltas: Array[String] = []
	var on_delta := func(delta: String, stream_kind: String) -> void:
		deltas.append(delta)
		pass
	var append_chunk := func(chunk_text: String) -> void:
		var buffer := pending_build.build_string() + chunk_text
		pending_build.clear()
		var remaining := client.consume_sse_buffer(buffer, on_delta)
		if StringUtils.is_not_empty(remaining):
			pending_build.append_if_not_empty(remaining)
		pass
	append_chunk.call("data: {\"choices\":[{\"delta\":{\"content\":\"Hel")
	append_chunk.call("lo\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"!\"}}]}\n")
	assert(deltas == ["Hello", "!"])
	pass


func extract_stream_tool_calls_test() -> void:
	var body := (
		"data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"read\",\"arguments\":\"\"}}]}}]}\n"
		+ "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"path\\\":\\\"a.txt\\\"}\"}}]}}]}\n"
	)
	var tool_calls := client.extract_stream_tool_calls(client.parse_stream_chunks(body))
	assert(tool_calls.size() == 1)
	assert(tool_calls[0].id == "call_1")
	assert(tool_calls[0].function.name == "read")
	assert(tool_calls[0].function.arguments == "{\"path\":\"a.txt\"}")
	pass


func open_ai_request_to_json_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, true)
	request.max_tokens = 8192
	var tool := OpenAiToolDef.new()
	tool.function.name = "read"
	tool.function.description = "Read a file"
	tool.function.parameters.string_prop("path", "File path", true)
	request.tools.append(tool)
	var json := request.to_json()
	assert(json.contains("\"model\": \"test-model\""))
	assert(json.contains("\"stream\": true"))
	assert(json.contains("\"max_tokens\": 8192"))
	assert(json.contains("\"content\": \"hello\""))
	assert(json.contains("\"name\": \"read\""))
	assert(not json.contains("\"thinking\""))
	pass


func open_ai_request_to_json_async_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, false)
	var json: String = await ExecutorHelper.async_execute_pooled(request.to_json)
	assert(json.contains("\"model\": \"test-model\""))
	assert(json.contains("\"content\": \"hello\""))
	pass


func open_ai_request_to_json_thinking_disabled_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, false)
	request.thinking = OpenAiRequest.THINKING_DISABLED
	var json := request.to_json()
	assert(json.contains("\"thinking\": {\"type\": \"disabled\"}"))
	pass


func open_ai_request_to_json_response_format_json_object_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, false)
	request.response_format = OpenAiRequest.RESPONSE_FORMAT_JSON_OBJECT
	var json := request.to_json()
	assert(json.contains("\"response_format\": {\"type\": \"json_object\"}"))
	pass


func extract_stream_usage_test() -> void:
	var body := (
		"data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\n"
		+ "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],"
		+ "\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":5,\"total_tokens\":17}}\n"
	)
	var usage := client.extract_stream_usage(client.parse_stream_chunks(body))
	assert(usage.total_tokens == 17)
	assert(usage.prompt_tokens == 12)
	assert(usage.completion_tokens == 5)
	pass


func collect_stream_text_test() -> void:
	var body := (
		"data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"thin\"}}]}\n\n"
		+ "data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"king\"}}]}\n\n"
		+ "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\n\n"
		+ "data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n\n"
		+ "data: [DONE]\n"
	)
	var chunks := client.parse_stream_chunks(body)
	assert(chunks.size() == 4)
	assert(client.extract_stream_content(chunks) == "Hello")
	assert(client.extract_stream_reasoning_content(chunks) == "thinking")
	pass


func parse_stream_chunks_skips_blank_body_test() -> void:
	assert(client.parse_stream_chunks(StringUtils.EMPTY).is_empty())
	pass


func open_ai_request_to_json_escapes_control_characters_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.tool_result("call_1", "ansi" + char(0x1B) + "[0m"))
	var request := OpenAiRequest.new("test-model", messages, true)
	var json := request.to_json()
	assert(JSON.parse_string(json) != null)
	assert(json.contains(r"\u001b"))
	assert(not json.contains(char(0x1B)))
	pass


func chat_message_tool_calls_reasoning_roundtrip_test() -> void:
	var tool_call := OpenAiToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	var message := ChatMessage.assistant_tool_calls([tool_call], "", "thinking")
	assert(message.reasoning_content == "thinking")
	assert(message.to_api_dict()["reasoning_content"] == "thinking")
	pass


func chat_message_plain_assistant_reasoning_roundtrip_test() -> void:
	var message := ChatMessage.assistant("done", "thinking")
	assert(message.reasoning_content == "thinking")
	assert(message.to_api_dict()["reasoning_content"] == "thinking")
	pass


func chat_message_plain_assistant_without_reasoning_omits_field_test() -> void:
	var message := ChatMessage.assistant("done")
	assert(not message.to_api_dict().has("reasoning_content"))
	pass


func chat_message_user_image_wire_shape_test() -> void:
	var message := ChatMessage.user("Inspect this image")
	message.image_data_url = "data:image/png;base64,AAAA"
	var wire := message.to_api_dict()
	assert(wire["role"] == ChatMessage.ROLE_USER)
	assert(wire["content"].size() == 2)
	assert(wire["content"][0] == {"type": "text", "text": "Inspect this image"})
	assert(wire["content"][1] == {"type": "image_url", "image_url": {"url": message.image_data_url}})
	pass


func chat_message_user_image_roundtrip_test() -> void:
	var message := ChatMessage.user("Inspect this image")
	message.image_data_url = "data:image/png;base64,AAAA"
	var restored: ChatMessage = JsonUtils.json_to_object(JsonUtils.object_to_json(message), ChatMessage)
	assert(restored != null)
	assert(restored.role == ChatMessage.ROLE_USER)
	assert(restored.content == message.content)
	assert(restored.image_data_url == message.image_data_url)
	pass


func chat_message_user_image_default_caption_test() -> void:
	var path := ProjectSettings.globalize_path("res://test/asset/explosion_animation.png")
	var message := ChatMessage.user_image(StringUtils.EMPTY, path)
	assert(StringUtils.is_not_blank(message.image_data_url))
	assert(message.content == StringUtils.format("Image read: {}", path))
	pass


func open_ai_request_to_json_tool_calls_reasoning_test() -> void:
	var tool_call := OpenAiToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hi"))
	messages.append(ChatMessage.assistant_tool_calls([tool_call], "", "thinking"))
	messages.append(ChatMessage.tool_result("call_1", "ok"))
	var json := OpenAiRequest.new("test-model", messages, true).to_json()
	var parsed: Dictionary = JSON.parse_string(json)
	var wire_messages: Array = parsed["messages"]
	assert(wire_messages[1]["reasoning_content"] == "thinking")
	assert(wire_messages[1]["tool_calls"].size() == 1)
	assert(not wire_messages[2].has("reasoning_content"))
	pass
