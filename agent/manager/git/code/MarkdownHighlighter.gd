class_name MarkdownHighlighter
extends SyntaxHighlighter

## Markdown and MDX [CodeEdit] highlighting ([member EXTENSIONS]) — chat composer and `.md` diff panes.
##
## Inline links: `[label](https://…)` / `mailto:` keep [CodeColors.link] on the `(destination)` span;
## `[label](local file)` uses [FileColors.color_for_path] from the path extension (same rules as rendered
## link chips in [MarkdownParser], without the emoji prefix). Label text `[…]` stays generic link color.
##
## Composer: line-leading `/skill` → [CodeColors.member]; `@path` → [FileColors] (same bounds as completion; skip `` ` ``).
##
## Region rules run on [member region_highlighter]. [method sync_region_colors] copies the visible editor's
## [code]font_color[/code] onto that scratch [CodeEdit] — it stays outside the tree, so the theme cache
## updates only when [method CanvasItem.notification] is sent directly.
## [CodeHighlighter] start keys must be symbol-only ([code]__[/code] and [code]][/code] are invalid).

const EXTENSIONS := ["md", "markdown", "mdown", "mkd", "mdx", "mdc", "mmd", "qmd", "rmd"]
const ALERT_KEYWORDS := [
	"TODO", "FIXME", "XXX", "HACK", "BUG", "REVIEW", "DEPRECATED",
	"NOTE", "INFO", "TIP", "IMPORTANT", "WARNING", "CAUTION", "DANGER", "ERROR", "SUCCESS", "QUESTION", "EXAMPLE", "ABSTRACT",
]

var region_edit: CodeEdit
var region_highlighter: CodeHighlighter


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text_edit := get_text_edit()
	if text_edit == null or region_highlighter == null or region_edit == null:
		return {}
	var line_text := text_edit.get_line(line)
	var base_color := prose_base_color()
	sync_region_colors(base_color)
	region_edit.set_text(line_text)
	region_highlighter.clear_highlighting_cache()
	var highlighting := region_highlighter.get_line_syntax_highlighting(0)
	highlight_file_link_destinations(line_text, highlighting, base_color)
	highlight_composer_tokens(line_text, highlighting)
	return highlighting
	pass


func prose_base_color() -> Color:
	var text_edit := get_text_edit()
	if text_edit != null:
		return text_edit.get_theme_color("font_color")
	return Colors.primary_text
	pass


func sync_region_colors(base_color: Color) -> void:
	region_edit.add_theme_color_override("font_color", base_color)
	region_edit.notification(Control.NOTIFICATION_THEME_CHANGED)
	region_highlighter.number_color = base_color
	region_highlighter.symbol_color = base_color
	region_highlighter.function_color = base_color
	region_highlighter.member_variable_color = base_color
	region_highlighter.update_cache()
	pass


# ---------------------------------------------------------------------------
# Static
# ---------------------------------------------------------------------------

static func create() -> MarkdownHighlighter:
	var highlighter := MarkdownHighlighter.new()
	highlighter.region_edit = CodeEdit.new()
	highlighter.region_highlighter = CodeHighlighter.new()
	configure(highlighter.region_highlighter)
	highlighter.region_edit.syntax_highlighter = highlighter.region_highlighter
	highlighter.sync_region_colors(Colors.primary_text)
	if not gdf.events.theme_changed.is_connected(highlighter.on_theme_changed):
		gdf.events.theme_changed.connect(highlighter.on_theme_changed)
	return highlighter


func on_theme_changed() -> void:
	clear_highlighting_cache()
	pass


