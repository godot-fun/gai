class_name WebSearchTool
extends AgentTool

## Search the web through the local browser server.

const NAME := "web_search"
const ARG_QUERY := "query"
const ARG_MAX_RESULTS := "max_results"
const DEFAULT_MAX_RESULTS := 5
const MAX_RESULTS_CAP := 10


func _init() -> void:
	name = NAME
	description = "Search the web via Browser. No API key required. Use for docs, errors, APIs, or facts."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_QUERY, "Search query", true)
	params.integer_prop(ARG_MAX_RESULTS, "Maximum number of results (1-10, default 5)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var query := str(args.get(ARG_QUERY, "")).strip_edges()
	if query.is_empty():
		return AgentToolResult.error("error: query is required")
	var max_results := DEFAULT_MAX_RESULTS
	if args.has(ARG_MAX_RESULTS):
		max_results = clampi(int(str(args.get(ARG_MAX_RESULTS, DEFAULT_MAX_RESULTS))), 1, MAX_RESULTS_CAP)
	var response := await WebServer.async_search(query, max_results)
	if response == null:
		return AgentToolResult.error(StringUtils.format("error: web search request failed for: {}", query))
	if response.results.is_empty():
		var empty := StringUtils.format("No web results for: {}", query)
		return AgentToolResult.ok(empty, AgentToolResult.ui_details(NAME, empty))
	var formatted := format_results(response)
	return AgentToolResult.ok(formatted, AgentToolResult.ui_details(NAME, formatted))
# AgentTool-Interface-Implement-End


static func format_results(response: WebServer.SearchResponse) -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("web search results for \"{}\":\n\n", response.query))
	for result in response.results:
		build.append(StringUtils.format("{}. {}\n   {}\n", result.position, result.title, result.url))
		if StringUtils.is_not_blank(result.snippet):
			build.append(StringUtils.format("   {}\n", result.snippet))
	return build.build_string().strip_edges()
