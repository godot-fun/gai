class_name WindowsHighlighter
extends SyntaxHighlighter

## Windows shell highlighter for PowerShell and Command Prompt scripts.

const POWERSHELL_KEYWORDS := {
	"begin": true, "break": true, "catch": true, "class": true, "continue": true,
	"data": true, "do": true, "dynamicparam": true, "else": true, "elseif": true,
	"end": true, "enum": true, "exit": true, "filter": true, "finally": true,
	"for": true, "foreach": true, "from": true, "function": true, "hidden": true,
	"if": true, "in": true, "param": true, "process": true, "return": true,
	"static": true, "switch": true, "throw": true, "trap": true, "try": true,
	"until": true, "using": true, "var": true, "while": true, "workflow": true,
}
const BATCH_KEYWORDS := {
	"call": true, "cd": true, "chdir": true, "cls": true, "copy": true,
	"del": true, "dir": true, "echo": true, "else": true, "endlocal": true,
	"erase": true, "exit": true, "for": true, "goto": true, "if": true,
	"md": true, "mkdir": true, "move": true, "path": true, "pause": true,
	"popd": true, "pushd": true, "rd": true, "rem": true, "ren": true,
	"rename": true, "rmdir": true, "set": true, "setlocal": true, "shift": true,
	"start": true, "title": true, "type": true,
}
const LITERALS := {"true": true, "false": true, "null": true}

var is_powershell := false


static func create(extension: String) -> WindowsHighlighter:
	var highlighter := WindowsHighlighter.new()
	highlighter.is_powershell = extension in ["ps1", "psm1"]
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
		if is_comment_start(source, column):
			paint(colors, column, source.length(), CodeColors.comment)
			break
		if is_powershell and column + 1 < source.length() and source.substr(column, 2) == "<#":
			var comment_end := source.find("#>", column + 2)
			comment_end = source.length() if comment_end < 0 else comment_end + 2
			paint(colors, column, comment_end, CodeColors.comment)
			column = comment_end
			continue
		var character := source[column]
		if character == '"' or (is_powershell and character == "'"):
			column = scan_string(source, column, colors)
			continue
		if is_variable_start(source, column):
			var variable_end := scan_variable_end(source, column)
			paint(colors, column, variable_end, CodeColors.member)
			column = variable_end
			continue
		if character >= "0" and character <= "9":
			var number_end := scan_number_end(source, column)
			paint(colors, column, number_end, CodeColors.number)
			column = number_end
			continue
		if is_word_start(character):
			var word_end := scan_word_end(source, column)
			var word := source.substr(column, word_end - column)
			paint(colors, column, word_end, word_color(word, base_color))
			column = word_end
			continue
		if character not in [" ", "\t"]:
			colors[column] = CodeColors.symbol
		column += 1
	return compress_colors(colors)


func is_comment_start(source: String, column: int) -> bool:
	if is_powershell:
		return source[column] == "#"
	var prefix := source.substr(0, column).strip_edges()
	if prefix.is_empty() and column + 1 < source.length() and source.substr(column, 2) == "::":
		return true
	if not prefix.is_empty():
		return false
	var remaining := source.substr(column).to_lower()
	return remaining == "rem" or remaining.begins_with("rem ") or remaining.begins_with("rem\t")


func is_variable_start(source: String, column: int) -> bool:
	return source[column] == "$" if is_powershell else source[column] == "%"


func scan_variable_end(source: String, start: int) -> int:
	var end := start + 1
	if is_powershell and end < source.length() and source[end] == "{":
		var brace_end := source.find("}", end + 1)
		return source.length() if brace_end < 0 else brace_end + 1
	if not is_powershell:
		if end < source.length() and source[end] in ["*", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			return end + 1
		if end < source.length() and source[end] == "~":
			while end < source.length() and source[end] not in [" ", "\t", '"', "%"]:
				end += 1
			return end
		var percent_end := source.find("%", end)
		if percent_end >= 0:
			return percent_end + 1
	while end < source.length() and (is_word_character(source[end]) or source[end] in [":", "?", "~"]):
		end += 1
	return end


static func scan_string(source: String, start: int, colors: Array[Color]) -> int:
	var quote := source[start]
	var end := start + 1
	while end < source.length():
		if source[end] == "`" and quote == '"':
			end = mini(end + 2, source.length())
			continue
		if source[end] == quote:
			end += 1
			break
		end += 1
	paint(colors, start, end, CodeColors.string)
	return end


static func scan_number_end(source: String, start: int) -> int:
	var end := start + 1
	while end < source.length() and (source[end] >= "0" and source[end] <= "9" or source[end] == "."):
		end += 1
	return end


static func scan_word_end(source: String, start: int) -> int:
	var end := start + 1
	while end < source.length() and (is_word_character(source[end]) or source[end] == "-"):
		end += 1
	return end


func word_color(word: String, base_color: Color) -> Color:
	var normalized := word.to_lower()
	if LITERALS.has(normalized):
		return CodeColors.type
	if (POWERSHELL_KEYWORDS if is_powershell else BATCH_KEYWORDS).has(normalized):
		return CodeColors.keyword
	if is_powershell and "-" in word:
		return CodeColors.function
	return base_color


static func is_word_start(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper()


static func is_word_character(character: String) -> bool:
	return is_word_start(character) or (character >= "0" and character <= "9")


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
