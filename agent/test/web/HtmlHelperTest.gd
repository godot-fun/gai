## Offline tests for the HTML-to-text extraction used by the degraded web fallback.

func extract_prefers_article_test() -> void:
	var html := "<html><head><title>Docs &amp; API</title><meta name=\"description\" content=\"Fast engine\"></head>" \
		+ "<body><nav>menu item</nav><article><h1>Intro</h1><p>alpha <b>beta</b> gamma</p><ul><li>one</li><li>two</li></ul></article>" \
		+ "<footer>footer text</footer></body></html>"
	var article := HtmlHelper.extract(html)
	assert(article.title == "Docs & API")
	assert(article.description == "Fast engine")
	assert("alpha beta gamma" in article.content)
	assert("- one" in article.content)
	assert("- two" in article.content)
	assert("menu item" not in article.content)
	assert("footer text" not in article.content)
	pass


func extract_prefers_main_test() -> void:
	var article := HtmlHelper.extract("<body><div>sidebar</div><main><p>main text</p></main></body>")
	assert("main text" in article.content)
	assert("sidebar" not in article.content)
	pass


func extract_drops_noise_elements_test() -> void:
	var html := "<body><script>var x = 1 < 2;</script><style>.a{color:red}</style><p>visible</p><!-- note --></body>"
	var article := HtmlHelper.extract(html)
	assert("visible" in article.content)
	assert("var x" not in article.content)
	assert("color:red" not in article.content)
	assert("note" not in article.content)
	pass


func extract_decodes_entities_test() -> void:
	var article := HtmlHelper.extract("<p>a&nbsp;&amp;&nbsp;b &#39;c&#39; &#65; &lt;tag&gt;</p>")
	assert(article.content == "a & b 'c' A <tag>")
	pass


func decode_named_entities_test() -> void:
	assert(HtmlHelper.to_inline_text("Godot Docs &mdash; 4.7 &hellip; &copy; 2026") == "Godot Docs — 4.7 … © 2026")
	assert(HtmlHelper.to_inline_text("keep &unknownentity; as is") == "keep &unknownentity; as is")
	pass


func extract_separates_blocks_test() -> void:
	var article := HtmlHelper.extract("<p>first</p><p>second</p>")
	assert(article.content == "first\n\nsecond")
	pass


func extract_empty_test() -> void:
	assert(HtmlHelper.extract("   ") == null)
	pass


func declared_charset_test() -> void:
	assert(HtmlHelper.get_declared_charset("<html><head><meta charset=\"gbk\"></head></html>", "text/html") == "gbk")
	assert(HtmlHelper.get_declared_charset("", "text/html; charset=UTF-8") == "utf-8")
	assert(HtmlHelper.get_declared_charset("<html></html>", "text/html") == StringUtils.EMPTY)
	pass


func supported_charset_test() -> void:
	assert(HtmlHelper.is_supported_charset(""))
	assert(HtmlHelper.is_supported_charset("UTF-8"))
	assert(!HtmlHelper.is_supported_charset("gbk"))
	assert(!HtmlHelper.is_supported_charset("shift_jis"))
	pass


func count_words_test() -> void:
	assert(HtmlHelper.count_words("a b  c") == 3)
	assert(HtmlHelper.count_words("") == 0)
	pass


func to_inline_text_test() -> void:
	assert(HtmlHelper.to_inline_text("  <b>a</b>\n  b  ") == "a b")
	assert(HtmlHelper.to_inline_text("") == StringUtils.EMPTY)
	pass
