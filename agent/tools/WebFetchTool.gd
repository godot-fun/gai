class_name WebFetchTool
extends AgentTool

## Fetch a URL and return plain text (HTML stripped).

const NAME := "web_fetch"
const ARG_URL := "url"
const ARG_MAX_CHARS := "max_chars"

const DEFAULT_MAX_CHARS := 80_000
const MAX_CHARS_CAP := 200_000


var proxy_address: String = ""


func _init(detected_proxy_address: String = "") -> void:
	proxy_address = detected_proxy_address
	name = NAME
	description = "Fetch a web page by URL and return readable plain text (for docs, API pages, or linked articles)."
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
	var headers := PackedStringArray([
		"User-Agent: Mozilla/5.0 (compatible; GodotCodeAgent/1.0)",
		"Accept: text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8",
	])
	var response := await HttpHelper.async_get(url, AsyncHttp.DEFAULT_TIMEOUT_MILLIS, proxy_address, headers)
	if not response.success:
		return AgentToolResult.error(StringUtils.format("error: fetch failed (HTTP {}): {}", response.code, url))
	var body := response.get_body_string()
	if StringUtils.is_blank(body):
		return AgentToolResult.error(StringUtils.format("error: empty response from {}", url))
	var text := html_to_text(body)
	if StringUtils.is_blank(text):
		text = body.strip_edges()
	text = StringUtils.truncate(text, max_chars, FileUtils.NEWLINE_LF + TRUNCATED_SUFFIX)
	var title := StringUtils.format("Fetched {}", url)
	return AgentToolResult.ok(text, AgentToolResult.ui_details(title, text))


static func html_to_text(html: String) -> String:
	# (?is) = caseless + dotall — Godot 4 RegEx.compile() has no flag argument.
	var text := html
	var script := RegEx.new()
	script.compile("(?is)<script[^>]*>.*?</script>")
	text = script.sub(text, "", true)
	var style := RegEx.new()
	style.compile("(?is)<style[^>]*>.*?</style>")
	text = style.sub(text, "", true)
	var block_tags := RegEx.new()
	block_tags.compile("(?i)</?(?:br|p|div|h[1-6]|li|tr|table|section|article|header|footer|nav)[^>]*>")
	text = block_tags.sub(text, FileUtils.NEWLINE_LF, true)
	var strip := RegEx.new()
	strip.compile("(?i)<[^>]+>")
	text = strip.sub(text, " ", true)
	text = decode_basic_entities(text)
	text = collapse_whitespace(text)
	return text.strip_edges()


static func decode_basic_entities(text: String) -> String:
	var out := text
	out = out.replace("&nbsp;", " ")
	out = out.replace("&amp;", "&")
	out = out.replace("&lt;", "<")
	out = out.replace("&gt;", ">")
	out = out.replace("&quot;", "\"")
	out = out.replace("&#39;", "'")
	return out


static func collapse_whitespace(text: String) -> String:
	var spaces := RegEx.new()
	spaces.compile("\\s+")
	var lines: PackedStringArray = PackedStringArray()
	for line in text.split(FileUtils.NEWLINE_LF, false):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		lines.append(spaces.sub(trimmed, " ", true))
	return FileUtils.NEWLINE_LF.join(lines)
# AgentTool-Interface-Implement-End
