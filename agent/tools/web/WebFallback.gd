class_name WebFallback
extends Object

## Last-resort web access when the browser server cannot start or its Camoufox browser is gone:
## plain HTTP through the configured proxy, then a local text extraction. It is a degradation,
## not a replacement — no JavaScript, no anti-bot handling, no screenshot, and no main-content
## heuristics beyond preferring <article>/<main>.
##
## Every entry point returns an empty value on failure so [WebServer] keeps its browser-first
## contract: null still means "the web request failed".

const DEFAULT_TIMEOUT_MILLIS: int = 10 * TimeUtils.MILLIS_PER_SECOND
const MAX_BODY_BYTES: int = 5 * 1024 * 1024
const USER_AGENT: String = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
const BING_RSS_URL: String = "https://www.bing.com/search"
const CONTENT_TYPE_TEXT: String = "text"

## Escape hatch: false restores the browser-only behavior.
static var enabled: bool = true


## Fetches the page over plain HTTP and extracts its text.
## Returns {title, description, content, wordCount, url, finalUrl, contentType} or {} on failure.
static func async_fetch(url: String) -> Dictionary:
	if not enabled:
		return {}
	var response := await HttpHelper.async_get(url, DEFAULT_TIMEOUT_MILLIS, ApiSetting.get_proxy_address(), build_headers())
	if not has_body(response):
		Log.info("web fallback fetch failed url:[{}] code:[{}] error:[{}]", url, response.code, response.error)
		return {}
	var html := read_text(response)
	var charset := HtmlHelper.get_declared_charset(html, response.get_header("Content-Type"))
	if not HtmlHelper.is_supported_charset(charset):
		Log.info("web fallback unsupported charset url:[{}] charset:[{}]", url, charset)
		return {}
	var page := HtmlHelper.extract(html)
	if page.is_empty():
		Log.info("web fallback extracted nothing url:[{}]", url)
		return {}
	# HttpHelper follows redirects internally and does not report the final URL, so the request URL stands in.
	page["url"] = url
	page["finalUrl"] = url
	page["contentType"] = CONTENT_TYPE_TEXT
	return page


## Searches through Bing's RSS endpoint and returns [{title, url, snippet}] capped at [param count].
static func async_search(query: String, count: int) -> Array[Dictionary]:
	if not enabled:
		return []
	var url := "%s?format=rss&q=%s" % [BING_RSS_URL, query.strip_edges().uri_encode()]
	var response := await HttpHelper.async_get(url, DEFAULT_TIMEOUT_MILLIS, ApiSetting.get_proxy_address(), build_headers())
	if not has_body(response):
		Log.info("web fallback search failed query:[{}] code:[{}] error:[{}]", query, response.code, response.error)
		return []
	var results := BingRssParser.parse(read_text(response))
	if results.size() > count:
		results.resize(count)
	return results


## True when the exchange produced a usable 2xx payload. [method HttpResponse.is_ok] alone rejects a
## server that answers with `Connection: close`: the body arrives, then the peer close is reported as
## a transport error, and for a text extraction a complete body beats an empty result.
static func has_body(response: HttpResponse) -> bool:
	if response.is_ok():
		return true
	if response.code < HTTPClient.RESPONSE_OK or response.code >= HTTPClient.RESPONSE_MULTIPLE_CHOICES:
		return false
	if response.body.is_empty():
		return false
	Log.info("web fallback kept a closed-connection body code:[{}] size:[{}]", response.code, response.body.size())
	return true


## Decodes the body as UTF-8 and caps it so a hostile or huge page cannot blow up the extraction.
static func read_text(response: HttpResponse) -> String:
	var body := response.body
	if body.size() > MAX_BODY_BYTES:
		Log.info("web fallback truncated body size:[{}] cap:[{}]", body.size(), MAX_BODY_BYTES)
		body = body.slice(0, MAX_BODY_BYTES)
	return body.get_string_from_utf8()


static func build_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
		"Accept-Language: zh-CN,zh;q=0.9,en;q=0.8",
	])
