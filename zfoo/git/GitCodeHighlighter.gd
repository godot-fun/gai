class_name GitCodeHighlighter
extends Object

## Creates a theme-aware CodeEdit highlighter from a repository file name. CodeHighlighter is
## deliberately used instead of a parser so incomplete code remains colorful while it is edited.

const SCRIPT_EXTENSIONS := ["gd", "py", "pyw", "rb", "lua"]
const C_STYLE_EXTENSIONS := ["c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx", "cs", "java", "js", "jsx", "ts", "tsx", "go", "rs", "swift", "kt", "kts"]
const DATA_EXTENSIONS := ["json", "jsonc", "json5", "yaml", "yml", "toml", "ini", "cfg", "conf", "env", "properties", "tscn", "tres", "godot"]
const MARKUP_EXTENSIONS := ["md", "markdown", "html", "htm", "xml", "svg", "css", "scss", "sass", "less"]
const SHELL_EXTENSIONS := ["sh", "bash", "zsh", "fish", "ps1", "psm1", "bat", "cmd"]

const COMMON_KEYWORDS := ["if", "else", "elif", "for", "while", "do", "match", "switch", "case", "break", "continue", "return", "class", "extends", "enum", "struct", "interface", "trait", "func", "function", "def", "fn", "var", "let", "const", "static", "public", "private", "protected", "internal", "async", "await", "yield", "try", "catch", "except", "finally", "throw", "raise", "import", "from", "export", "package", "namespace", "new", "delete", "this", "self", "super", "in", "is", "as", "and", "or", "not"]
const TYPE_KEYWORDS := ["void", "bool", "boolean", "int", "uint", "float", "double", "char", "string", "String", "StringName", "Array", "Dictionary", "Variant", "Object", "Node", "Resource", "Vector2", "Vector2i", "Vector3", "Vector3i", "Color", "Callable", "Signal", "true", "false", "null", "nil", "None"]
const DECLARATION_KEYWORDS := ["class_name", "extends", "signal", "enum", "const", "static", "var", "func", "@export", "@onready", "@tool", "@warning_ignore", "@rpc", "override", "virtual", "abstract", "readonly", "typedef", "using"]
const SHELL_KEYWORDS := ["case", "do", "done", "elif", "else", "esac", "fi", "for", "foreach", "function", "if", "in", "select", "then", "until", "while", "param", "begin", "end", "process"]


static func create(file_path: String) -> CodeHighlighter:
	var highlighter := CodeHighlighter.new()
	highlighter.number_color = CodeColors.number
	highlighter.symbol_color = CodeColors.symbol
	highlighter.function_color = CodeColors.function
	highlighter.member_variable_color = CodeColors.member
	var extension := file_path.get_extension().to_lower()
	var file_name := file_path.get_file().to_lower()
	if extension in SCRIPT_EXTENSIONS:
		configure_script(highlighter, extension)
	elif extension in C_STYLE_EXTENSIONS:
		configure_c_style(highlighter)
	elif extension in DATA_EXTENSIONS or file_name in PackedStringArray(["dockerfile", "makefile", ".gitignore", ".gitattributes", ".editorconfig"]):
		configure_data(highlighter, extension, file_name)
	elif extension in MARKUP_EXTENSIONS:
		configure_markup(highlighter, extension)
	elif extension in SHELL_EXTENSIONS:
		configure_shell(highlighter, extension)
	return highlighter


static func add_keywords(highlighter: CodeHighlighter, words: Array, color: Color) -> void:
	for word in words:
		highlighter.add_keyword_color(word, color)
	pass


static func add_quoted_strings(highlighter: CodeHighlighter, color: Color) -> void:
	highlighter.add_color_region('"', '"', color)
	highlighter.add_color_region("'", "'", color)
	pass


static func configure_script(highlighter: CodeHighlighter, extension: String) -> void:
	add_keywords(highlighter, COMMON_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, TYPE_KEYWORDS, CodeColors.type)
	add_keywords(highlighter, DECLARATION_KEYWORDS, CodeColors.declaration)
	add_quoted_strings(highlighter, CodeColors.string)
	highlighter.add_color_region("#", "", CodeColors.comment, true)
	if extension == "gd" or extension.begins_with("py"):
		highlighter.add_color_region("\"\"\"", "\"\"\"", CodeColors.string)
		highlighter.add_color_region("'''", "'''", CodeColors.string)
	elif extension == "lua":
		highlighter.add_color_region("--[[", "]]", CodeColors.comment)
		highlighter.add_color_region("--", "", CodeColors.comment, true)
	pass


static func configure_c_style(highlighter: CodeHighlighter) -> void:
	add_keywords(highlighter, COMMON_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, TYPE_KEYWORDS, CodeColors.type)
	add_keywords(highlighter, DECLARATION_KEYWORDS, CodeColors.declaration)
	add_quoted_strings(highlighter, CodeColors.string)
	highlighter.add_color_region("//", "", CodeColors.comment, true)
	highlighter.add_color_region("/*", "*/", CodeColors.comment)
	highlighter.add_color_region("#", "", CodeColors.declaration, true)
	pass


static func configure_data(highlighter: CodeHighlighter, extension: String, file_name: String) -> void:
	add_keywords(highlighter, PackedStringArray(["true", "false", "null", "yes", "no", "on", "off"]), CodeColors.type)
	add_quoted_strings(highlighter, CodeColors.string)
	if extension in PackedStringArray(["jsonc", "json5"]):
		highlighter.add_color_region("//", "", CodeColors.comment, true)
		highlighter.add_color_region("/*", "*/", CodeColors.comment)
	elif extension in PackedStringArray(["ini", "cfg", "conf", "properties", "godot", "tscn", "tres"]):
		highlighter.add_color_region(";", "", CodeColors.comment, true)
		highlighter.add_color_region("#", "", CodeColors.comment, true)
	else:
		highlighter.add_color_region("#", "", CodeColors.comment, true)
	if file_name == "dockerfile":
		add_keywords(highlighter, PackedStringArray(["FROM", "RUN", "CMD", "LABEL", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT", "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL"]), CodeColors.declaration)
	pass


static func configure_markup(highlighter: CodeHighlighter, extension: String) -> void:
	add_quoted_strings(highlighter, CodeColors.string)
	if extension in PackedStringArray(["md", "markdown"]):
		highlighter.add_color_region("`", "`", CodeColors.string)
		highlighter.add_color_region("<!--", "-->", CodeColors.comment)
	else:
		highlighter.add_color_region("<!--", "-->", CodeColors.comment)
		highlighter.add_color_region("<", ">", CodeColors.tag)
	if extension in PackedStringArray(["css", "scss", "sass", "less"]):
		highlighter.add_color_region("/*", "*/", CodeColors.comment)
	pass


static func configure_shell(highlighter: CodeHighlighter, extension: String) -> void:
	add_keywords(highlighter, SHELL_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, PackedStringArray(["true", "false", "null"]), CodeColors.type)
	add_quoted_strings(highlighter, CodeColors.string)
	if extension in PackedStringArray(["bat", "cmd"]):
		highlighter.add_color_region("REM ", "", CodeColors.comment, true)
	else:
		highlighter.add_color_region("#", "", CodeColors.comment, true)
	pass
