class_name BingRssParser
extends Object

## Parses Bing's RSS search feed (`/search?format=rss`) into ranked [SearchResult] rows.
## Field-based XML with a fixed schema, so it is matched with regular expressions: Godot's
## XMLParser cannot return CDATA text, and a search snippet may wrap its highlight markup in CDATA.

const MAX_RESULT_COUNT: int = 100

static var re_item: RegEx = RegEx.create_from_string(r"(?is)<item\b[^>]*>(.*?)</item\s*>")
static var re_title: RegEx = RegEx.create_from_string(r"(?is)<title\b[^>]*>(.*?)</title\s*>")
static var re_link: RegEx = RegEx.create_from_string(r"(?is)<link\b[^>]*>(.*?)</link\s*>")
static var re_description: RegEx = RegEx.create_from_string(r"(?is)<description\b[^>]*>(.*?)</description\s*>")
static var re_cdata: RegEx = RegEx.create_from_string(r"(?s)<!\[CDATA\[(.*?)\]\]>")


## Returns the feed entries in feed order, numbered by [member SearchResult.position].
## Blank titles, non-HTTP(S) links, and duplicate URLs are dropped.
static func parse(xml: String) -> Array[SearchResult]:
	var results: Array[SearchResult] = []
	if StringUtils.is_blank(xml):
		return results
	var seen: Dictionary = {}
	for item_match in re_item.search_all(xml):
		var entry_xml := item_match.get_string(1)
		var title := field(re_title, entry_xml)
		var url := field(re_link, entry_xml)
		if title.is_empty() or not is_http_url(url) or seen.has(url):
			continue
		seen[url] = true
		var result := SearchResult.new()
		result.position = results.size() + 1
		result.title = title
		result.url = url
		result.snippet = field(re_description, entry_xml)
		results.append(result)
		if results.size() >= MAX_RESULT_COUNT:
			break
	return results


static func field(regex: RegEx, item: String) -> String:
	var found := regex.search(item)
	if found == null:
		return StringUtils.EMPTY
	return HtmlHelper.to_inline_text(unwrap_cdata(found.get_string(1)))


static func unwrap_cdata(text: String) -> String:
	var found := re_cdata.search(text)
	return found.get_string(1) if found != null else text


static func is_http_url(url: String) -> bool:
	return url.begins_with("http://") or url.begins_with("https://")
