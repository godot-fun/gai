class_name GitCodeHighlighter
extends Object

## Creates a theme-aware CodeEdit highlighter from a repository file name. CodeHighlighter is
## deliberately used instead of a parser so incomplete code remains colorful while it is edited.

const SCRIPT_EXTENSIONS := ["gd", "py", "pyw", "pyi", "rb", "rake", "lua", "r", "jl", "pl", "pm", "tcl"]
const C_STYLE_EXTENSIONS := ["c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx", "m", "mm", "cs", "java", "js", "jsx", "mjs", "cjs", "ts", "tsx", "go", "rs", "swift", "kt", "kts", "dart", "scala", "groovy", "gradle", "php", "sol", "proto"]
const JS_EXTENSIONS := ["js", "jsx", "mjs", "cjs", "ts", "tsx"]
const CPP_EXTENSIONS := ["c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx", "m", "mm"]
const SHADER_EXTENSIONS := ["gdshader", "gdshaderinc", "glsl", "vert", "frag", "geom", "tesc", "tese", "comp", "hlsl", "fx", "wgsl"]
const DATA_EXTENSIONS := ["json", "jsonc", "json5", "yaml", "yml", "toml", "ini", "cfg", "conf", "env", "properties", "tscn", "tres", "godot", "gdextension", "import", "lock"]
const MARKUP_EXTENSIONS := ["md", "markdown", "mdx", "html", "htm", "xhtml", "xml", "svg", "vue", "svelte", "css", "scss", "sass", "less"]
const SHELL_EXTENSIONS := ["sh", "bash", "zsh", "fish", "ps1", "psm1", "bat", "cmd"]
const SQL_EXTENSIONS := ["sql", "psql", "ddl", "dml"]
const DIFF_EXTENSIONS := ["diff", "patch", "rej"]
const LATEX_EXTENSIONS := ["tex", "sty", "cls", "bib"]

