class_name AgentTool
extends RefCounted

## Base tool definition. Each tool exposes an OpenAI function schema and async_execute() returning AgentToolResult.

const MAX_OUTPUT := 32_000
const MAX_FILE_RESULTS := 512
const MAX_FILE_BYTES := FileUtils.BYTES_PER_KB * 128
const ARG_PARSE_ERROR := "__agent_tool_parse_error"
const TRUNCATED_SUFFIX := "... (truncated)"


var name: String = ""
var description: String = ""


func get_schema() -> OpenAiToolDef:
	var def := OpenAiToolDef.new()
	def.function.name = name
	def.function.description = description
	def.function.parameters = get_parameters()
	return def


func get_parameters() -> OpenAiToolDef.Parameters:
	return OpenAiToolDef.Parameters.new()


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	return AgentToolResult.error("not implemented")


func parse_args(raw: String) -> Dictionary[String, Variant]:
	var args: Dictionary[String, Variant] = {}
	if StringUtils.is_blank(raw):
		return args
	var json := JSON.new()
	var parse_error := json.parse(raw.strip_edges())
	if parse_error != OK:
		args[ARG_PARSE_ERROR] = StringUtils.format("invalid tool arguments JSON: {}", json.get_error_message())
		return args
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		args[ARG_PARSE_ERROR] = "tool arguments must be a JSON object"
		return args
	args.assign(data)
	return args
