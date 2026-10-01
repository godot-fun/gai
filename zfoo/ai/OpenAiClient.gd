class_name OpenAiClient
extends Object

const REQUEST_TIMEOUT_MILLIS := 5 * TimeUtils.MILLIS_PER_MINUTE

var api_key: String
var base_url: String
var model: String


func _init(p_api_key: String, p_base_url: String, p_model: String) -> void:
	api_key = p_api_key
	base_url = p_base_url
	model = p_model
	pass


func build_messages(prompt: String, system_prompt: String = "") -> Array[ChatMessage]:
	var messages: Array[ChatMessage] = []
	if StringUtils.is_not_blank(system_prompt):
		messages.append(ChatMessage.new(ChatMessage.ROLE_SYSTEM, system_prompt))
	messages.append(ChatMessage.new(ChatMessage.ROLE_USER, prompt))
	return messages


func build_headers(stream: bool = false) -> PackedStringArray:
	var headers := PackedStringArray([StringUtils.format("Authorization: Bearer {}", api_key)])
	if stream:
		headers.append("Accept: text/event-stream")
	return headers


func validate_messages(messages: Array[ChatMessage]) -> bool:
	if StringUtils.is_blank(api_key):
		Log.error("OpenAI api_key is empty")
		return false
	if messages.is_empty():
		Log.error("OpenAI messages is empty")
		return false
	return true


func build_request_json(request: OpenAiRequest) -> String:
	return request.to_json()


# ----------------------------------------------------------------------------------------------------------------------
func async_chat(prompt: String, system_prompt: String = "", proxy: String = "", response_format: String = "") -> String:
	return await async_chat_messages(build_messages(prompt, system_prompt), proxy, response_format)

