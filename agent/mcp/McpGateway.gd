class_name McpGateway
extends Object

## Model-visible text when a call succeeds with neither `content` blocks nor `structuredContent`.
const EMPTY_RESULT_TEXT := "(MCP tool returned no content)"
## Marks the machine-readable payload so it is not confused with the tool's own text output.
const STRUCTURED_CONTENT_LABEL := "[structuredContent] "

static func async_list_tools() -> Array[Dictionary]:
	if await WebServer.async_ensure_server_running() != OK:
		return []
	var response := await HttpHelper.async_get(WebServer.server_url() + "/mcp/tools", WebServer.REQUEST_TIMEOUT_MILLIS)
	if not response.is_ok():
		Log.error("MCP tool listing failed code:[{}] error:[{}]", response.code, describe_error(response))
		return []
	var body = response.get_body_json()
	if typeof(body) != TYPE_DICTIONARY or typeof(body.get("tools")) != TYPE_ARRAY:
		Log.error("MCP tool listing returned invalid JSON")
		return []
	var result: Array[Dictionary] = []
	result.assign(body.tools)
	return result


static func async_call_tool(server: String, tool_name: String, args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var payload := {"server": server, "name": tool_name, "arguments": args}
	var response := await HttpHelper.async_post(WebServer.server_url() + "/mcp/call", JsonUtils.object_to_json(payload), PackedStringArray(), WebServer.REQUEST_TIMEOUT_MILLIS, "", Callable(), cancel_scope)
	if not response.is_ok():
		return AgentToolResult.error(describe_error(response))
	var body = response.get_body_json()
	if typeof(body) != TYPE_DICTIONARY:
		return AgentToolResult.error("MCP tool returned invalid JSON")
	var text := describe_result(body)
	return AgentToolResult.error(text) if body.get("isError", false) else AgentToolResult.ok(text)


## Full model-visible text of a `tools/call` result: the content blocks, then the structured payload.
static func describe_result(body: Dictionary) -> String:
	var text := join_content_blocks(body.get("content"))
	if body.has("structuredContent"):
		text += ("\n" if StringUtils.is_not_blank(text) else StringUtils.EMPTY) + STRUCTURED_CONTENT_LABEL + JsonUtils.object_to_json(body.structuredContent)
	if StringUtils.is_blank(text):
		text = EMPTY_RESULT_TEXT
	return truncate_output(text)


## Gateway failures arrive as `{"error":{"code","message"}}`; the model needs the reason, not the
## envelope. Falls back to [method HttpResponse.get_error_string] for transport failures and for
## bodies that are not a gateway payload.
static func describe_error(response: HttpResponse) -> String:
	var text := response.get_body_string().strip_edges()
	if text.begins_with("{"):
		var body: Variant = JSON.parse_string(text)
		if typeof(body) == TYPE_DICTIONARY and typeof(body.get("error")) == TYPE_DICTIONARY:
			var error: Dictionary = body.get("error")
			var message := str(error.get("message", StringUtils.EMPTY))
			if StringUtils.is_not_blank(message):
				return StringUtils.format("MCP call failed status:[{}] code:[{}] message:[{}]", response.code, str(error.get("code", StringUtils.EMPTY)), message)
	return response.get_error_string()


## Joins every `content[]` entry. A missing or `null` `content` (the spec still allows it) yields an
## empty string instead of failing to iterate.
static func join_content_blocks(content: Variant) -> String:
	if typeof(content) != TYPE_ARRAY:
		return StringUtils.EMPTY
	var parts: PackedStringArray = []
	for item: Variant in content:
		parts.append(describe_content_block(item))
	return "\n".join(parts)


## Keeps MCP output inside the same budget as the builtin tools ([constant AgentTool.MAX_OUTPUT]).
static func truncate_output(text: String) -> String:
	return StringUtils.truncate(text, AgentTool.MAX_OUTPUT, AgentTool.TRUNCATED_SUFFIX)


## One `content[]` entry as model-readable text. Non-text blocks keep a placeholder instead of being
## dropped, so an image-only or resource-only result still tells the model what came back.
static func describe_content_block(item: Variant) -> String:
	if typeof(item) != TYPE_DICTIONARY:
		return str(item)
	var block: Dictionary = item
	var block_type := str(block.get("type", StringUtils.EMPTY))
	match block_type:
		"text":
			return str(block.get("text", StringUtils.EMPTY))
		"image", "audio":
			var mime := str(block.get("mimeType", StringUtils.EMPTY))
			var encoded_length := str(block.get("data", StringUtils.EMPTY)).length()
			return StringUtils.format("[{} mime:[{}] base64:~{} chars]", block_type, mime, encoded_length)
		"resource_link":
			return StringUtils.format("[resource link] name:[{}] uri:[{}] description:[{}]", str(block.get("name", StringUtils.EMPTY)), str(block.get("uri", StringUtils.EMPTY)), str(block.get("description", StringUtils.EMPTY)))
		"resource":
			return describe_embedded_resource(block.get("resource"))
	return StringUtils.format("[{} block] {}", block_type, JSON.stringify(block))


## `resource` content block: inline text when present, otherwise the blob size.
static func describe_embedded_resource(resource: Variant) -> String:
	if typeof(resource) != TYPE_DICTIONARY:
		return StringUtils.format("[embedded resource] {}", JSON.stringify(resource))
	var uri := str(resource.get("uri", StringUtils.EMPTY))
	var mime := str(resource.get("mimeType", StringUtils.EMPTY))
	if typeof(resource.get("text")) == TYPE_STRING:
		return StringUtils.format("[embedded resource] uri:[{}] mime:[{}]\n{}", uri, mime, str(resource.get("text")))
	var blob_length := str(resource.get("blob", StringUtils.EMPTY)).length()
	return StringUtils.format("[embedded resource] uri:[{}] mime:[{}] blob:~{} chars]", uri, mime, blob_length)
