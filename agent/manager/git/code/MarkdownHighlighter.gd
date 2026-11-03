class_name MarkdownHighlighter
extends SyntaxHighlighter

## Markdown and MDX [CodeEdit] highlighting ([member EXTENSIONS]) — chat composer and `.md` diff panes.
##
## Inline links: `[label](https://…)` / `mailto:` keep [CodeColors.link] on the `(destination)` span;
## `[label](local file)` uses [FileColors.color_for_path] from the path extension (same rules as rendered
## link chips in [MarkdownParser], without the emoji prefix). Label text `[…]` stays generic link color.
##
## Region rules run on [member region_highlighter]; prose uses the editor [code]font_color[/code].
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
	sync_region_incidental_colors()
	var base_color := prose_base_color()
	var region := fetch_region_map(line_text)
	var highlighting := materialize_line_highlighting(line_text, region, base_color)
	highlight_file_link_destinations(line_text, highlighting)
	return highlighting
	pass


func prose_base_color() -> Color:
	var text_edit := get_text_edit()
	if text_edit != null:
		return text_edit.get_theme_color("font_color")
	return Colors.primary_text
	pass


func sync_region_incidental_colors() -> void:
	var base_color := prose_base_color()
	region_highlighter.number_color = base_color
	region_highlighter.symbol_color = base_color
	region_highlighter.function_color = base_color
	region_highlighter.member_variable_color = base_color
	pass


func fetch_region_map(line_text: String) -> Dictionary:
	region_edit.set_text(line_text)
	region_highlighter.clear_highlighting_cache()
	return region_highlighter.get_line_syntax_highlighting(0)
	pass


# ---------------------------------------------------------------------------
# Static
# ---------------------------------------------------------------------------

static func create() -> MarkdownHighlighter:
	var highlighter := MarkdownHighlighter.new()
	highlighter.region_edit = CodeEdit.new()
	highlighter.region_highlighter = CodeHighlighter.new()
	apply_base(highlighter.region_highlighter)
	configure(highlighter.region_highlighter)
	highlighter.region_edit.syntax_highlighter = highlighter.region_highlighter
	if not gdf.events.theme_changed.is_connected(highlighter.on_theme_changed):
		gdf.events.theme_changed.connect(highlighter.on_theme_changed)
	return highlighter


func on_theme_changed() -> void:
	clear_highlighting_cache()
	pass


static func apply_base(highlighter: CodeHighlighter) -> void:
	var base_color := Colors.primary_text
	highlighter.number_color = base_color
	highlighter.symbol_color = base_color
	highlighter.function_color = base_color
	highlighter.member_variable_color = base_color
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


## Turn sparse [CodeHighlighter] breakpoints into a map where prose gaps use [param base_color].
static func materialize_line_highlighting(line_text: String, region: Dictionary, base_color: Color) -> Dictionary:
	var length := line_text.length()
	if length == 0:
		return {}
	var highlighting: Dictionary = {}
	var previous_color := base_color
	highlighting[0] = {"color": previous_color}
	for column in range(1, length):
		var color := color_at_column(region, column, base_color)
		if color != previous_color:
			highlighting[column] = {"color": color}
			previous_color = color
	return highlighting
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
static func highlight_file_link_destinations(line: String, highlighting: Dictionary) -> void:
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
		for column in range(paren, close + 1):
			highlighting[column] = {"color": destination_color}
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