func async_chat_messages(messages: Array[ChatMessage], proxy: String = "", response_format: String = "") -> String:
	if not validate_messages(messages):
		return StringUtils.EMPTY
	var request := OpenAiRequest.new(model, messages, false)
	# DeepSeek V4 enables thinking by default; non-stream short replies (e.g. Sense) stay non-thinking.
	request.thinking = OpenAiRequest.THINKING_DISABLED
	if StringUtils.is_not_blank(response_format):
		request.response_format = response_format
	var response := await HttpHelper.async_post(base_url, build_request_json(request), build_headers(), REQUEST_TIMEOUT_MILLIS, proxy)
	var body := response.get_body_string()
	Log.info("OpenAI response body:[{}]", StringUtils.truncate(body, 512))
	if not response.success or response.code != 200:
		Log.error("OpenAI request failed code:[{}] body:[{}]", response.code, StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var chat_response: OpenAiResponse = JsonUtils.json_to_object(body, OpenAiResponse)
	if chat_response == null or chat_response.choices.is_empty():
		Log.error("OpenAI response parse failed body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var message := chat_response.choices[0].message
	if message == null or StringUtils.is_blank(message.content):
		Log.error("OpenAI response missing content body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	return message.content

# ----------------------------------------------------------------------------------------------------------------------
# Example sse request:
# HTTP/1.1 200 OK
# Content-Type: text/event-stream
# Cache-Control: no-cache
# Connection: keep-alive

# Example response:
# data: {"content":"你"}
# data: {"content":"好"}
# data: {"content":"！"}
# data: [DONE]

## Streaming chat completion with optional tools.
## on_delta(delta, stream_kind) — stream_kind is STREAM_KIND_CONTENT or STREAM_KIND_REASONING.
func async_chat_messages_stream(messages: Array[ChatMessage], tools: Array[OpenAiToolDef] = [], proxy: String = "", on_delta: Callable = Callable()) -> OpenAiCompletion:
	var result := OpenAiCompletion.new()
	if not validate_messages(messages):
		result.error = "invalid messages"
		return result
	var request := OpenAiRequest.new(model, messages, true)
	request.tools = tools
	request.max_tokens = 8192
	var pending_build := StringBuilder.new()
	var utf8_decoder := Utf8StreamDecoder.new()
	var on_chunk := func(chunk: PackedByteArray) -> void:
		var buffer := pending_build.build_string() + utf8_decoder.push(chunk)
		pending_build.clear()
		var remaining := consume_sse_buffer(buffer, on_delta)
		pending_build.append_if_not_empty(remaining)
		pass
	var response := await HttpHelper.async_post(base_url, build_request_json(request), build_headers(true)
			, REQUEST_TIMEOUT_MILLIS, proxy, on_chunk)
	## The final body carries every delta verbatim, so content / reasoning / finish_reason / usage
	## all come from that one string instead of being accumulated during streaming.
	var body := response.get_body_string()
	if not response.success or response.code != 200:
		Log.error("OpenAI stream failed code:[{}] body:[{}]", response.code, StringUtils.truncate(body, 512))
		result.error = body
		return result
	var tail := pending_build.build_string() + utf8_decoder.flush()
	if StringUtils.is_not_empty(tail):
		consume_sse_buffer(tail + FileUtils.NEWLINE_LF, on_delta)
	var chunks := parse_stream_chunks(body)
	result.content = extract_stream_content(chunks)
	result.reasoning_content = extract_stream_reasoning_content(chunks)
	result.tool_calls = extract_stream_tool_calls(chunks)
	result.finish_reason = extract_finish_reason(chunks)
	result.usage = extract_stream_usage(chunks)
	return result

# ----------------------------------------------------------------------------------------------------------------------
const STREAM_KIND_CONTENT := "content"
const STREAM_KIND_REASONING := "reasoning"

func consume_sse_buffer(buffer: String, on_delta: Callable = Callable()) -> String:
	if buffer.is_empty():
		return StringUtils.EMPTY
	var lines: PackedStringArray = buffer.split(FileUtils.NEWLINE_LF, false)
	var remaining := StringUtils.EMPTY
	if not buffer.ends_with(FileUtils.NEWLINE_LF):
		remaining = lines[lines.size() - 1]
		lines = lines.slice(0, lines.size() - 1)
	for line: String in lines:
		line = line.strip_edges()
		if line.is_empty() or not line.begins_with("data:"):
			continue
		var payload := StringUtils.substring_after(line, "data:").strip_edges()
		if payload.to_upper() == "[DONE]":
			continue
		var chunk: OpenAiStreamChunk = JsonUtils.json_to_object(payload, OpenAiStreamChunk)
		if chunk == null or chunk.choices.is_empty():
			continue
		var choice := chunk.choices[0]
		if choice.delta != null:
			if StringUtils.is_not_empty(choice.delta.content):
				on_delta.call(choice.delta.content, STREAM_KIND_CONTENT)
			if StringUtils.is_not_empty(choice.delta.reasoning_content):
				on_delta.call(choice.delta.reasoning_content, STREAM_KIND_REASONING)
	return remaining

# ----------------------------------------------------------------------------------------------------------------------
## Parses a raw SSE body, skipping blank lines, non-`data:` lines and `[DONE]`.
func parse_stream_chunks(body: String) -> Array[OpenAiStreamChunk]:
	var chunks: Array[OpenAiStreamChunk] = []
	if StringUtils.is_blank(body):
		return chunks
	for line: String in body.split(FileUtils.NEWLINE_LF, false):
		line = line.strip_edges()
		if line.is_empty() or not line.begins_with("data:"):
			continue
		var payload := StringUtils.substring_after(line, "data:").strip_edges()
		if payload.to_upper() == "[DONE]":
			continue
		var chunk: OpenAiStreamChunk = JsonUtils.json_to_object(payload, OpenAiStreamChunk)
		if chunk != null:
			chunks.append(chunk)
	return chunks


## Joins every content (or reasoning) delta of the parsed chunks in stream order.
func extract_stream_content(chunks: Array[OpenAiStreamChunk]) -> String:
	var build := StringBuilder.new()
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.choices.is_empty():
			continue
		var delta := chunk.choices[0].delta
		if delta == null:
			continue
		build.append_if_not_empty(delta.content)
	return build.build_string()


func extract_stream_reasoning_content(chunks: Array[OpenAiStreamChunk]) -> String:
	var build := StringBuilder.new()
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.choices.is_empty():
			continue
		var delta := chunk.choices[0].delta
		if delta == null:
			continue
		build.append_if_not_empty(delta.reasoning_content)
	return build.build_string()


func extract_stream_tool_calls(chunks: Array[OpenAiStreamChunk]) -> Array[OpenAiToolCall]:
	var merged_calls: Array[OpenAiToolCall] = []
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.choices.is_empty():
			continue
		var delta := chunk.choices[0].delta
		if delta == null:
			continue
		OpenAiToolCall.merge_stream_deltas(merged_calls, delta.tool_calls)
	var tool_calls: Array[OpenAiToolCall] = []
	for call: OpenAiToolCall in merged_calls:
		if StringUtils.is_not_blank(call.function.name):
			tool_calls.append(call)
	return tool_calls

func extract_finish_reason(chunks: Array[OpenAiStreamChunk]) -> String:
	var finish_reason := StringUtils.EMPTY
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.choices.is_empty():
			continue
		if StringUtils.is_not_empty(chunk.choices[0].finish_reason):
			finish_reason = chunk.choices[0].finish_reason
	return finish_reason


func extract_stream_usage(chunks: Array[OpenAiStreamChunk]) -> OpenAiUsage:
	var usage := OpenAiUsage.new()
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.usage.has_data():
			usage = chunk.usage
	return usage
