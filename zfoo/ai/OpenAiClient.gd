class_name OpenAiClient
extends Object

const REQUEST_TIMEOUT_MILLIS := 5 * TimeUtils.MILLIS_PER_MINUTE

var api_key: String
var base_url: String
var model: String
## Optional cancellation scope; cancelling it aborts the in-flight request (see CancelScope).
var cancel_scope: CancelScope = CancelScope.new()


func _init(p_api_key: String, p_base_url: String, p_model: String) -> void:
	api_key = p_api_key
	base_url = p_base_url
	model = p_model
	pass


func build_headers(stream: bool = false) -> PackedStringArray:
	var headers := PackedStringArray([StringUtils.format("Authorization: Bearer {}", api_key)])
	if stream:
		headers.append("Accept: text/event-stream")
	return headers


## Empty when the request can be sent; otherwise why it cannot, so the failure names its real cause.
## Without this the user sees a generic "invalid messages" while a blank API key is only in the log.
func check_request(messages: Array[ChatMessage]) -> String:
	if StringUtils.is_blank(api_key):
		Log.error("OpenAI api_key is empty")
		return "OpenAI api key is empty"
	if messages.is_empty():
		Log.error("OpenAI messages is empty")
		return "OpenAI messages is empty"
	return StringUtils.EMPTY


# ----------------------------------------------------------------------------------------------------------------------
# Non-stream chat — plain assistant text only (no tool_calls, reasoning, or usage). Agent loops and tool
# rounds should use [method async_chat_messages_stream] and [OpenAiCompletion] instead.
## Non-stream single-turn assistant text (builds system + user messages). Same as [method async_chat_messages_text].
func async_chat_text(prompt: String, system_prompt: String = "", proxy: String = "", response_format: String = "") -> String:
	var messages: Array[ChatMessage] = []
	if StringUtils.is_not_blank(system_prompt):
		messages.append(ChatMessage.system(system_prompt))
	messages.append(ChatMessage.user(prompt))
	return await async_chat_messages_text(messages, proxy, response_format)


