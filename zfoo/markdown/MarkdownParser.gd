class_name MarkdownParser
extends Object

## Markdown → RichTextLabel BBCode.
##
## Syntax map
## ----------
## `#`–`###### Title`     → `[font_size=N]Title[/font_size]`
## ` ```lang / ~~~ ` fence → colored `⌨ lang` title + `[code]…[/code]` block
## `` `code` ``           → `[bgcolor=…][code]code[/code][/bgcolor]` (inline chip)
## `---` `***` `___`      → full-width `[hr]` line
## `> quote`              → two-cell table: accent strip + muted quote text
## `> [!NOTE]` alerts     → colored GitHub-style note/warning/tip/important/caution block
## `-` `*` `+` item       → `• item`  (`- [ ]` / `- [x]` → ☐ / ☑)
## `1. item` / `1) item`  → `1. item`
## `**bold**` / `__bold__` → `[b]bold[/b]`
## `*italic*` / `_italic_` → `[i]italic[/i]`
## `***both***`           → `[b][i]both[/i][/b]`
## `~~strike~~`           → `[s]strike[/s]`
## `<u>text</u>`          → `[u]text[/u]` (inline HTML, not CommonMark)
## `[label](url)`         → `[url=url][color=…]label[/color][/url]` (label in the link color)
## `![alt](url)`          → `[img]url[/img]`
## GFM `\| col \|` table  → `[table=N][cell border=…]…[/cell][/table]` (header row bold + bg)
## leftover `[` / `]`     → `[lb]` / `[rb]` (incl. literal `[b]`, `[url=…]`)
##
## No color lives here: every fill, border and mark comes from [ColorMarkdown], whose dark
## and light sets are constants it switches between.
##
## Block pass then inline pass. Block order is load-bearing: fences first so
## inner `---` / `#` stay literal; HR before lists so `---` is not `- --`.
##
## Inline replacements are stashed via [method protect] as U+E000/index/U+E001
## tokens so later regexes cannot rematch already-built tags
## (`[code]**x**[/code]` must not become bold). Whatever is left outside a token is
## bracket-escaped before restore, so a literal `[b]` in the source stays text
## instead of becoming a live tag. Restore runs high index → low because an outer
## token's body holds the inner tokens it was built from.

# ---------------------------------------------------------------------------
# Constants and patterns
# ---------------------------------------------------------------------------

# h1–h6; body uses RichTextLabel default size. Headline/Title steps of [Typography]: h4 and h5
# both land on title_large because the 20px step has no counterpart in the scale.
const HEADING_FONT_SIZES: PackedInt32Array = [
	Typography.headline_large_size,
	Typography.headline_medium_size,
	Typography.headline_small_size,
	Typography.title_large_size,
	Typography.title_large_size,
	Typography.title_medium_size,
]

# Private-use tokens; must not appear in source markdown.
# ESCAPE_SENTINEL: `[lb]` itself contains `]`, so `[`/`]` cannot be replaced in place.
const PROTECT_START := "\uE000"
const PROTECT_END := "\uE001"
const ESCAPE_SENTINEL := "\uE002"
const NBSP := "\u00A0"
const FOLDER_PREFIX := "📁 "
const FILE_PREFIX := "📄 "
const AUDIO_PREFIX := "🎵 "
const WEB_PREFIX := "🔗 "
const EMAIL_PREFIX := "✉ "
const EXECUTABLE_CONFIG_PREFIX := "⚙ "
const TEXT_DOCUMENT_PREFIX := "📝 "
const CODE_LANGUAGE_PREFIX := "⌨ "
const EXECUTABLE_CONFIG_EXTENSIONS: PackedStringArray = [
	"apk", "app", "bat", "cfg", "cmd", "conf", "env", "exe", "godot", "ini", "json",
	"msi", "plist", "properties", "ps1", "sh", "toml", "xml", "yaml", "yml",
]
const TEXT_DOCUMENT_EXTENSIONS: PackedStringArray = [
	"doc", "docx", "gd", "log", "markdown", "md", "odt", "pdf", "rtf", "rst", "txt",
]
const TABLE_CELL_PADDING := "8,4,8,4"
const CODE_BLOCK_PADDING := "6,6,6,6"
const BLOCKQUOTE_BAR_PADDING := "2,0,0,0"
const BLOCKQUOTE_BODY_PADDING := "6,0,0,0"
# RichTextLabel paints a `[cell]` background `padding + table_h_separation` wider than
# the column it sits in (`RichTextLabel::_set_table_size`), so a one-column `expand=1`
# cell runs past the label's right edge and the fill lands under the bubble's right
# margin while the left one stays visible. Padding here is left, top, right, bottom:
# the gutter reserves that spill so the fill ends on the label box.
const CODE_BLOCK_RIGHT_GUTTER := "0,0,16,0"
# Thin spaces either side of the chip, *outside* its box: the box reaches
# [constant HIGHLIGHT_H_PADDING] past the glyphs, which eats the space markdown authors
# type around the backticks, so the code ends up glued to the prose. This is what gives the
# chip its air; the padding inside the box stays tight. Two of them — one thin space still
# left the box close to the neighbouring words.
const INLINE_CODE_MARGIN := "\u2009\u2009"
# Dest allows one `(...)` nest (Wikipedia). Title is optional `"..."` / `'...'`.
const LINK_DEST := r"((?:<[^>]+>|[^()\s]+|\([^)]*\))+)"
const LINK_TITLE := r"""(?:\s+(?:"[^"]*"|'[^']*'))?"""

