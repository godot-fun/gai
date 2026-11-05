class_name GdScriptHighlighter
extends SyntaxHighlighter

## GDScript-aware highlighter for runtime CodeEdit controls. Godot's editor-only
## GDScriptSyntaxHighlighter is unavailable to the application, so this scanner mirrors its
## visible token roles without depending on editor classes.

const KEYWORDS := {
	"class_name": true, "extends": true, "is": true, "in": true, "as": true,
	"self": true, "super": true, "signal": true, "func": true, "static": true,
	"const": true, "enum": true, "var": true, "breakpoint": true, "await": true,
	"yield": true,
}
const CONTROL_FLOW_KEYWORDS := {
	"if": true, "elif": true, "else": true, "for": true, "while": true,
	"match": true, "when": true, "break": true, "continue": true, "return": true,
	"pass": true, "and": true, "or": true, "not": true,
}
const BUILT_IN_TYPES := {
	"void": true, "bool": true, "int": true, "float": true, "String": true,
	"StringName": true, "NodePath": true, "Vector2": true, "Vector2i": true,
	"Rect2": true, "Rect2i": true, "Vector3": true, "Vector3i": true,
	"Transform2D": true, "Vector4": true, "Vector4i": true, "Plane": true,
	"Quaternion": true, "AABB": true, "Basis": true, "Transform3D": true,
	"Projection": true, "Color": true, "RID": true,
	"Callable": true, "Signal": true, "Dictionary": true, "Array": true,
	"PackedByteArray": true, "PackedInt32Array": true, "PackedInt64Array": true,
	"PackedFloat32Array": true, "PackedFloat64Array": true, "PackedStringArray": true,
	"PackedVector2Array": true, "PackedVector3Array": true, "PackedColorArray": true,
	"PackedVector4Array": true, "Variant": true,
}
const LITERALS := {"true": true, "false": true, "null": true, "PI": true, "TAU": true, "INF": true, "NAN": true}
const GLOBAL_FUNCTIONS := {
	"abs": true, "all": true, "any": true, "assert": true, "bytes_to_var": true,
	"ceil": true, "clamp": true, "clampf": true, "clampi": true, "convert": true,
	"cos": true, "deg_to_rad": true, "error_string": true, "floor": true,
	"is_equal_approx": true, "is_instance_valid": true, "is_zero_approx": true,
	"len": true, "lerp": true, "lerpf": true, "load": true, "max": true,
	"maxf": true, "maxi": true, "min": true, "minf": true, "mini": true,
	"move_toward": true, "preload": true, "print": true, "printerr": true,
	"print_rich": true, "push_error": true, "push_warning": true, "rad_to_deg": true,
	"range": true, "round": true, "roundi": true, "sign": true, "sin": true,
	"snapped": true, "sqrt": true, "str": true, "tan": true, "type_string": true,
	"typeof": true, "var_to_bytes": true, "var_to_str": true,
}


static func create() -> GdScriptHighlighter:
	var highlighter := GdScriptHighlighter.new()
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
		var character := source[column]
		if character == "#":
			paint(colors, column, source.length(), CodeColors.comment)
			break
		if character == '"' or character == "'":
			column = scan_string(source, column, colors)
			continue
		if character == "@":
			var annotation_end := column + 1
			while annotation_end < source.length() and is_identifier_character(source[annotation_end]):
				annotation_end += 1
			paint(colors, column, annotation_end, CodeColors.tag)
			column = annotation_end
			continue
		if character == "$":
			var node_end := scan_path_end(source, column + 1)
			paint(colors, column, node_end, CodeColors.node_reference)
			column = node_end
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
			paint(colors, column, word_end, identifier_color(source, column, word_end, word, base_color))
			column = word_end
			continue
		if is_symbol(character):
			colors[column] = CodeColors.symbol
		column += 1
	return compress_colors(colors)


static func identifier_color(source: String, start: int, end: int, word: String, base_color: Color) -> Color:
	if CONTROL_FLOW_KEYWORDS.has(word):
		return CodeColors.declaration
	if KEYWORDS.has(word):
		return CodeColors.keyword
	if BUILT_IN_TYPES.has(word):
		return CodeColors.type
	if LITERALS.has(word):
		return CodeColors.keyword
	var previous_word := word_before(source, start)
	if previous_word == "func" or previous_word == "signal":
		return CodeColors.function_definition
	if previous_word == "class_name" or previous_word == "extends":
		return CodeColors.engine_type
	if previous_word == "const":
		return base_color
	var dot_before := previous_non_space(source, start)
	if dot_before >= 0 and source[dot_before] == ".":
		var next_after := next_non_space(source, end)
		if next_after < source.length() and source[next_after] == "(":
			return CodeColors.function
		if word[0] == word[0].to_upper() and word[0] != word[0].to_lower():
			return base_color
		return CodeColors.member
	if word[0] == word[0].to_upper() and word[0] != word[0].to_lower():
		return CodeColors.engine_type
	var next := next_non_space(source, end)
	if next < source.length() and source[next] == "(":
		return CodeColors.global_function if GLOBAL_FUNCTIONS.has(word) else CodeColors.function
	return base_color


static func scan_string(source: String, start: int, colors: Array[Color]) -> int:
	var quote := source[start]
	var triple := start + 2 < source.length() and source.substr(start, 3) == quote.repeat(3)
	var delimiter_length := 3 if triple else 1
	var end := start + delimiter_length
	while end < source.length():
		if source[end] == "\\":
			end += 2
			continue
		if end + delimiter_length <= source.length() and source.substr(end, delimiter_length) == quote.repeat(delimiter_length):
			end += delimiter_length
			break
		end += 1
	paint(colors, start, mini(end, source.length()), CodeColors.string)
	return mini(end, source.length())


static func scan_path_end(source: String, start: int) -> int:
	var end := start
	while end < source.length() and source[end] not in [" ", "\t", ",", ")", "]", "}"]:
		end += 1
	return end


static func is_number_start(source: String, column: int) -> bool:
	if source[column] >= "0" and source[column] <= "9":
		return true
	return source[column] == "." and column + 1 < source.length() and source[column + 1] >= "0" and source[column + 1] <= "9"


static func scan_number_end(source: String, start: int) -> int:
	var end := start + 1
	while end < source.length() and (is_identifier_character(source[end]) or source[end] in [".", "+", "-"]):
		end += 1
	return end


static func word_before(source: String, start: int) -> String:
	var end := previous_non_space(source, start) + 1
	var begin := end
	while begin > 0 and is_identifier_character(source[begin - 1]):
		begin -= 1
	return source.substr(begin, end - begin)


static func previous_non_space(source: String, start: int) -> int:
	var column := start - 1
	while column >= 0 and source[column] in [" ", "\t"]:
		column -= 1
	return column


static func next_non_space(source: String, start: int) -> int:
	var column := start
	while column < source.length() and source[column] in [" ", "\t"]:
		column += 1
	return column


static func is_identifier_start(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper()


static func is_identifier_character(character: String) -> bool:
	return is_identifier_start(character) or (character >= "0" and character <= "9")


static func is_symbol(character: String) -> bool:
	return character not in [" ", "\t"]


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
