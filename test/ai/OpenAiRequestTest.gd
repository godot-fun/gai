func open_ai_request_to_json_test() -> void:
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hello"))
	var request := OpenAiRequest.new("test-model", messages, true)
	request.max_tokens = 8192
	var tool := FunctionToolDef.new()
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


func open_ai_request_omits_optional_fields_test() -> void:
	var body: Dictionary = JSON.parse_string(OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false).to_json())
	assert(not body.has("max_tokens"))
	assert(not body.has("tools"))
	assert(not body.has("tool_choice"))
	assert(not body.has("thinking"))
	assert(not body.has("response_format"))
	pass


func open_ai_request_empty_messages_test() -> void:
	var body: Dictionary = JSON.parse_string(OpenAiRequest.new("test-model", [], false).to_json())
	assert(body.messages == [])
	assert(body.model == "test-model")
	assert(body.stream == false)
	pass


func open_ai_request_number_tool_parameter_to_json_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	var tool := FunctionToolDef.new()
	tool.function.name = "set_volume"
	tool.function.parameters.number_prop("volume", "Volume multiplier", true)
	request.tools.append(tool)
	var json := request.to_json()
	assert(json.contains("\"volume\": {\"type\": \"number\", \"description\": \"Volume multiplier\"}"))
	assert(json.contains("\"required\": [\"volume\"]"))
	pass


func open_ai_request_enum_tool_parameter_to_json_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	var tool := FunctionToolDef.new()
	tool.function.name = "set_unit"
	tool.function.parameters.enum_prop("unit", ["celsius", "fahrenheit"], "Temperature unit", true)
	request.tools.append(tool)
	var body: Dictionary = JSON.parse_string(request.to_json())
	var unit: Dictionary = body.tools[0].function.parameters.properties.unit
	assert(unit.type == "string")
	assert(unit["enum"] == ["celsius", "fahrenheit"])
	assert(unit.description == "Temperature unit")
	assert(body.tools[0].function.parameters.required == ["unit"])
	pass


func open_ai_request_array_tool_parameter_to_json_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	var tool := FunctionToolDef.new()
	tool.function.name = "read_files"
	tool.function.parameters.array_prop("paths", "string", "File paths", true)
	request.tools.append(tool)
	var body: Dictionary = JSON.parse_string(request.to_json())
	var parameters: Dictionary = body.tools[0].function.parameters
	var paths: Dictionary = parameters.properties.paths
	assert(paths.type == "array")
	assert(paths.description == "File paths")
	assert(paths.items.type == "string")
	assert(parameters.required == ["paths"])
	pass


func open_ai_request_object_tool_parameter_to_json_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	var tool := FunctionToolDef.new()
	tool.function.name = "create_user"
	var profile := ToolParameters.Parameters.new()
	profile.string_prop("name", "Display name", true)
	profile.enum_prop("role", ["admin", "member"], "User role", true)
	tool.function.parameters.object_prop("profile", profile, "User profile", true)
	request.tools.append(tool)
	var body: Dictionary = JSON.parse_string(request.to_json())
	var parameters: Dictionary = body.tools[0].function.parameters
	var profile_json: Dictionary = parameters.properties.profile
	assert(profile_json.type == "object")
	assert(profile_json.description == "User profile")
	assert(profile_json.properties.name.type == "string")
	assert(profile_json.properties.role["enum"] == ["admin", "member"])
	assert(profile_json.required == ["name", "role"])
	assert(parameters.required == ["profile"])
	pass


func open_ai_request_to_json_async_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	var json: String = await ExecutorHelper.async_execute_pooled(request.to_json)
	assert(json.contains("\"model\": \"test-model\""))
	assert(json.contains("\"content\": \"hello\""))
	pass


func open_ai_request_to_json_thinking_disabled_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	request.thinking = OpenAiRequest.THINKING_DISABLED
	var json := request.to_json()
	assert(json.contains("\"thinking\": {\"type\": \"disabled\"}"))
	pass


func open_ai_request_to_json_response_format_json_object_test() -> void:
	var request := OpenAiRequest.new("test-model", [ChatMessage.user("hello")], false)
	request.response_format = OpenAiRequest.RESPONSE_FORMAT_JSON_OBJECT
	var json := request.to_json()
	assert(json.contains("\"response_format\": {\"type\": \"json_object\"}"))
	pass


func open_ai_request_to_json_escapes_control_characters_test() -> void:
	var messages: Array[ChatMessage] = [ChatMessage.tool_result("call_1", "ansi" + char(0x1B) + "[0m")]
	var json := OpenAiRequest.new("test-model", messages, true).to_json()
	assert(JSON.parse_string(json) != null)
	assert(json.contains(r"\u001b"))
	assert(not json.contains(char(0x1B)))
	pass


func open_ai_request_to_json_tool_calls_reasoning_test() -> void:
	var tool_call := ToolCall.new()
	tool_call.id = "call_1"
	tool_call.function.name = "read"
	var messages: Array[ChatMessage] = []
	messages.append(ChatMessage.user("hi"))
	messages.append(ChatMessage.assistant_tool_calls([tool_call], "", "thinking"))
	messages.append(ChatMessage.tool_result("call_1", "ok"))
	var parsed: Dictionary = JSON.parse_string(OpenAiRequest.new("test-model", messages, true).to_json())
	var wire_messages: Array = parsed["messages"]
	assert(wire_messages[1]["reasoning_content"] == "thinking")
	assert(wire_messages[1]["tool_calls"].size() == 1)
	assert(not wire_messages[2].has("reasoning_content"))
	pass
