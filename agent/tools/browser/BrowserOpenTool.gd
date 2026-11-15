class_name BrowserOpenTool
extends BrowserTool

## Opens a URL in the shared browser. Observation is an explicit follow-up operation.

const NAME := "browser_open"


func _init() -> void:
	name = NAME
	description = "Open an absolute HTTP or HTTPS URL in the shared browser. Use browser_observe afterwards to read elements, Markdown, or a screenshot."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_URL, "Absolute http or https URL to open", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var url := str(args.get(ARG_URL, "")).strip_edges()
	if not HttpUtils.is_valid_http_url(url):
		return AgentToolResult.error("error: url must start with http:// or https://")
	var response := await WebServer.async_browser_open(url, cancel_scope)
	return to_result(NAME, response, cancel_scope)
# AgentTool-Interface-Implement-End