## Non-stream assistant **text** from [param messages] — reads only [code]choices[0].message.content[/code].
## Tool-call replies, reasoning-only payloads, and blank [code]content[/code] count as failure ([member StringUtils.EMPTY]).
## For tools, streaming, [member OpenAiCompletion.reasoning_content], or [member OpenAiCompletion.usage], use [method async_chat_messages_stream].
func async_chat_messages_text(messages: Array[ChatMessage], proxy: String = "", response_format: String = "") -> String:
	if StringUtils.is_not_blank(check_request(messages)):
		return StringUtils.EMPTY
	var request := OpenAiRequest.new(model, messages, false)
	# DeepSeek V4 enables thinking by default; non-stream short replies (e.g. Sense) stay non-thinking.
	request.thinking = OpenAiRequest.THINKING_DISABLED
	if StringUtils.is_not_blank(response_format):
		request.response_format = response_format
	var request_body: String = await ExecutorHelper.async_execute_pooled(request.to_json)
	var response := await HttpHelper.async_post(base_url, request_body, build_headers(), REQUEST_TIMEOUT_MILLIS, proxy, Callable(), cancel_scope)
	var body := response.get_body_string()
	Log.info("OpenAI response body:[{}]", StringUtils.truncate(body, 512))
	if not response.is_ok():
		Log.error("OpenAI request failed, http code:[{}], {}", response.code, StringUtils.truncate(response.get_error_string(), 512))
		return StringUtils.EMPTY
	var parser := JSON.new()
	if parser.parse(body) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		Log.error("OpenAI response is not valid JSON body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var choices: Variant = (parser.data as Dictionary).get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		Log.error("OpenAI response missing choices body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var choice: Variant = choices[0]
	if typeof(choice) != TYPE_DICTIONARY:
		Log.error("OpenAI response choice is invalid body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var message: Variant = choice.get("message", {})
	if typeof(message) != TYPE_DICTIONARY:
		Log.error("OpenAI response message is invalid body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	var content := str(message.get("content", ""))
	if StringUtils.is_blank(content):
		Log.error("OpenAI response missing content body:[{}]", StringUtils.truncate(body, 512))
		return StringUtils.EMPTY
	return content

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

## Full chat completion (content, reasoning, tool_calls, usage, finish_reason). Prefer this for agent loops.
## on_delta(delta, stream_kind) — stream_kind is STREAM_KIND_CONTENT or STREAM_KIND_REASONING.
func async_chat_messages_stream(messages: Array[ChatMessage], tools: Array[ToolDef] = [], proxy: String = "", on_delta: Callable = Callable()) -> OpenAiCompletion:
	var request_error := check_request(messages)
	if StringUtils.is_not_blank(request_error):
		return OpenAiCompletion.failure(request_error)
	var request := OpenAiRequest.new(model, messages, true)
	request.tools = tools
	var request_body: String = await ExecutorHelper.async_execute_pooled(request.to_json)
	var pending_build := StringBuilder.new()
	var utf8_decoder := Utf8StreamDecoder.new()
	var on_chunk := func(chunk: PackedByteArray) -> void:
		var buffer := pending_build.build_string() + utf8_decoder.push(chunk)
		pending_build.clear()
		var remaining := consume_sse_buffer(buffer, on_delta)
		pending_build.append_if_not_empty(remaining)
		pass
	var response := await HttpHelper.async_post(base_url, request_body, build_headers(true)
			, REQUEST_TIMEOUT_MILLIS, proxy, on_chunk, cancel_scope)
	## The final body carries every delta verbatim, so content / reasoning / finish_reason / usage
	## all come from that one string instead of being accumulated during streaming.
	var body := response.get_body_string()
	if not response.is_ok():
		var result := OpenAiCompletion.failure(StringUtils.format("request failed, http code:[{}], {}", response.code, response.get_error_string()))
		Log.error("OpenAI stream failed:[{}]", StringUtils.truncate(result.error, 512))
		return result
	var tail := pending_build.build_string() + utf8_decoder.flush()
	if StringUtils.is_not_empty(tail):
		consume_sse_buffer(tail + FileUtils.NEWLINE_LF, on_delta)
	var result: OpenAiCompletion = await ExecutorHelper.async_execute_pooled(parse_stream_completion.bind(body))
	if StringUtils.is_not_blank(result.error):
		Log.error("OpenAI stream failed:[{}]", result.error)
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
		if choice.delta != null and on_delta.is_valid():
			if StringUtils.is_not_empty(choice.delta.content):
				on_delta.call(choice.delta.content, STREAM_KIND_CONTENT)
			if StringUtils.is_not_empty(choice.delta.reasoning_content):
				on_delta.call(choice.delta.reasoning_content, STREAM_KIND_REASONING)
	return remaining

# ----------------------------------------------------------------------------------------------------------------------
## [OpenAiCompletion] parsed from a finished SSE body (content, reasoning, tool_calls, usage, finish_reason).
func parse_stream_completion(body: String) -> OpenAiCompletion:
	var result := OpenAiCompletion.new()
	var chunks := parse_stream_chunks(body)
	result.content = extract_stream_content(chunks)
	result.reasoning_content = extract_stream_reasoning_content(chunks)
	result.tool_calls = extract_stream_tool_calls(chunks)
	result.finish_reason = extract_finish_reason(chunks)
	result.usage = extract_stream_usage(chunks)
	result.error = extract_finish_error(result.finish_reason)
	return result


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


func extract_stream_tool_calls(chunks: Array[OpenAiStreamChunk]) -> Array[ToolCall]:
	var merged_calls: Array[ToolCall] = []
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.choices.is_empty():
			continue
		var delta := chunk.choices[0].delta
		if delta == null:
			continue
		ToolCall.merge_stream_deltas(merged_calls, delta.tool_calls)
	var tool_calls: Array[ToolCall] = []
	for call: ToolCall in merged_calls:
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


## Agent-loop failure message for provider [param finish_reason], or empty when the turn can proceed.
func extract_finish_error(finish_reason: String) -> String:
	# A turn the loop cannot act on must be reported instead of silently looking like a finished answer.
	# `stop` / `end` / `tool_calls` / `function_call` are the normal ends; anything else names the raw
	# value so an unrecognized provider reason stays visible. Missing values are left alone: not every
	# endpoint sends one, and a false failure would be worse than a silent one.
	match finish_reason:
		"", "stop", "end", "tool_calls", "function_call":
			return StringUtils.EMPTY
		"length":
			return "response truncated by the output token limit"
		"content_filter":
			return "response stopped by the provider content filter"
		"network_error":
			return "provider reported a network error"
		_:
			if StringUtils.is_not_blank(finish_reason):
				return StringUtils.format("unhandled finish_reason: {}", finish_reason)
			return StringUtils.EMPTY


func extract_stream_usage(chunks: Array[OpenAiStreamChunk]) -> OpenAiUsage:
	var usage := OpenAiUsage.new()
	for chunk: OpenAiStreamChunk in chunks:
		if chunk.usage.has_data():
			usage = chunk.usage
	return usage