# Flanking: marker must touch the word (`*em*`), so `3 * 4 * 5` stays plain.
static var re_inline_code: RegEx = compile_regex(r"`([^`\n]+)`") # `code` → [bgcolor][code]
static var re_image: RegEx = compile_regex(r"!\[([^\]]*)\]\(" + LINK_DEST + LINK_TITLE + r"\)") # ![alt](url) → [img]
static var re_link: RegEx = compile_regex(r"\[([^\]]+)\]\(" + LINK_DEST + LINK_TITLE + r"\)") # [label](url) → [url]
static var re_dunder: RegEx = compile_regex("(?<![A-Za-z0-9])__[A-Za-z_][A-Za-z0-9_]*__(?![A-Za-z0-9])") # keep __init__
static var re_bold_italic: RegEx = compile_regex(r"(?<!\*)\*\*\*(?!\*|\s)([^\n]+?)(?<!\s)\*\*\*(?!\*)") # ***both***
static var re_bold: RegEx = compile_regex(r"(?<!\*)\*\*(?!\*|\s)([^\n]+?)(?<!\s)\*\*(?!\*)") # **bold**
static var re_bold_underscore: RegEx = compile_regex(r"(?<![A-Za-z0-9])__(?![\s_])([^_\n]+)(?<![\s_])__(?![A-Za-z0-9])") # __bold__
static var re_strike: RegEx = compile_regex(r"~~(?!\s)([^~\n]+)(?<!\s)~~") # ~~strike~~
static var re_italic: RegEx = compile_regex(r"(?<!\*)\*(?!\*|\s)([^\n]+?)(?<!\s|\*)\*(?!\*)") # *italic*
static var re_italic_underscore: RegEx = compile_regex(r"(?<![A-Za-z0-9])_(?![\s_])([^_\n]+)(?<![\s_])_(?![A-Za-z0-9])") # _italic_
static var re_html_underline: RegEx = compile_regex(r"(?i)<u>([^<\n]+)</u>") # <u>html underline</u>
static var re_table_separator_cell: RegEx = compile_regex(r"^\s*:?-+:?\s*$") # --- / :---:

enum InlineReplacement {
	INLINE_CODE,
	HTML_UNDERLINE,
	IMAGE,
	LINK,
	DUNDER_LITERAL,
	BOLD_ITALIC,
	BOLD,
	STRIKE,
	ITALIC,
}


static func compile_regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		Log.error("MarkdownParser regex compile failed pattern:[{}] err:[{}]", pattern, err)
	return regex


# ---------------------------------------------------------------------------
# Parser entry point
# ---------------------------------------------------------------------------

