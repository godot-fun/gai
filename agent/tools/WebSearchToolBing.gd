class_name WebSearchToolBing
extends AgentTool

## Search the web via Bing China (cn.bing.com). No API key or proxy required in mainland China.

const NAME := "bing_cn_search"
const ARG_QUERY := "query"
const ARG_MAX_RESULTS := "max_results"
const DEFAULT_MAX_RESULTS := 5
const MAX_RESULTS_CAP := 10
const SEARCH_URL := "https://cn.bing.com/search"

func _init() -> void:
	name = NAME
	description = "Search the web via Bing China (cn.bing.com). No API key or proxy required in mainland China. Use for docs, errors, APIs, or facts."
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
	var html := await fetch_search_html(query)
	if StringUtils.is_blank(html):
		var failed := StringUtils.format("error: Bing CN search request failed for: {}", query)
		return AgentToolResult.error(failed)
	var results := parse_results(html, query, max_results)
	if results.is_empty():
		var empty := StringUtils.format("No web results for: {}", query)
		return AgentToolResult.ok(empty, AgentToolResult.ui_details(NAME, empty))
	var formatted := results.format("Bing CN search results")
	return AgentToolResult.ok(formatted, AgentToolResult.ui_details(NAME, formatted))
# AgentTool-Interface-Implement-End


static func fetch_search_html(query: String) -> String:
	var url := StringUtils.format("{}?q={}&setlang=zh-CN", SEARCH_URL, query.uri_encode())
	var headers := PackedStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Accept-Language: zh-CN,zh;q=0.9,en;q=0.8",
	])
	var response := await HttpHelper.async_get(url, AsyncHttp.DEFAULT_TIMEOUT_MILLIS, "", headers)
	if not response.success or response.code != 200:
		return StringUtils.EMPTY
	return response.get_body_string()


static func parse_results(html: String, query: String, max_results: int) -> Results:
	var hits: Array[Hit] = []
	var start := 0
	while hits.size() < max_results:
		var index := html.find("<li class=\"b_algo\"", start)
		if index < 0:
			break
		var end := html.find("</li>", index)
		if end < 0:
			break
		var block := html.substr(index, end - index + "</li>".length())
		var hit := parse_result_block(block)
		if hit.is_valid():
			hits.append(hit)
		start = end + "</li>".length()
	return Results.new(query, hits)


static func parse_result_block(block: String) -> Hit:
	var link_regex := RegEx.new()
	link_regex.compile("<h2[^>]*>\\s*<a[^>]*href=\"([^\"]+)\"[^>]*>([\\s\\S]*?)</a>")
	var link_match := link_regex.search(block)
	if link_match == null:
		return Hit.new()
	var url := link_match.get_string(1).strip_edges()
	var title := strip_html(link_match.get_string(2)).strip_edges()
	var snippet := StringUtils.EMPTY
	var snippet_regex := RegEx.new()
	snippet_regex.compile("<div class=\"b_caption\"><p[^>]*>([\\s\\S]*?)</p>")
	var snippet_match := snippet_regex.search(block)
	if snippet_match != null:
		snippet = decode_html_entities(strip_html(snippet_match.get_string(1))).strip_edges()
	return Hit.new(title, url, snippet)


static func strip_html(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("<[^>]+>")
	return regex.sub(text, "", true)


static func decode_html_entities(text: String) -> String:
	var decoded := text
	decoded = decoded.replace("&nbsp;", " ")
	decoded = decoded.replace("&ensp;", " ")
	decoded = decoded.replace("&amp;", "&")
	decoded = decoded.replace("&lt;", "<")
	decoded = decoded.replace("&gt;", ">")
	decoded = decoded.replace("&quot;", "\"")
	var num_regex := RegEx.new()
	num_regex.compile("&#(\\d+);")
	for match_result: RegExMatch in num_regex.search_all(decoded):
		var code := int(match_result.get_string(1))
		decoded = decoded.replace(match_result.get_string(0), char(code))
	return decoded


class Hit extends RefCounted:
	var title: String = ""
	var url: String = ""
	var snippet: String = ""


	func _init(_title: String = "", _url: String = "", _snippet: String = "") -> void:
		title = _title
		url = _url
		snippet = _snippet
		pass


	func is_valid() -> bool:
		return StringUtils.is_not_blank(title) and StringUtils.is_not_blank(url)


class Results extends RefCounted:
	var query: String = ""
	var hits: Array[Hit] = []


	func _init(_query: String = "", _hits: Array[Hit] = []) -> void:
		query = _query
		hits = _hits
		pass


	func is_empty() -> bool:
		return hits.is_empty()


	func format(header: String) -> String:
		if hits.is_empty():
			return StringUtils.EMPTY
		var build := StringBuilder.new()
		build.append(StringUtils.format("{} for \"{}\":\n\n", header, query))
		for index in hits.size():
			var hit: Hit = hits[index]
			build.append(StringUtils.format("{}. {}\n   {}\n", index + 1, hit.title, hit.url))
			if StringUtils.is_not_blank(hit.snippet):
				build.append(StringUtils.format("   {}\n", hit.snippet))
		return build.build_string().strip_edges()
