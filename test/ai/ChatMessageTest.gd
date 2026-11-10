func chat_message_from_dict_dispatches_by_role_test() -> void:
	var system := JsonUtils.dict_to_object({"role": ChatMessage.ROLE_SYSTEM, "text": "sys"}, ChatMessage) as SystemChatMessage
	assert(system != null and system.text == "sys")
	var user := JsonUtils.dict_to_object({"role": ChatMessage.ROLE_USER, "parts": [{"part_type": "text", "text": "hi"}]}, ChatMessage) as UserChatMessage
	assert(user != null and (user.parts[0] as UserTextPart).text == "hi")
	assert(JsonUtils.dict_to_object({"role": "unknown"}, ChatMessage) == null)
	pass


func chat_message_persistence_roundtrip_test() -> void:
	var tool_call := ToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	tool_call.function.arguments = '{"path":"a.txt"}'
	var messages: Array[ChatMessage] = [
		ChatMessage.system("system"),
		ChatMessage.user("question"),
		ChatMessage.assistant_tool_calls([tool_call], "answer", "thinking"),
		ChatMessage.tool_result("call_1", "result"),
	]
	for message: ChatMessage in messages:
		var json := JsonUtils.object_to_json(message)
		var restored := JsonUtils.json_to_object(json, ChatMessage) as ChatMessage
		assert(restored != null)
		assert(JsonUtils.object_to_json(restored) == json)
	pass


func chat_message_plain_user_api_shape_test() -> void:
	var wire := ChatMessage.user("hello").to_api_dict()
	assert(wire == {"role": ChatMessage.ROLE_USER, "content": "hello"})
	pass


func chat_message_user_api_omits_null_parts_test() -> void:
	var parts: Array[ChatUserPart] = [UserTextPart.new("hello"), null, UserImageUrlPart.new("data:image/png;base64,AAAA")]
	var content: Array = UserChatMessage.new(parts).to_api_dict()["content"]
	assert(content.size() == 2)
	assert(content[0] == {"type": "text", "text": "hello"})
	assert(content[1] == {"type": "image_url", "image_url": {"url": "data:image/png;base64,AAAA"}})
	pass


func chat_message_assistant_tool_call_persistence_test() -> void:
	var tool_call := ToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	tool_call.function.arguments = '{"path":"a.txt"}'
	var source := ChatMessage.assistant_tool_calls([tool_call], "", "thinking")
	var restored := JsonUtils.json_to_object(JsonUtils.object_to_json(source), ChatMessage) as AssistantChatMessage
	assert(restored != null)
	assert(restored.tool_calls.size() == 1)
	assert(restored.tool_calls[0].id == "call_1")
	assert(restored.tool_calls[0].function.name == "read")
	assert(restored.tool_calls[0].function.arguments == '{"path":"a.txt"}')
	pass


func chat_message_tool_calls_reasoning_omits_empty_reasoning_test() -> void:
	var tool_call := ToolCall.new()
	tool_call.id = "call_1"
	var message := ChatMessage.assistant_tool_calls([tool_call])
	assert(not message.to_api_dict().has("reasoning_content"))
	pass


func chat_message_tool_calls_reasoning_roundtrip_test() -> void:
	var tool_call := ToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	var message := ChatMessage.assistant_tool_calls([tool_call], "", "thinking") as AssistantChatMessage
	assert(message.reasoning_content == "thinking")
	assert(message.to_api_dict()["reasoning_content"] == "thinking")
	pass


func chat_message_plain_assistant_reasoning_roundtrip_test() -> void:
	var message := ChatMessage.assistant("done", "thinking") as AssistantChatMessage
	assert(message.reasoning_content == "thinking")
	assert(message.to_api_dict()["reasoning_content"] == "thinking")
	pass


func chat_message_plain_assistant_without_reasoning_omits_field_test() -> void:
	var message := ChatMessage.assistant("done")
	assert(not message.to_api_dict().has("reasoning_content"))
	pass


func chat_message_user_image_wire_shape_test() -> void:
	var message := UserChatMessage.with_text_and_data_url("Inspect this image", "data:image/png;base64,AAAA")
	var wire := message.to_api_dict()
	assert(wire["role"] == ChatMessage.ROLE_USER)
	assert(wire["content"].size() == 2)
	assert(wire["content"][0] == {"type": "text", "text": "Inspect this image"})
	assert(wire["content"][1] == {"type": "image_url", "image_url": {"url": "data:image/png;base64,AAAA"}})
	pass


func chat_message_user_image_roundtrip_test() -> void:
	var message := UserChatMessage.with_text_and_data_url("Inspect this image", "data:image/png;base64,AAAA")
	var json := JsonUtils.object_to_json(message)
	var user := JsonUtils.json_to_object(json, ChatMessage) as UserChatMessage
	assert(user != null)
	assert((user.parts[0] as UserTextPart).text == (message.parts[0] as UserTextPart).text)
	assert(user.first_image_data_url() == message.first_image_data_url())
	pass


func chat_message_user_image_default_caption_test() -> void:
	var path := ProjectSettings.globalize_path("res://test/asset/explosion_animation.png")
	var message := ChatMessage.user_image(StringUtils.EMPTY, path)
	assert(StringUtils.is_not_blank(message.first_image_data_url()))
	assert((message.parts[0] as UserTextPart).text == StringUtils.format("Image read: {}", path))
	pass


func chat_message_user_image_missing_file_has_no_data_url_test() -> void:
	var path := ProjectSettings.globalize_path("res://test/asset/does_not_exist.png")
	var message := ChatMessage.user_image("caption", path)
	assert(StringUtils.is_blank(message.first_image_data_url()))
	assert((message.parts[0] as UserTextPart).text == "caption")
	pass