## Parses Markdown into RichTextLabel BBCode plus ordered image metadata.
## Colors come from [ColorMarkdown], so [member MarkdownParseResult.bbcode] follows the current theme.
static func to_bbcode(markdown: String) -> MarkdownParseResult:
	var result := MarkdownParseResult.new()
	if StringUtils.is_blank(markdown):
		return result

	var lines := normalize_newlines(markdown).split(FileUtils.NEWLINE_LF)
	var out: PackedStringArray = []
	var i := 0
	while i < lines.size():
		var line: String = lines[i]

		# ```lang / ~~~  …  ``` / ~~~  →  [code]…[/code]
		# Unclosed fence swallows the rest of the document (same as CommonMark).
		var fence := parse_code_fence(line)
		if StringUtils.is_not_empty(fence):
			var language := parse_code_fence_language(line, fence)
			i += 1
			var code_lines: PackedStringArray = []
			while i < lines.size() and not is_closing_fence(lines[i], fence):
				code_lines.append(lines[i])
				i += 1
			if i < lines.size():
				i += 1
			out.append(format_code_fence_bbcode(FileUtils.NEWLINE_LF.join(code_lines), language))
			continue

		# --- / *** / ___  →  [hr width=100% …]
		if is_horizontal_rule_line(line):
			out.append(format_horizontal_rule_line())
			i += 1
			continue

		# # Title  →  [font_size=32]Title[/font_size]
		var heading_level := parse_heading_level(line)
		if heading_level > 0:
			var size := HEADING_FONT_SIZES[heading_level - 1]
			out.append(
					StringUtils.format(
							"[font_size={}]{}[/font_size]",
							size,
							inline_to_bbcode(extract_heading_text(line, heading_level), result)
					)
			)
			i += 1
			continue

		# > quote  →  table cell strip + muted text; the strip is independent of font baseline
		if is_blockquote_line(line):
			var quote_lines: PackedStringArray = []
			while i < lines.size() and is_blockquote_line(lines[i]):
				quote_lines.append(strip_blockquote_prefix(lines[i]))
				i += 1
			var admonition_kind := parse_admonition_kind(quote_lines[0])
			if StringUtils.is_not_empty(admonition_kind):
				quote_lines.remove_at(0)
				out.append(format_admonition_bbcode(admonition_kind, quote_lines, result))
			else:
				out.append(format_blockquote_bbcode(FileUtils.NEWLINE_LF.join(quote_lines), result))
			continue

		# | h1 | h2 | + |---|  →  [table=2][cell][b]h1[/b][/cell]…[/table]
		var table := parse_table_block(lines, i, result)
		if table.has("next"):
			out.append(table["bbcode"])
			i = table["next"]
			continue

		# - item / 1. item / - [ ] task  →  • / 1. / ☐ ☑
		var list_line := format_list_line(line, result)
		if StringUtils.is_not_empty(list_line):
			out.append(list_line)
			i += 1
			continue

		if StringUtils.is_blank(line):
			out.append("")
		else:
			out.append(inline_to_bbcode(line, result))
		i += 1

	result.bbcode = FileUtils.NEWLINE_LF.join(out)
	return result


# ---------------------------------------------------------------------------
# Shared block helpers
# ---------------------------------------------------------------------------

## CRLF / lone CR → LF so Windows sources do not leave `\r` on markers.
static func normalize_newlines(text: String) -> String:
	return text.replace(FileUtils.NEWLINE_CRLF, FileUtils.NEWLINE_LF).replace(FileUtils.NEWLINE_CR, FileUtils.NEWLINE_LF)


