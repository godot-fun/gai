class_name WebFetchTool
extends AgentTool

## Fetch a URL through the local browser server and return extracted Markdown.

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
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
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
	var screenshot_path := FileUtils.globalize_writable_path(AgentWorkspace.get_root().path_join(WEB_SCREENSHOT_DIR).path_join(StringUtils.format("fetch_{}.webp", IdUtils.uuid())))
	var response := await WebServer.async_fetch(url, screenshot_path)
	if response == null:
		return AgentToolResult.error(StringUtils.format("error: fetch failed: {}", url))
	if StringUtils.is_not_blank(response.screenshotError):
		Log.error("web fetch screenshot failed error:[{}]", response.screenshotError)
	if StringUtils.is_blank(response.content):
		return AgentToolResult.error(StringUtils.format("error: empty response from {}", url))
	var text := StringUtils.truncate(response.content.strip_edges(), max_chars, FileUtils.NEWLINE_LF + TRUNCATED_SUFFIX)
	return AgentToolResult.ok(text, AgentToolResult.ui_web_details(NAME, text, response.screenshotPath))
# AgentTool-Interface-Implement-End
