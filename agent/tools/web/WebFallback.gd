class_name WebFallback
extends Object

## Last-resort web access when the browser server cannot start or its Camoufox browser is gone:
## plain HTTP through the configured proxy, then a local text extraction. It is a degradation,
## not a replacement — no JavaScript, no anti-bot handling, no screenshot, and no main-content
## heuristics beyond preferring <article>/<main>.
##
## Every entry point returns an empty value on failure so the tools keep their browser-first
## contract: null still means "the web request failed".

const DEFAULT_TIMEOUT_MILLIS: int = 10 * TimeUtils.MILLIS_PER_SECOND
const USER_AGENT: String = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
const BING_RSS_URL: String = "https://www.bing.com/search"
const CONTENT_TYPE_TEXT: String = "text"
## Payload types that decode into readable text. Anything else (a PDF, an image) turns into
## replacement characters and must not be handed to the model as if it were the page.
const TEXT_MIME_TYPES: PackedStringArray = ["application/xhtml+xml", "application/xml", "application/json"]

## Escape hatch: false restores the browser-only behavior.
static var enabled: bool = true


## Fetches the page over plain HTTP and extracts its article. Returns null when the page is
## unreachable, carries a binary payload, or declares a charset that cannot be decoded.
static func async_fetch(url: String, cancel_scope: CancelScope) -> HtmlHelper.Article:
	if not enabled:
		return null
	var response := await HttpHelper.async_get(url, DEFAULT_TIMEOUT_MILLIS, ApiSetting.get_proxy_address(), build_headers(), cancel_scope)
	if not response.is_ok_with_body():
		Log.info("web fallback fetch failed url:[{}] code:[{}] error:[{}]", url, response.code, response.error)
		return null
	var content_type := response.get_header("Content-Type")
	if not is_text_payload(content_type):
		Log.info("web fallback unsupported content type url:[{}] type:[{}]", url, content_type)
		return null
	var head := response.body.slice(0, HtmlHelper.CHARSET_SNIFF_CHARS).get_string_from_utf8()
	var charset := HtmlHelper.get_declared_charset(head, content_type)
	if not HtmlHelper.is_supported_charset(charset):
		Log.info("web fallback unsupported charset url:[{}] charset:[{}]", url, charset)
		return null
	# Decoding and the regex pass are the expensive part of a fallback fetch (20 MB of HTML measured ~6 s
	# here), so they run on the worker pool. The callable stays free of logging and scene-tree access.
	var body := response.body
	var article: HtmlHelper.Article = await ExecutorHelper.async_execute_pooled(func() -> HtmlHelper.Article:
		return HtmlHelper.extract(body.get_string_from_utf8())
	)
	if article == null:
		Log.info("web fallback extracted nothing url:[{}]", url)
	return article


## Searches through Bing's RSS endpoint and returns at most [param count] results.
static func async_search(query: String, count: int, cancel_scope: CancelScope) -> Array[SearchResult]:
	if not enabled:
		return []
	var url := "%s?format=rss&q=%s" % [BING_RSS_URL, query.strip_edges().uri_encode()]
	var response := await HttpHelper.async_get(url, DEFAULT_TIMEOUT_MILLIS, ApiSetting.get_proxy_address(), build_headers(), cancel_scope)
	if not response.is_ok_with_body():
		Log.info("web fallback search failed query:[{}] code:[{}] error:[{}]", query, response.code, response.error)
		return []
	# Same deal as [method async_fetch]: parsing stays off the main thread so a huge feed cannot stall it.
	var body := response.body
	var results: Array[SearchResult] = await ExecutorHelper.async_execute_pooled(func() -> Array[SearchResult]:
		return BingRssParser.parse(body.get_string_from_utf8())
	)
	if results.size() > count:
		results.resize(count)
	return results


## True when the response carries text: a missing Content-Type counts as HTML, and every `text/*`
## subtype decodes fine, so the check only has to reject the binary families.
static func is_text_payload(content_type: String) -> bool:
	var mime := content_type.get_slice(";", 0).strip_edges().to_lower()
	if mime.is_empty():
		return true
	return mime.begins_with("text/") or TEXT_MIME_TYPES.has(mime)


static func build_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
		"Accept-Language: zh-CN,zh;q=0.9,en;q=0.8",
	])