const COMMON_KEYWORDS := ["if", "else", "elif", "for", "while", "do", "match", "switch", "case", "break", "continue", "return", "class", "extends", "enum", "struct", "interface", "trait", "func", "function", "def", "fn", "var", "let", "const", "static", "public", "private", "protected", "internal", "async", "await", "yield", "try", "catch", "except", "finally", "throw", "raise", "import", "from", "export", "package", "namespace", "new", "delete", "this", "self", "super", "in", "is", "as", "and", "or", "not", "pass"]
const TYPE_KEYWORDS := ["void", "bool", "boolean", "int", "uint", "float", "double", "char", "string", "String", "StringName", "Array", "Dictionary", "Variant", "Object", "Node", "Resource", "Vector2", "Vector2i", "Vector3", "Vector3i", "Color", "Callable", "Signal", "true", "false", "null", "nil", "None"]
const DECLARATION_KEYWORDS := ["class_name", "extends", "signal", "enum", "const", "static", "var", "func", "@export", "@onready", "@tool", "@warning_ignore", "@rpc", "override", "virtual", "abstract", "readonly", "typedef", "using"]
const SHELL_KEYWORDS := ["case", "do", "done", "elif", "else", "esac", "fi", "for", "foreach", "function", "if", "in", "select", "then", "until", "while", "param", "begin", "end", "process"]
const GDSCRIPT_KEYWORDS := ["assert", "breakpoint", "class_name", "extends", "is_instance_of", "preload", "signal", "super", "when", "@abstract", "@export", "@export_category", "@export_color_no_alpha", "@export_custom", "@export_dir", "@export_enum", "@export_exp_easing", "@export_file", "@export_file_path", "@export_flags", "@export_flags_2d_navigation", "@export_flags_2d_physics", "@export_flags_2d_render", "@export_flags_3d_navigation", "@export_flags_3d_physics", "@export_flags_3d_render", "@export_flags_avoidance", "@export_global_dir", "@export_global_file", "@export_group", "@export_multiline", "@export_node_path", "@export_placeholder", "@export_range", "@export_storage", "@export_subgroup", "@export_tool_button", "@icon", "@onready", "@rpc", "@static_unload", "@tool", "@warning_ignore", "@warning_ignore_start", "@warning_ignore_restore"]
const GDSCRIPT_TYPES := ["AABB", "Basis", "NodePath", "PackedByteArray", "PackedColorArray", "PackedFloat32Array", "PackedFloat64Array", "PackedInt32Array", "PackedInt64Array", "PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "Plane", "Projection", "Quaternion", "Rect2", "Rect2i", "RID", "Transform2D", "Transform3D", "Vector4", "Vector4i", "PI", "TAU", "INF", "NAN"]
const PYTHON_KEYWORDS := ["assert", "del", "except", "False", "finally", "global", "lambda", "nonlocal", "pass", "True", "with", "None", "__name__", "__main__"]
const JS_KEYWORDS := ["constructor", "debugger", "default", "delete", "instanceof", "of", "typeof", "undefined", "NaN", "Infinity", "get", "set", "implements", "declare", "keyof", "satisfies", "unknown", "never", "any", "type", "infer", "asserts", "with", "module", "bigint", "symbol", "globalThis"]
const MARKDOWN_KEYWORDS := ["TODO", "FIXME", "NOTE", "WARNING", "IMPORTANT", "TIP", "CAUTION"]
const CPP_KEYWORDS := ["alignas", "alignof", "asm", "auto", "constexpr", "consteval", "constinit", "decltype", "explicit", "extern", "friend", "inline", "mutable", "noexcept", "operator", "register", "requires", "sizeof", "template", "thread_local", "typename", "union", "volatile", "concept", "nullptr"]
const RUST_KEYWORDS := ["crate", "dyn", "impl", "loop", "macro_rules", "mod", "move", "mut", "pub", "ref", "type", "unsafe", "use", "where", "Self", "Box", "Option", "Result", "Some", "None", "Ok", "Err"]
const GO_KEYWORDS := ["chan", "defer", "fallthrough", "go", "goto", "map", "range", "select", "type", "interface", "package"]
const SHADER_KEYWORDS := ["shader_type", "render_mode", "uniform", "varying", "in", "out", "inout", "discard", "layout", "precision", "attribute", "buffer", "shared", "sampler", "texture", "textureLod", "vertex", "fragment", "light", "compute", "group_uniforms"]
const SHADER_TYPES := ["bvec2", "bvec3", "bvec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4", "vec2", "vec3", "vec4", "mat2", "mat3", "mat4", "sampler2D", "sampler2DArray", "sampler3D", "samplerCube", "isampler2D", "usampler2D"]
const SQL_KEYWORDS := ["ADD", "ALL", "ALTER", "AND", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASE", "CHECK", "COLUMN", "COMMIT", "CONSTRAINT", "CREATE", "DATABASE", "DEFAULT", "DELETE", "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS", "FOREIGN", "FROM", "FULL", "GRANT", "GROUP", "HAVING", "IN", "INDEX", "INNER", "INSERT", "INTO", "IS", "JOIN", "KEY", "LEFT", "LIKE", "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "OUTER", "PRIMARY", "REFERENCES", "RETURNING", "REVOKE", "RIGHT", "ROLLBACK", "SELECT", "SET", "TABLE", "THEN", "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "VALUES", "VIEW", "WHEN", "WHERE", "WITH"]


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
		configure_c_style(highlighter, extension)
	elif extension in SHADER_EXTENSIONS:
		configure_shader(highlighter)
	elif extension in DATA_EXTENSIONS or file_name in PackedStringArray(["dockerfile", "makefile", ".gitignore", ".gitattributes", ".editorconfig"]):
		configure_data(highlighter, extension, file_name)
	elif extension in MARKUP_EXTENSIONS:
		configure_markup(highlighter, extension)
	elif extension in SHELL_EXTENSIONS:
		configure_shell(highlighter, extension)
	elif extension in SQL_EXTENSIONS:
		configure_sql(highlighter)
	elif extension in DIFF_EXTENSIONS:
		configure_diff(highlighter)
	elif extension in LATEX_EXTENSIONS:
		configure_latex(highlighter)
	elif file_name in PackedStringArray(["sconstruct", "sconscript"]):
		configure_script(highlighter, "py")
	elif file_name == "cmakelists.txt" or extension == "cmake":
		configure_cmake(highlighter)
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
	if extension == "gd":
		add_keywords(highlighter, GDSCRIPT_KEYWORDS, CodeColors.declaration)
		add_keywords(highlighter, GDSCRIPT_TYPES, CodeColors.type)
		highlighter.add_color_region(r'"""', r'"""', CodeColors.string)
		highlighter.add_color_region(r"'''", r"'''", CodeColors.string)
		# StringName / NodePath literals: &"name", ^"path"
		highlighter.add_color_region('&"', '"', CodeColors.string)
		highlighter.add_color_region('^"', '"', CodeColors.string)
	elif extension.begins_with("py"):
		add_keywords(highlighter, PYTHON_KEYWORDS, CodeColors.keyword)
		highlighter.add_color_region(r'"""', r'"""', CodeColors.string)
		highlighter.add_color_region(r"'''", r"'''", CodeColors.string)
	elif extension == "lua":
		highlighter.add_color_region("--[[", "]]", CodeColors.comment)
		highlighter.add_color_region("--", "", CodeColors.comment, true)
	pass


static func configure_c_style(highlighter: CodeHighlighter, extension: String) -> void:
	add_keywords(highlighter, COMMON_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, TYPE_KEYWORDS, CodeColors.type)
	add_keywords(highlighter, DECLARATION_KEYWORDS, CodeColors.declaration)
	add_quoted_strings(highlighter, CodeColors.string)
	highlighter.add_color_region("//", "", CodeColors.comment, true)
	highlighter.add_color_region("/*", "*/", CodeColors.comment)
	# JS/TS private fields use `#name`; only C-family preprocessors should own line `#`.
	if extension in JS_EXTENSIONS:
		add_keywords(highlighter, JS_KEYWORDS, CodeColors.keyword)
		highlighter.add_color_region("`", "`", CodeColors.string)
		if extension in PackedStringArray(["jsx", "tsx"]):
			highlighter.add_color_region("<", ">", CodeColors.tag)
	else:
		highlighter.add_color_region("#", "", CodeColors.declaration, true)
		if extension in CPP_EXTENSIONS:
			add_keywords(highlighter, CPP_KEYWORDS, CodeColors.keyword)
		elif extension == "rs":
			add_keywords(highlighter, RUST_KEYWORDS, CodeColors.keyword)
		elif extension == "go":
			add_keywords(highlighter, GO_KEYWORDS, CodeColors.keyword)
	pass


static func configure_shader(highlighter: CodeHighlighter) -> void:
	add_keywords(highlighter, COMMON_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, TYPE_KEYWORDS, CodeColors.type)
	add_keywords(highlighter, SHADER_KEYWORDS, CodeColors.declaration)
	add_keywords(highlighter, SHADER_TYPES, CodeColors.type)
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
	elif extension in PackedStringArray(["ini", "cfg", "conf", "properties", "godot", "tscn", "tres", "gdextension", "import"]):
		highlighter.add_color_region(";", "", CodeColors.comment, true)
		highlighter.add_color_region("#", "", CodeColors.comment, true)
	else:
		highlighter.add_color_region("#", "", CodeColors.comment, true)
	if file_name == "dockerfile":
		add_keywords(highlighter, PackedStringArray(["FROM", "RUN", "CMD", "LABEL", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT", "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL"]), CodeColors.declaration)
	elif file_name == "makefile":
		add_keywords(highlighter, PackedStringArray(["define", "else", "endef", "endif", "export", "ifdef", "ifeq", "ifndef", "ifneq", "include", "override", "private", "sinclude", "undefine", "unexport", "vpath"]), CodeColors.keyword)
	pass


static func configure_markup(highlighter: CodeHighlighter, extension: String) -> void:
	add_quoted_strings(highlighter, CodeColors.string)
	if extension in PackedStringArray(["md", "markdown", "mdx"]):
		add_keywords(highlighter, MARKDOWN_KEYWORDS, CodeColors.declaration)
		# Fenced blocks before single backticks so ```…``` wins over nested `.
		highlighter.add_color_region("```", "```", CodeColors.string)
		highlighter.add_color_region("`", "`", CodeColors.string)
		highlighter.add_color_region("<!--", "-->", CodeColors.comment)
		highlighter.add_color_region("#", "", CodeColors.declaration, true)
		highlighter.add_color_region("**", "**", CodeColors.keyword)
		highlighter.add_color_region("~~", "~~", CodeColors.comment)
		# Inline HTML (and JSX in MDX).
		highlighter.add_color_region("<", ">", CodeColors.tag)
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


static func configure_sql(highlighter: CodeHighlighter) -> void:
	add_keywords(highlighter, SQL_KEYWORDS, CodeColors.keyword)
	add_keywords(highlighter, PackedStringArray(["BOOLEAN", "CHAR", "DATE", "DECIMAL", "FLOAT", "INT", "INTEGER", "JSON", "NUMERIC", "REAL", "TEXT", "TIME", "TIMESTAMP", "UUID", "VARCHAR", "TRUE", "FALSE", "NULL"]), CodeColors.type)
	add_quoted_strings(highlighter, CodeColors.string)
	highlighter.add_color_region("--", "", CodeColors.comment, true)
	highlighter.add_color_region("/*", "*/", CodeColors.comment)
	pass


static func configure_diff(highlighter: CodeHighlighter) -> void:
	highlighter.add_color_region("@@", "@@", CodeColors.declaration, true)
	highlighter.add_color_region("+++", "", CodeColors.type, true)
	highlighter.add_color_region("---", "", CodeColors.keyword, true)
	highlighter.add_color_region("+", "", CodeColors.string, true)
	highlighter.add_color_region("-", "", CodeColors.keyword, true)
	highlighter.add_color_region("diff ", "", CodeColors.function, true)
	pass


static func configure_latex(highlighter: CodeHighlighter) -> void:
	highlighter.add_color_region("%", "", CodeColors.comment, true)
	highlighter.add_color_region(r"\begin{", "}", CodeColors.declaration)
	highlighter.add_color_region(r"\end{", "}", CodeColors.declaration)
	highlighter.add_color_region("{", "}", CodeColors.string)
	pass


static func configure_cmake(highlighter: CodeHighlighter) -> void:
	add_keywords(highlighter, PackedStringArray(["add_custom_command", "add_custom_target", "add_executable", "add_library", "cmake_minimum_required", "else", "elseif", "endforeach", "endfunction", "endif", "endmacro", "endwhile", "find_package", "foreach", "function", "if", "include", "install", "macro", "message", "option", "project", "return", "set", "target_compile_definitions", "target_compile_options", "target_include_directories", "target_link_libraries", "while"]), CodeColors.keyword)
	add_quoted_strings(highlighter, CodeColors.string)
	highlighter.add_color_region("#", "", CodeColors.comment, true)
	pass