static func count_leading_spaces(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == " ":
		n += 1
	return n


# ---------------------------------------------------------------------------
# Headings
# ---------------------------------------------------------------------------

## CommonMark ATX: 0–3 leading spaces. 4+ is indented code, not a heading.
static func atx_content_source(line: String) -> String:
	var leading := count_leading_spaces(line)
	if leading == 0 or leading > 3:
		return line
	return line.substr(leading)


## `# Title` / `## Title` … `###### Title` (space/tab required). `#not-a-heading` → 0.
static func parse_heading_level(line: String) -> int:
	var source := atx_content_source(line)
	if StringUtils.is_empty(source) or source[0] != "#":
		return 0
	var level := 0
	while level < source.length() and level < 6 and source[level] == "#":
		level += 1
	if level == 0 or level >= source.length():
		return 0
	if source[level] != " " and source[level] != "\t":
		return 0
	var content := strip_closing_atx_hashes(source.substr(level).strip_edges())
	return level if StringUtils.is_not_blank(content) else 0


static func extract_heading_text(line: String, level: int) -> String:
	var source := atx_content_source(line)
	return strip_closing_atx_hashes(source.substr(level).strip_edges())


## `# Title ##` → `Title`. Closing `#` run is stripped only when a space precedes it.
static func strip_closing_atx_hashes(content: String) -> String:
	if StringUtils.is_empty(content):
		return content
	var i := content.length() - 1
	while i >= 0 and content[i] == "#":
		i -= 1
	if i >= 0 and i < content.length() - 1 and (content[i] == " " or content[i] == "\t"):
		return content.substr(0, i).strip_edges()
	return content


# ---------------------------------------------------------------------------
# Fenced code blocks
# ---------------------------------------------------------------------------

## Opening fence: ` ``` ` or ` ~~~ ` (run ≥ 3). An info string provides the language title.
static func parse_code_fence(line: String) -> String:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return StringUtils.EMPTY
	var rest := line.substr(leading)
	var fence_char := ""
	if rest.begins_with("`"):
		fence_char = "`"
	elif rest.begins_with("~"):
		fence_char = "~"
	else:
		return StringUtils.EMPTY
	var n := 0
	while n < rest.length() and rest[n] == fence_char:
		n += 1
	if n < 3:
		return StringUtils.EMPTY
	return rest.substr(0, n)


static func parse_code_fence_language(line: String, fence: String) -> String:
	var rest := line.substr(count_leading_spaces(line) + fence.length()).strip_edges()
	if StringUtils.is_empty(rest):
		return StringUtils.EMPTY
	return rest.split(" ", false, 1)[0]


## Closer: same character as [param fence], no info string, length ≥ opening run.
static func is_closing_fence(line: String, fence: String) -> bool:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return false
	var rest := line.substr(leading).strip_edges(false, true)
	if rest.length() < fence.length():
		return false
	for index in rest.length():
		if rest[index] != fence[0]:
			return false
	return true


## One full-width code cell wrapped in an outer gutter-preserving cell.
static func format_code_fence_bbcode(code: String, language: String = StringUtils.EMPTY) -> String:
	var title := StringUtils.EMPTY
	if StringUtils.is_not_empty(language):
		title = StringUtils.format(
				"[color={}]{}{}[/color]\n",
				to_bbcode_color(ColorBase.teal), CODE_LANGUAGE_PREFIX, escape_bbcode_literals(language)
		)
	var block := StringUtils.format(
			"[table=1][cell shrink=false expand=1 bg={} padding={}]{}{}[/cell][/table]",
			to_bbcode_color(ColorMarkdown.code_block_bg),
			CODE_BLOCK_PADDING,
			title,
			wrap_code(code)
	)
	return StringUtils.format(
			"[table=1][cell padding={}]{}[/cell][/table]",
			CODE_BLOCK_RIGHT_GUTTER,
			block
	)


## Inline code uses the same monospace wrapper with a compact themed background.
static func add_code_background(code: String) -> String:
	return StringUtils.format(
			"{}[bgcolor={}]{}[/bgcolor]{}",
			INLINE_CODE_MARGIN,
			to_bbcode_color(ColorMarkdown.inline_code_bg),
			wrap_code(code),
			INLINE_CODE_MARGIN
	)


static func wrap_code(code: String) -> String:
	return StringUtils.format("[code]{}[/code]", escape_bbcode_literals(preserve_code_spaces(code)))


## RichTextLabel collapses ASCII spaces in `[code]`; NBSP preserves indentation.
static func preserve_code_spaces(code: String) -> String:
	return code.replace("\t", "    ").replace(" ", NBSP)


# ---------------------------------------------------------------------------
# Horizontal rules
# ---------------------------------------------------------------------------

## Thematic break: `---`, `***`, `___`, or `- - -`. Mixed `-_*-` is not an HR.
static func is_horizontal_rule_line(line: String) -> bool:
	var trimmed := line.strip_edges()
	if trimmed.length() < 3:
		return false
	var hr_char := trimmed[0]
	if hr_char != "-" and hr_char != "*" and hr_char != "_":
		return false
	var marker_count := 0
	for index in trimmed.length():
		var ch: String = trimmed[index]
		if ch == hr_char:
			marker_count += 1
		elif ch != " ":
			return false
	return marker_count >= 3


## `---` → full-width rule in the table grid color, so rules and table lines match.
static func format_horizontal_rule_line() -> String:
	return StringUtils.format("[hr width=100% height=1 color={}]", to_bbcode_color(ColorMarkdown.table_grid_color))


# ---------------------------------------------------------------------------
# Blockquotes and GitHub-style alerts
# ---------------------------------------------------------------------------

## `>` after 0–3 spaces. Nested `>>` is left as leftover `>` in the quote body.
static func is_blockquote_line(line: String) -> bool:
	var leading := count_leading_spaces(line)
	if leading > 3:
		return false
	return line.substr(leading).begins_with(">")


static func strip_blockquote_prefix(line: String) -> String:
	var leading := count_leading_spaces(line)
	var rest := line.substr(leading) if leading <= 3 else line
	if rest.begins_with(">"):
		rest = rest.substr(1)
		if rest.begins_with(" "):
			rest = rest.substr(1)
	return rest


## Blockquote: the narrow background cell is a real full-height strip, not a baseline-aligned glyph.
static func format_blockquote_bbcode(text: String, result: MarkdownParseResult) -> String:
	var chunks: PackedStringArray = ["[indent][table=2]"]
	for line: String in text.split(FileUtils.NEWLINE_LF):
		chunks.append(
				StringUtils.format(
						"[cell bg={} padding={}][/cell]",
						to_bbcode_color(ColorMarkdown.blockquote_bar_color),
						BLOCKQUOTE_BAR_PADDING
				)
		)
		chunks.append(
				StringUtils.format(
						"[cell shrink=false expand=1 padding={}][color={}]{}[/color][/cell]",
						BLOCKQUOTE_BODY_PADDING,
						to_bbcode_color(ColorMarkdown.blockquote_text_color),
						inline_to_bbcode(line, result)
				)
		)
	chunks.append("[/table][/indent]")
	return "".join(chunks)


## GitHub-style alert syntax: `> [!NOTE]`, followed by consecutive quoted body lines.
static func parse_admonition_kind(line: String) -> String:
	var marker := line.strip_edges().to_upper()
	for kind: String in ["NOTE", "WARNING", "TIP", "IMPORTANT", "CAUTION"]:
		if marker == "[!%s]" % kind:
			return kind
	return StringUtils.EMPTY


static func format_admonition_bbcode(kind: String, lines: PackedStringArray, result: MarkdownParseResult) -> String:
	var color := get_admonition_color(kind)
	var chunks: PackedStringArray = ["[indent][table=2]"]
	append_admonition_row(chunks, StringUtils.format(
			"[color={}][b]{} {}[/b][/color]",
			to_bbcode_color(color), get_admonition_icon(kind), kind.capitalize()
	), color)
	for line: String in lines:
		append_admonition_row(chunks, inline_to_bbcode(line, result), color)
	chunks.append("[/table][/indent]")
	return StringUtils.EMPTY.join(chunks)


static func append_admonition_row(chunks: PackedStringArray, content: String, color: Color) -> void:
	chunks.append(StringUtils.format(
			"[cell bg={} padding={}][/cell]", to_bbcode_color(color), BLOCKQUOTE_BAR_PADDING
	))
	chunks.append(StringUtils.format(
			"[cell shrink=false expand=1 padding={}]{}[/cell]", BLOCKQUOTE_BODY_PADDING, content
	))
	pass


static func get_admonition_icon(kind: String) -> String:
	match kind:
		"WARNING": return "⚠"
		"TIP": return "✓"
		"CAUTION": return "✕"
		_: return "ℹ"


static func get_admonition_color(kind: String) -> Color:
	match kind:
		"WARNING": return ColorBase.warning
		"TIP": return ColorBase.success
		"IMPORTANT": return ColorBase.purple
		"CAUTION": return ColorBase.error
		_: return ColorBase.info


# ---------------------------------------------------------------------------
# Tables
# ---------------------------------------------------------------------------

## GFM table: header row + `\| --- \|` separator + body rows. Needs the separator line.
static func parse_table_block(lines: PackedStringArray, start: int, result: MarkdownParseResult) -> Dictionary:
	if start + 1 >= lines.size():
		return {}
	if not is_table_row_line(lines[start]):
		return {}
	if not is_table_separator_line(lines[start + 1]):
		return {}
	var header := parse_table_cells(lines[start])
	var columns := header.size()
	if columns == 0:
		return {}
	var body_rows: Array[PackedStringArray] = []
	var index := start + 2
	while index < lines.size() and is_table_row_line(lines[index]):
		body_rows.append(normalize_table_row(parse_table_cells(lines[index]), columns))
		index += 1
	return {
		"bbcode": format_table_bbcode(header, body_rows, columns, result),
		"next": index,
	}


static func is_table_row_line(line: String) -> bool:
	return line.contains("|") and parse_table_cells(line).size() > 0


static func is_table_separator_line(line: String) -> bool:
	var cells := parse_table_cells(line)
	if cells.is_empty():
		return false
	for cell in cells:
		if re_table_separator_cell.search(cell) == null:
			return false
	return true


static func parse_table_cells(line: String) -> PackedStringArray:
	if not line.contains("|"):
		return PackedStringArray()
	var body := line.strip_edges()
	if body.begins_with("|"):
		body = body.substr(1)
	if body.ends_with("|"):
		body = body.substr(0, body.length() - 1)
	var cells: PackedStringArray = []
	for part in body.split("|"):
		cells.append(part.strip_edges())
	return cells


static func normalize_table_row(cells: PackedStringArray, columns: int) -> PackedStringArray:
	var row: PackedStringArray = []
	for index in columns:
		if index < cells.size():
			row.append(cells[index])
		else:
			row.append("")
	return row


## One line of `[cell]` tags; cell text is single-line (Godot table layout requirement).
static func format_table_bbcode(
		header: PackedStringArray,
		body_rows: Array[PackedStringArray],
		columns: int,
		result: MarkdownParseResult
) -> String:
	var chunks: PackedStringArray = []
	chunks.append(StringUtils.format("[table={}]", columns))
	for cell in header:
		chunks.append(format_table_cell(cell, true, result))
	for row in body_rows:
		for cell in row:
			chunks.append(format_table_cell(cell, false, result))
	chunks.append("[/table]")
	return "".join(chunks)


static func format_table_cell(text: String, is_header: bool, result: MarkdownParseResult) -> String:
	var content := inline_to_bbcode(text, result)
	var border := to_bbcode_color(ColorMarkdown.table_grid_color)
	if is_header:
		content = StringUtils.format("[b]{}[/b]", content)
		return StringUtils.format(
				"[cell border={} bg={} padding={}]{}[/cell]",
				border,
				to_bbcode_color(ColorMarkdown.table_header_bg),
				TABLE_CELL_PADDING,
				content
		)
	return StringUtils.format(
			"[cell border={} padding={}]{}[/cell]",
			border,
			TABLE_CELL_PADDING,
			content
	)


# ---------------------------------------------------------------------------
# Lists and tasks
# ---------------------------------------------------------------------------

## `- item` / `* item` / `+ item` → `• item`; `1. item` / `1) item` → `1. item`.
static func format_list_line(line: String, result: MarkdownParseResult) -> String:
	var prefix_len := parse_unordered_list_prefix_length(line)
	if prefix_len > 0:
		return format_unordered_list_item(line.substr(prefix_len).strip_edges(), result)

	prefix_len = parse_ordered_list_prefix_length(line)
	if prefix_len > 0:
		var trimmed := line.strip_edges(true, false)
		var number := trimmed.substr(0, parse_leading_integer_length(trimmed))
		var item := line.substr(prefix_len).strip_edges()
		return StringUtils.format("{}. {}", number, inline_to_bbcode(item, result))

	return StringUtils.EMPTY


## GFM task list: `- [ ]` → ☐, `- [x]` / `- [X]` → ☑; otherwise `•`.
static func format_unordered_list_item(item: String, result: MarkdownParseResult) -> String:
	if item.begins_with("[ ] "):
		return StringUtils.format("☐ {}", inline_to_bbcode(item.substr(4), result))
	if item.length() >= 4 and item.substr(0, 3).to_lower() == "[x]" and item[3] == " ":
		return StringUtils.format("☑ {}", inline_to_bbcode(item.substr(4), result))
	return StringUtils.format("• {}", inline_to_bbcode(item, result))


## Prefix length of `- `/`* `/`+ ` (or tab). `0` if the line is not an unordered item.
static func parse_unordered_list_prefix_length(line: String) -> int:
	if StringUtils.is_empty(line):
		return 0
	var trimmed := line.strip_edges(true, false)
	if StringUtils.is_empty(trimmed):
		return 0
	var first: String = trimmed[0]
	if first != "-" and first != "*" and first != "+":
		return 0
	if trimmed.length() < 2:
		return 0
	if trimmed[1] != " " and trimmed[1] != "\t":
		return 0
	return line.length() - trimmed.length() + 2


## Prefix length of `1. ` / `1) ` (or tab). `0` if the line is not an ordered item.
static func parse_ordered_list_prefix_length(line: String) -> int:
	if StringUtils.is_empty(line):
		return 0
	var trimmed := line.strip_edges(true, false)
	if StringUtils.is_empty(trimmed):
		return 0
	var number_len := parse_leading_integer_length(trimmed)
	if number_len == 0 or number_len >= trimmed.length():
		return 0
	var marker := trimmed[number_len]
	if marker != "." and marker != ")":
		return 0
	if number_len + 1 >= trimmed.length():
		return 0
	var after := trimmed[number_len + 1]
	if after != " " and after != "\t":
		return 0
	return line.length() - trimmed.length() + number_len + 2


static func parse_leading_integer_length(text: String) -> int:
	var n := 0
	while n < text.length() and text[n] >= "0" and text[n] <= "9":
		n += 1
	return n


# ---------------------------------------------------------------------------
# Inline parsing
# ---------------------------------------------------------------------------

## Inline Markdown → BBCode. Protect → escape leftover brackets → restore.
static func inline_to_bbcode(text: String, result: MarkdownParseResult = null) -> String:
	if StringUtils.is_empty(text):
		return StringUtils.EMPTY
	if result == null:
		result = MarkdownParseResult.new()
	var parts: Array[String] = []
	return restore_protected(inline_body(text, parts, result), parts)


## Converted text with every leftover `[` / `]` escaped, tags still stashed in [param parts].
## Escaping before [method restore_protected] is what keeps a literal `[b]` in the source
## from turning into a live tag; tokens hold no brackets, so they survive untouched.
## Emphasis and link labels go through here too — their bodies land inside [param parts]
## and are never scanned again, so `**a[0]b**` must be escaped on the way in.
static func inline_body(text: String, parts: Array[String], result: MarkdownParseResult) -> String:
	return escape_bbcode_literals(apply_inline(text, parts, result))


## Order is load-bearing: code, then images (so `![a](u)` is not a link), then
## links, then `__init__` as literal, then `***` / `**` / `__` / `~~` / `*` / `_`,
## plus inline HTML `<u>`.
## Recurse into link labels and emphasis so `**foo *bar* baz**` / `[**b**](url)` work.
static func apply_inline(text: String, parts: Array[String], result: MarkdownParseResult) -> String:
	var s := text
	# `code` → [bgcolor][code]code[/code][/bgcolor]
	s = regex_sub(s, re_inline_code, InlineReplacement.INLINE_CODE, parts, result)
	# <u>html</u> → [u]html[/u]  (CommonMark has no native underline)
	s = regex_sub(s, re_html_underline, InlineReplacement.HTML_UNDERLINE, parts, result)
	# ![alt](url "title") → [img]url[/img]
	s = regex_sub(s, re_image, InlineReplacement.IMAGE, parts, result)
	# [label](url "title") → [url=url][color]label[/color][/url]
	s = regex_sub(s, re_link, InlineReplacement.LINK, parts, result)
	# `__init__` would otherwise become `[b]init[/b]` (and then `_init_` italic).
	s = regex_sub(s, re_dunder, InlineReplacement.DUNDER_LITERAL, parts, result)
	# ***both*** → [b][i]both[/i][/b]
	s = regex_sub(s, re_bold_italic, InlineReplacement.BOLD_ITALIC, parts, result)
	# **bold** → [b]bold[/b]
	s = regex_sub(s, re_bold, InlineReplacement.BOLD, parts, result)
	# __bold__ → [b]bold[/b]  (not __init__)
	s = regex_sub(s, re_bold_underscore, InlineReplacement.BOLD, parts, result)
	# ~~strike~~ → [s]strike[/s]
	s = regex_sub(s, re_strike, InlineReplacement.STRIKE, parts, result)
	# *italic* → [i]italic[/i]
	s = regex_sub(s, re_italic, InlineReplacement.ITALIC, parts, result)
	# _italic_ → [i]italic[/i]  (not my_var_name)
	s = regex_sub(s, re_italic_underscore, InlineReplacement.ITALIC, parts, result)
	return s


static func replace_inline_match(
		match: RegExMatch,
		replacement: InlineReplacement,
		parts: Array[String],
		result: MarkdownParseResult
) -> String:
	match replacement:
		InlineReplacement.INLINE_CODE:
			return protect(parts, add_code_background(match.get_string(1)))
		InlineReplacement.HTML_UNDERLINE:
			return protect(parts, StringUtils.format("[u]{}[/u]", inline_body(match.get_string(1), parts, result)))
		InlineReplacement.IMAGE:
			var alt_text := match.get_string(1)
			var image_url := parse_link_destination(match.get_string(2))
			var url := escape_bbcode_literals(image_url)
			result.images.append(MarkdownParseResult.MarkdownImage.new(alt_text, image_url))
			return protect(parts, StringUtils.format("[img]{}[/img]", url))
		InlineReplacement.LINK:
			var link_destination := parse_link_destination(match.get_string(2))
			var label := get_link_prefix(link_destination) + inline_body(match.get_string(1), parts, result)
			var url := escape_bbcode_literals(link_destination)
			return protect(parts, StringUtils.format(
					"[url={}][color={}]{}[/color][/url]",
					url,
					to_bbcode_color(ColorMarkdown.link_color),
					label
			))
		InlineReplacement.DUNDER_LITERAL:
			return protect(parts, escape_bbcode_literals(match.get_string(0)))
		InlineReplacement.BOLD_ITALIC:
			return protect(parts, StringUtils.format("[b][i]{}[/i][/b]", inline_body(match.get_string(1), parts, result)))
		InlineReplacement.BOLD:
			return protect(parts, StringUtils.format("[b]{}[/b]", inline_body(match.get_string(1), parts, result)))
		InlineReplacement.STRIKE:
			return protect(parts, StringUtils.format("[s]{}[/s]", inline_body(match.get_string(1), parts, result)))
		InlineReplacement.ITALIC:
			return protect(parts, StringUtils.format("[i]{}[/i]", inline_body(match.get_string(1), parts, result)))
	assert(false, "Unhandled inline replacement: %s" % replacement)
	return StringUtils.EMPTY


# ---------------------------------------------------------------------------
# Link and file markers
# ---------------------------------------------------------------------------

## Adds a theme-colored visual marker based on the link destination type.
static func get_link_prefix(path: String) -> String:
	if HttpUtils.is_valid_http_url(path):
		return format_link_prefix(WEB_PREFIX, ColorBase.info)
	if path.to_lower().begins_with("mailto:"):
		return format_link_prefix(EMAIL_PREFIX, ColorBase.purple)
	if not (path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://")):
		return StringUtils.EMPTY
	if DirAccess.dir_exists_absolute(path):
		return format_link_prefix(FOLDER_PREFIX, ColorFile.folder_color)
	var extension := path.get_extension().to_lower()
	if ResourceHelper.AUDIO_EXTENSIONS.has(extension):
		return format_link_prefix(AUDIO_PREFIX, ColorFile.audio_color)
	if EXECUTABLE_CONFIG_EXTENSIONS.has(extension):
		return format_link_prefix(EXECUTABLE_CONFIG_PREFIX, ColorBase.teal)
	if TEXT_DOCUMENT_EXTENSIONS.has(extension):
		return format_link_prefix(TEXT_DOCUMENT_PREFIX, ColorFile.text_color)
	return format_link_prefix(FILE_PREFIX, ColorFile.text_color)


static func format_link_prefix(prefix: String, color: Color) -> String:
	return StringUtils.format("[color={}]{}[/color]", to_bbcode_color(color), prefix)


## Link/image dest: `[t](<url>)` unwraps; `[t](url "title")` / `[t](url 'title')` drops title.
static func parse_link_destination(raw: String) -> String:
	var dest := raw.strip_edges()
	if dest.begins_with("<"):
		var end := dest.find(">")
		if end != -1:
			return dest.substr(1, end - 1).strip_edges()
	var title_dq := dest.find(" \"")
	var title_sq := dest.find(" '")
	var cut := dest.length()
	if title_dq != -1:
		cut = title_dq
	if title_sq != -1 and title_sq < cut:
		cut = title_sq
	return dest.substr(0, cut).strip_edges()


# ---------------------------------------------------------------------------
# Protected replacement and BBCode utilities
# ---------------------------------------------------------------------------

## Stash finished BBCode and leave a token that no inline regex will match.
static func protect(parts: Array[String], bbcode: String) -> String:
	var index := parts.size()
	parts.append(bbcode)
	return "%s%d%s" % [PROTECT_START, index, PROTECT_END]


## High → low so token `1` does not replace the prefix of token `10`.
static func restore_protected(text: String, parts: Array[String]) -> String:
	var s := text
	var index := parts.size() - 1
	while index >= 0:
		s = s.replace("%s%d%s" % [PROTECT_START, index, PROTECT_END], parts[index])
		index -= 1
	return s


static func regex_sub(
		text: String,
		regex: RegEx,
		replacement: InlineReplacement,
		parts: Array[String],
		result: MarkdownParseResult
) -> String:
	if StringUtils.is_empty(text):
		return text
	var matches := regex.search_all(text)
	if matches.is_empty():
		return text
	var chunks: PackedStringArray = []
	var pos := 0
	for m in matches:
		chunks.append(text.substr(pos, m.get_start() - pos))
		chunks.append(replace_inline_match(m, replacement, parts, result))
		pos = m.get_end()
	chunks.append(text.substr(pos))
	return "".join(chunks)


## `#rrggbbaa` for a `[color]` / `[bgcolor]` / `[cell border]` argument. BBCode only takes
## strings, and the palette is read at conversion time, so the tags carry the value instead
## of a cached hex.
static func to_bbcode_color(color: Color) -> String:
	return "#" + color.to_html(true)


## `[` → `[lb]`, `]` → `[rb]`. Must go through [constant ESCAPE_SENTINEL]:
## `[hello]` → `[lb]hello]` → `[lb[rb]hello[rb]` if `]` is replaced second.
static func escape_bbcode_literals(text: String) -> String:
	if StringUtils.is_empty(text):
		return StringUtils.EMPTY
	return text.replace("[", ESCAPE_SENTINEL).replace("]", "[rb]").replace(ESCAPE_SENTINEL, "[lb]")
