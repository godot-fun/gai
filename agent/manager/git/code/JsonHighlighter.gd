class_name JsonHighlighter
extends SyntaxHighlighter

## JSON-aware highlighter for runtime CodeEdit controls. Object keys and string values use
## separate token roles, while JSONC and JSON5 variants additionally support comments.

var allow_comments := false
var allow_single_quotes := false


static func create(extension: String = "json") -> JsonHighlighter:
	var highlighter := JsonHighlighter.new()
	highlighter.allow_comments = extension in ["jsonc", "json5"]
	highlighter.allow_single_quotes = extension == "json5"
	if not gdf.events.theme_changed.is_connected(highlighter.on_theme_changed):
		gdf.events.theme_changed.connect(highlighter.on_theme_changed)
	return highlighter


func on_theme_changed() -> void:
	clear_highlighting_cache()
	pass


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var edit := get_text_edit()
	if edit == null:
		return {}
	var source := edit.get_line(line)
	if source.is_empty():
		return {}
	var base_color := edit.get_theme_color("font_color")
	var colors: Array[Color] = []
	colors.resize(source.length())
	colors.fill(base_color)
	var column := 0
	while column < source.length():
		if allow_comments and column + 1 < source.length() and source.substr(column, 2) == "//":
			paint(colors, column, source.length(), CodeColors.comment)
			break
		if allow_comments and column + 1 < source.length() and source.substr(column, 2) == "/*":
			var comment_end := source.find("*/", column + 2)
			comment_end = source.length() if comment_end < 0 else comment_end + 2
			paint(colors, column, comment_end, CodeColors.comment)
			column = comment_end
			continue
		var character := source[column]
		if character == '"' or (allow_single_quotes and character == "'"):
			column = scan_string(source, column, colors)
			continue
		if is_number_start(source, column):
			var number_end := scan_number_end(source, column)
			paint(colors, column, number_end, CodeColors.number)
			column = number_end
			continue
		if is_identifier_start(character):
			var word_end := column + 1
			while word_end < source.length() and is_identifier_character(source[word_end]):
				word_end += 1
			var word := source.substr(column, word_end - column)
			if word in ["true", "false", "null"]:
				paint(colors, column, word_end, CodeColors.type)
			column = word_end
			continue
		if character not in [" ", "\t"]:
			colors[column] = CodeColors.symbol
		column += 1
	return compress_colors(colors)


static func scan_string(source: String, start: int, colors: Array[Color]) -> int:
	var quote := source[start]
	var end := start + 1
	while end < source.length():
		if source[end] == "\\":
			end = mini(end + 2, source.length())
			continue
		if source[end] == quote:
			end += 1
			break
		end += 1
	var color := CodeColors.member if next_non_space(source, end) < source.length() and source[next_non_space(source, end)] == ":" else CodeColors.string
	paint(colors, start, end, color)
	return end


static func is_number_start(source: String, column: int) -> bool:
	if source[column] >= "0" and source[column] <= "9":
		return true
	return source[column] == "-" and column + 1 < source.length() and source[column + 1] >= "0" and source[column + 1] <= "9"


static func scan_number_end(source: String, start: int) -> int:
	var end := start + 1
	while end < source.length() and source[end] in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "e", "E", "+", "-"]:
		end += 1
	return end


static func next_non_space(source: String, start: int) -> int:
	var column := start
	while column < source.length() and source[column] in [" ", "\t"]:
		column += 1
	return column


static func is_identifier_start(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper()


static func is_identifier_character(character: String) -> bool:
	return is_identifier_start(character) or (character >= "0" and character <= "9")


static func paint(colors: Array[Color], start: int, end: int, color: Color) -> void:
	for column in range(start, end):
		colors[column] = color
	pass


static func compress_colors(colors: Array[Color]) -> Dictionary:
	var highlighting := {}
	var previous := Color.TRANSPARENT
	for column in range(colors.size()):
		if column == 0 or colors[column] != previous:
			highlighting[column] = {"color": colors[column]}
			previous = colors[column]
	return highlighting