static func configure(highlighter: CodeHighlighter) -> void:
	highlighter.add_color_region('"', '"', CodeColors.string)
	highlighter.add_color_region("'", "'", CodeColors.string)
	for word in ALERT_KEYWORDS:
		highlighter.add_keyword_color(word, CodeColors.declaration)
	highlighter.add_color_region("```", "```", CodeColors.string)
	highlighter.add_color_region("~~~", "~~~", CodeColors.string)
	highlighter.add_color_region("`", "`", CodeColors.string)
	highlighter.add_color_region("<!--", "-->", CodeColors.comment)
	highlighter.add_color_region("[", "]", CodeColors.link)
	highlighter.add_color_region("<", ">", CodeColors.link)
	highlighter.add_color_region("#", "", CodeColors.declaration, true)
	highlighter.add_color_region("**", "**", CodeColors.keyword)
	highlighter.add_color_region("~~", "~~", CodeColors.comment)
	pass


static func color_at_column(region: Dictionary, column: int, base_color: Color) -> Color:
	var best_key := -1
	for key in region.keys():
		var index := int(key)
		if index <= column and index > best_key:
			best_key = index
	if best_key == -1:
		return base_color
	return region[best_key]["color"]
	pass


## [code]null[/code] keeps [CodeColors.link] for http(s) / mailto; otherwise [FileColors.color_for_path].
static func syntax_color_for_link_destination(raw_destination: String) -> Variant:
	var path := MarkdownParser.parse_link_destination(raw_destination)
	if HttpUtils.is_valid_http_url(path) or path.to_lower().begins_with("mailto:"):
		return null
	return FileColors.color_for_path(path)
	pass


## Paints `(…)` after `](` for inline links only; skips destinations inside `` ` ``.
static func highlight_file_link_destinations(line: String, highlighting: Dictionary, base_color: Color) -> void:
	var search_from := 0
	while true:
		var link_start := line.find("](", search_from)
		if link_start == -1:
			break
		if is_inside_inline_code(line, link_start):
			search_from = link_start + 2
			continue
		var paren := link_start + 1
		var dest_start := link_start + 2
		var close := find_link_destination_close(line, dest_start)
		if close == -1:
			search_from = dest_start
			continue
		var raw_destination := line.substr(dest_start, close - dest_start)
		var destination_color: Variant = syntax_color_for_link_destination(raw_destination)
		if destination_color == null:
			destination_color = CodeColors.link
		var resume_color := color_at_column(highlighting, close + 1, base_color)
		for column in range(paren, close + 1):
			highlighting[column] = {"color": destination_color}
		if close + 1 < line.length():
			highlighting[close + 1] = {"color": resume_color}
		search_from = close + 1
	pass


static func is_inside_inline_code(line: String, index: int) -> bool:
	var tick_count := 0
	for column in range(index):
		if line[column] == "`":
			tick_count += 1
	return tick_count % 2 == 1
	pass


static func find_link_destination_close(line: String, dest_start: int) -> int:
	if dest_start >= line.length():
		return -1
	if line[dest_start] == "<":
		var gt := line.find(">", dest_start)
		if gt == -1:
			return -1
		return line.find(")", gt + 1)
	return line.find(")", dest_start)
	pass


static func highlight_composer_tokens(line: String, highlighting: Dictionary) -> void:
	var slash_start := line.length() - line.strip_edges(true, false).length()
	if slash_start < line.length() and line[slash_start] == "/":
		var slash_end := slash_start + 1
		while slash_end < line.length() and line[slash_end] != " " and line[slash_end] != "\t":
			slash_end += 1
		for column in range(slash_start, slash_end):
			if not is_inside_inline_code(line, column):
				highlighting[column] = {"color": CodeColors.member}
	for column in range(line.length()):
		if line[column] != "@" or ChatInputFileCompletion.mention_start(line.substr(0, column + 1)) != column:
			continue
		var mention_end := ChatInputFileCompletion.token_end(line, column + 1)
		var mention_color := FileColors.color_for_path(line.substr(column + 1, mention_end - column - 1))
		for paint_at in range(column, mention_end):
			if not is_inside_inline_code(line, paint_at):
				highlighting[paint_at] = {"color": mention_color}
	pass
