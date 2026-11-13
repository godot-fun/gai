class_name WebSearchTool
extends AgentTool

## Search the web through the local browser server, degrading to Bing's RSS endpoint (see
## [WebFallback]) when that server or its browser is unavailable.

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
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
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
	var screenshot_path := FileUtils.globalize_writable_path(CacheManager.get_web_screenshot_cache_dir().path_join(StringUtils.format("search_{}.webp", IdUtils.uuid())))
	var response := await async_search(query, max_results, screenshot_path)
	if response == null:
		return AgentToolResult.error(StringUtils.format("error: web search request failed for: {}", query))
	if response.results.is_empty():
		var empty := StringUtils.format("No web results for: {}", query)
		return AgentToolResult.ok(empty, AgentToolResult.ui_web_details(NAME, empty, response.screenshotPath))
	var formatted := format_results(response)
	return AgentToolResult.ok(formatted, AgentToolResult.ui_web_details(NAME, formatted, response.screenshotPath))
# AgentTool-Interface-Implement-End


## Browser first; Bing's RSS endpoint when the browser server is unavailable, so a dead browser
## still yields results. Returns null when both paths failed.
static func async_search(query: String, count: int, screenshot_path: String) -> WebServer.SearchResponse:
	var response := await WebServer.async_search(query, count, screenshot_path)
	if response != null:
		if StringUtils.is_not_blank(response.screenshotError):
			Log.error("web search screenshot failed error:[{}]", response.screenshotError)
		return response
	Log.info("web search degraded to Bing RSS fallback query:[{}]", query)
	var entries := await WebFallback.async_search(query, count)
	if entries.is_empty():
		Log.error("web search fallback failed query:[{}]", query)
		return null
	var fallback := WebServer.SearchResponse.new()
	fallback.query = query
	for entry in entries:
		var result := WebServer.SearchResult.new()
		result.position = fallback.results.size() + 1
		result.title = str(entry.get("title", StringUtils.EMPTY))
		result.url = str(entry.get("url", StringUtils.EMPTY))
		result.snippet = str(entry.get("snippet", StringUtils.EMPTY))
		fallback.results.append(result)
	return fallback


static func format_results(response: WebServer.SearchResponse) -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("web search results for \"{}\":\n\n", response.query))
	for result in response.results:
		build.append(StringUtils.format("{}. {}\n   {}\n", result.position, result.title, result.url))
		if StringUtils.is_not_blank(result.snippet):
			build.append(StringUtils.format("   {}\n", result.snippet))
	return build.build_string().strip_edges()
