class_name HtmlHelper
extends Object

## Turns a raw HTML document into plain text for the HTTP fallback path (no browser, no DOM).
## Not a renderer: <article> or <main> wins as the content root when present, scripts/styles/comments
## are dropped, block tags become newlines, and entities are decoded.

## The readable article of a page: the extraction result the fallback path hands to the tool layer.
class Article extends RefCounted:
	var title: String
	var description: String
	var content: String
	var wordCount: int
	pass


## Elements whose whole subtree is noise for a text extraction.
static var re_drop_element: RegEx = RegEx.create_from_string(r"(?is)<(script|style|noscript|template|svg)\b[^>]*>.*?</\1\s*>")
## Leftover opening/closing tags of the dropped elements (an unclosed <script> keeps its text otherwise).
static var re_drop_element_tag: RegEx = RegEx.create_from_string(r"(?is)</?(script|style|noscript|template|svg)\b[^>]*>")
static var re_comment: RegEx = RegEx.create_from_string(r"(?s)<!--.*?-->")
static var re_article: RegEx = RegEx.create_from_string(r"(?is)<article\b[^>]*>(.*)</article\s*>")
static var re_main: RegEx = RegEx.create_from_string(r"(?is)<main\b[^>]*>(.*)</main\s*>")
static var re_title: RegEx = RegEx.create_from_string(r"(?is)<title\b[^>]*>(.*?)</title\s*>")
static var re_meta: RegEx = RegEx.create_from_string(r"(?is)<meta\b[^>]*>")
static var re_meta_description: RegEx = RegEx.create_from_string(r"(?i)(?:name|property)\s*=\s*[\"']?(?:description|og:description)[\"']?")
static var re_meta_content: RegEx = RegEx.create_from_string(r"(?i)content\s*=\s*(?:\"([^\"]*)\"|'([^']*)')")
static var re_li_open: RegEx = RegEx.create_from_string(r"(?i)<li\b[^>]*>")
static var re_block: RegEx = RegEx.create_from_string(r"(?i)</?(p|div|section|article|main|header|footer|nav|aside|h[1-6]|ul|ol|dl|dt|dd|table|thead|tbody|tfoot|tr|td|th|blockquote|pre|figure|figcaption|br|hr|form|fieldset|legend|address)\b[^>]*>")
static var re_tag: RegEx = RegEx.create_from_string(r"(?s)<[^>]*>")
static var re_charset: RegEx = RegEx.create_from_string(r"(?i)charset\s*=\s*[\"']?\s*([a-z0-9_\-]+)")
static var re_whitespace: RegEx = RegEx.create_from_string(r"[ \t\f\x0b\xa0]+")
static var re_all_whitespace: RegEx = RegEx.create_from_string(r"\s+")
static var re_blank_lines: RegEx = RegEx.create_from_string(r"\n{3,}")
static var re_word: RegEx = RegEx.create_from_string(r"\S+")
static var re_entity: RegEx = RegEx.create_from_string(r"&([a-zA-Z][a-zA-Z0-9]{1,5}|#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6});")

## Charsets that [method PackedByteArray.get_string_from_utf8] already decodes correctly.
const UTF8_CHARSETS: PackedStringArray = ["", "utf-8", "utf8", "us-ascii", "ascii"]

## Named entities worth carrying; unknown names stay as-is, numeric ones decode by code point.
const ENTITIES: Dictionary[String, String] = {
	"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
	"mdash": "—", "ndash": "–", "hellip": "…", "middot": "·", "bull": "•", "dagger": "†",
	"ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’", "laquo": "«", "raquo": "»",
	"copy": "©", "reg": "®", "trade": "™", "sect": "§", "para": "¶", "deg": "°",
	"plusmn": "±", "times": "×", "divide": "÷", "frac12": "½", "sup2": "²", "sup3": "³",
	"euro": "€", "pound": "£", "yen": "¥",
}

const CHARSET_SNIFF_CHARS: int = 4096


