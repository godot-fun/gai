class_name WebSearchToolProxy
extends AgentTool

## Search the web via DuckDuckGo (no API key required).

const NAME := "web_search"
const ARG_QUERY := "query"
const ARG_MAX_RESULTS := "max_results"
const DEFAULT_MAX_RESULTS := 5
const MAX_RESULTS_CAP := 10
const DDG_API_URL := "https://api.duckduckgo.com/"
const DDG_LITE_URL := "https://lite.duckduckgo.com/lite/"

var proxy_address: String = ""

func _init(detected_proxy_address: String = "") -> void:
	proxy_address = detected_proxy_address
	name = NAME
	description = "Search the web for documentation, API references, error messages, release notes, or general facts."
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
	var api_text := await search_ddg_api(query, max_results, proxy_address)
	if StringUtils.is_not_blank(api_text):
		return AgentToolResult.ok(api_text, AgentToolResult.ui_details(NAME, api_text))
	var lite_text := await search_ddg_lite(query, max_results, proxy_address)
	if StringUtils.is_not_blank(lite_text):
		return AgentToolResult.ok(lite_text, AgentToolResult.ui_details(NAME, lite_text))
	var empty := StringUtils.format("No web results for: {}", query)
	return AgentToolResult.ok(empty, AgentToolResult.ui_details(NAME, empty))
# AgentTool-Interface-Implement-End

static func search_ddg_api(query: String, max_results: int, proxy_address: String) -> String:
	var url := StringUtils.format(
		"{}?q={}&format=json&no_html=1&skip_disambig=1",
		DDG_API_URL,
		query.uri_encode()
	)
	var response := await HttpHelper.async_get(url, AsyncHttp.DEFAULT_TIMEOUT_MILLIS, proxy_address)
	if not response.success or response.code != 200:
		return StringUtils.EMPTY
	var data = response.get_body_json()
	if typeof(data) != TYPE_DICTIONARY:
		return StringUtils.EMPTY
	return format_api_results(data as Dictionary, query, max_results)


static func format_api_results(data: Dictionary, query: String, max_results: int) -> String:
	var build := StringBuilder.new()
	var abstract := str(data.get("Abstract", "")).strip_edges()
	var abstract_url := str(data.get("AbstractURL", "")).strip_edges()
	if StringUtils.is_not_blank(abstract):
		build.append("Summary: ")
		build.append(abstract)
		if StringUtils.is_not_blank(abstract_url):
			build.append(FileUtils.NEWLINE_LF + "URL: " + abstract_url)
		build.append(FileUtils.NEWLINE_LF + FileUtils.NEWLINE_LF)
	var hits := collect_related_topics(data.get("RelatedTopics", []), max_results)
	for index in hits.size():
		var hit: Dictionary = hits[index]
		build.append(StringUtils.format("{}. {}\n   {}", index + 1, hit.get("title", ""), hit.get("url", "")))
		var snippet := str(hit.get("snippet", "")).strip_edges()
		if StringUtils.is_not_blank(snippet):
			build.append(FileUtils.NEWLINE_LF + "   " + snippet)
		build.append(FileUtils.NEWLINE_LF)
	if build.is_empty():
		return StringUtils.EMPTY
	return StringUtils.format("Web search results for \"{}\":\n\n{}", query, build.build_string()).strip_edges()


static func collect_related_topics(raw_topics: Variant, max_results: int) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	collect_topics_recursive(raw_topics, hits, max_results)
	return hits


static func collect_topics_recursive(raw_topics: Variant, hits: Array[Dictionary], max_results: int) -> void:
	if hits.size() >= max_results or typeof(raw_topics) != TYPE_ARRAY:
		return
	for raw: Variant in raw_topics:
		if hits.size() >= max_results:
			return
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var topic: Dictionary = raw
		if topic.has("Topics"):
			collect_topics_recursive(topic.get("Topics", []), hits, max_results)
			continue
		var url := str(topic.get("FirstURL", "")).strip_edges()
		var text := str(topic.get("Text", "")).strip_edges()
		if url.is_empty() or text.is_empty():
			continue
		hits.append({"title": text, "url": url, "snippet": ""})


static func search_ddg_lite(query: String, max_results: int, proxy_address: String) -> String:
	var body := StringUtils.format("q={}", query.uri_encode())
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var response := await HttpHelper.async_post(DDG_LITE_URL, body, headers, AsyncHttp.DEFAULT_TIMEOUT_MILLIS, proxy_address)
	if not response.success or response.code != 200:
		return StringUtils.EMPTY
	return format_lite_results(response.get_body_string(), query, max_results)


static func format_lite_results(html: String, query: String, max_results: int) -> String:
	var regex := RegEx.new()
	regex.compile("<a[^>]*rel=\"nofollow\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>")
	var matches := regex.search_all(html)
	if matches.is_empty():
		return StringUtils.EMPTY
	var build := StringBuilder.new()
	build.append(StringUtils.format("Web search results for \"{}\":\n\n", query))
	var count := 0
	for match_result: RegExMatch in matches:
		if count >= max_results:
			break
		var url := decode_result_url(match_result.get_string(1))
		var title := match_result.get_string(2).strip_edges()
		if url.is_empty() or title.is_empty():
			continue
		count += 1
		build.append(StringUtils.format("{}. {}\n   {}\n", count, title, url))
	if count == 0:
		return StringUtils.EMPTY
	return build.build_string().strip_edges()


static func decode_result_url(raw_url: String) -> String:
	var url := raw_url.strip_edges()
	if url.begins_with("//"):
		url = "https:" + url
	if url.contains("uddg="):
		var encoded := StringUtils.substring_after(url, "uddg=")
		if encoded.contains("&"):
			encoded = StringUtils.substring_before(encoded, "&")
		url = encoded.uri_decode()
	return url
