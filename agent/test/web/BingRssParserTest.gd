## Offline tests for the Bing RSS feed parsing used by the degraded web search fallback.

const SAMPLE_RSS: String = "<?xml version=\"1.0\" encoding=\"utf-8\" ?><rss version=\"2.0\"><channel>" \
	+ "<title>Bing: godot engine</title><link>http://www.bing.com:80/search?q=godot</link>" \
	+ "<item><title>Godot &amp; Engine</title><link>https://godotengine.org/</link><description>Free &amp; open source</description></item>" \
	+ "<item><title>Second result</title><link>https://example.com/2</link><description><![CDATA[<b>bold</b> text]]></description></item>" \
	+ "<item><title>Duplicate url</title><link>https://godotengine.org/</link><description>dup</description></item>" \
	+ "<item><title>Non http link</title><link>ftp://example.com/file</link><description>bad</description></item>" \
	+ "<item><title></title><link>https://example.com/3</link><description>no title</description></item>" \
	+ "</channel></rss>"


func parse_results_test() -> void:
	var results := BingRssParser.parse(SAMPLE_RSS)
	assert(results.size() == 2)
	assert(results[0].title == "Godot & Engine")
	assert(results[0].url == "https://godotengine.org/")
	assert(results[0].snippet == "Free & open source")
	assert(results[1].title == "Second result")
	assert(results[1].url == "https://example.com/2")
	assert(results[1].snippet == "bold text")
	pass


func parse_empty_test() -> void:
	assert(BingRssParser.parse(StringUtils.EMPTY).is_empty())
	assert(BingRssParser.parse("<rss><channel></channel></rss>").is_empty())
	pass


func parse_caps_result_count_test() -> void:
	var build := StringBuilder.new()
	build.append("<rss><channel>")
	for index in BingRssParser.MAX_RESULT_COUNT + 5:
		build.append(StringUtils.format("<item><title>t{}</title><link>https://example.com/{}</link></item>", index, index))
	build.append("</channel></rss>")
	assert(BingRssParser.parse(build.build_string()).size() == BingRssParser.MAX_RESULT_COUNT)
	pass