## Extracts the article of a page: title, description, body text, and an approximate word count.
## Returns null when there is nothing to read.
static func extract(html: String) -> Article:
	if StringUtils.is_blank(html):
		return null
	var title := to_inline_text(extract_group(re_title, html))
	var description := extract_description(html)
	var body := re_comment.sub(html, StringUtils.EMPTY, true)
	body = re_drop_element.sub(body, StringUtils.EMPTY, true)
	body = re_drop_element_tag.sub(body, StringUtils.EMPTY, true)
	body = scope_content(body)
	body = re_li_open.sub(body, "\n- ", true)
	body = re_block.sub(body, "\n", true)
	body = re_tag.sub(body, StringUtils.EMPTY, true)
	var text := tidy_block(decode_entities(body))
	var article := Article.new()
	article.title = title
	article.description = description
	article.content = text
	article.wordCount = count_words(text)
	return article


## Charset declared by the Content-Type header or by a <meta> tag in the document head, lowercased.
static func get_declared_charset(html: String, content_type: String) -> String:
	var from_header := re_charset.search(content_type)
	if from_header != null:
		return from_header.get_string(1).to_lower()
	var from_meta := re_charset.search(html.substr(0, CHARSET_SNIFF_CHARS))
	if from_meta != null:
		return from_meta.get_string(1).to_lower()
	return StringUtils.EMPTY


## True when [method PackedByteArray.get_string_from_utf8] is the right decoder for this charset.
static func is_supported_charset(charset: String) -> bool:
	return UTF8_CHARSETS.has(charset.to_lower())


## Collapses an HTML fragment into one line of readable text.
static func to_inline_text(fragment: String) -> String:
	return re_all_whitespace.sub(decode_entities(re_tag.sub(fragment, StringUtils.EMPTY, true)), StringUtils.SPACE, true).strip_edges()


## Decodes the named, decimal, and hexadecimal entities a page or feed is likely to carry.
static func decode_entities(text: String) -> String:
	if not text.contains("&"):
		return text
	var build := StringBuilder.new()
	var cursor := 0
	for found in re_entity.search_all(text):
		build.append(text.substr(cursor, found.get_start() - cursor))
		build.append(decode_entity(found.get_string(0), found.get_string(1)))
		cursor = found.get_end()
	build.append(text.substr(cursor))
	return build.build_string()


## Splits text into lines, drops indentation-only space, and keeps at most one blank line in a row.
static func tidy_block(text: String) -> String:
	var build := StringBuilder.new()
	for line in text.split("\n"):
		var stripped := re_whitespace.sub(line, StringUtils.SPACE, true).strip_edges()
		build.append(stripped + "\n")
	return re_blank_lines.sub(build.build_string(), "\n\n", true).strip_edges()


## Approximate: whitespace-separated runs, so CJK text counts once per run instead of per character.
static func count_words(content: String) -> int:
	return re_word.search_all(content).size()


static func scope_content(body: String) -> String:
	var article := re_article.search(body)
	if article != null:
		return article.get_string(1)
	var main := re_main.search(body)
	if main != null:
		return main.get_string(1)
	return body


static func extract_description(html: String) -> String:
	for found in re_meta.search_all(html):
		var tag := found.get_string(0)
		if re_meta_description.search(tag) == null:
			continue
		var content := re_meta_content.search(tag)
		if content != null:
			return to_inline_text(content.get_string(1) + content.get_string(2))
	return StringUtils.EMPTY


static func extract_group(regex: RegEx, text: String) -> String:
	var found := regex.search(text)
	return found.get_string(1) if found != null else StringUtils.EMPTY


static func decode_entity(raw: String, name: String) -> String:
	if name.begins_with("#x") or name.begins_with("#X"):
		return String.chr(name.substr(2).hex_to_int())
	if name.begins_with("#"):
		return String.chr(name.substr(1).to_int())
	return ENTITIES.get(name.to_lower(), raw)
