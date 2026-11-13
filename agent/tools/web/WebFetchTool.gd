class_name WebFetchTool
extends AgentTool

## Fetch a URL through the local browser server, degrading to plain HTTP with a local text
## extraction (see [WebFallback]) when that server or its browser is unavailable.

const NAME := "web_fetch"
const ARG_URL := "url"
const ARG_MAX_CHARS := "max_chars"

const DEFAULT_MAX_CHARS := 80_000
const MAX_CHARS_CAP := 200_000


func _init() -> void:
	name = NAME
	description = "Fetch a web page by URL and return readable Markdown (for docs, API pages, or linked articles)."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_URL, "HTTP or HTTPS URL to fetch", true)
	params.integer_prop(ARG_MAX_CHARS, "Maximum characters to return (default 80000, max 200000)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var url := str(args.get(ARG_URL, "")).strip_edges()
	if url.is_empty():
		return AgentToolResult.error("error: url is required")
	if not url.begins_with("http://") and not url.begins_with("https://"):
		return AgentToolResult.error("error: url must start with http:// or https://")
	var max_chars := DEFAULT_MAX_CHARS
	if args.has(ARG_MAX_CHARS) and str(args.get(ARG_MAX_CHARS, "")).strip_edges().is_valid_int():
		max_chars = clampi(int(str(args.get(ARG_MAX_CHARS, "")).strip_edges()), 1_000, MAX_CHARS_CAP)
	var screenshot_path := FileUtils.globalize_writable_path(CacheManager.get_web_screenshot_cache_dir().path_join(StringUtils.format("fetch_{}.webp", IdUtils.uuid())))
	var page := await async_fetch(url, screenshot_path)
	if page.is_empty():
		return AgentToolResult.error(StringUtils.format("error: fetch failed: {}", url))
	var content := str(page.get("content", StringUtils.EMPTY))
	if StringUtils.is_blank(content):
		return AgentToolResult.error(StringUtils.format("error: empty response from {}", url))
	var text := StringUtils.truncate(content.strip_edges(), max_chars, FileUtils.NEWLINE_LF + TRUNCATED_SUFFIX)
	return AgentToolResult.ok(text, AgentToolResult.ui_web_details(NAME, text, str(page.get("screenshotPath", StringUtils.EMPTY))))
# AgentTool-Interface-Implement-End


## Browser first; plain HTTP when the browser server is unavailable, so a dead browser still fetches.
## Returns {content, screenshotPath} or an empty dictionary when both paths failed.
static func async_fetch(url: String, screenshot_path: String) -> Dictionary:
	var response := await WebServer.async_fetch(url, screenshot_path)
	if response != null:
		if StringUtils.is_not_blank(response.screenshotError):
			Log.error("web fetch screenshot failed error:[{}]", response.screenshotError)
		return {"content": response.content, "screenshotPath": response.screenshotPath}
	Log.info("web fetch degraded to HTTP fallback url:[{}]", url)
	var fallback := await WebFallback.async_fetch(url)
	if fallback.is_empty():
		Log.error("web fetch fallback failed url:[{}]", url)
		return {}
	return {"content": str(fallback.get("content", StringUtils.EMPTY)), "screenshotPath": StringUtils.EMPTY}
