## Diff code syntax highlighter tests.

static func recognizes_gdscript_test() -> void:
	var highlighter := GitCodeHighlighter.create("scripts/player.gd")
	assert(highlighter.get_keyword_color("func").a > 0.0)
	assert(highlighter.get_keyword_color("pass") == CodeColors.keyword)
	assert(highlighter.get_keyword_color("Vector2").a > 0.0)
	assert(highlighter.get_keyword_color("PackedVector4Array") == CodeColors.type)
	assert(highlighter.get_keyword_color("PI") == CodeColors.type)
	assert(highlighter.get_keyword_color("@export_range") == CodeColors.declaration)
	assert(highlighter.get_keyword_color("@abstract") == CodeColors.declaration)
	assert(highlighter.get_keyword_color("@export_tool_button") == CodeColors.declaration)
	assert(highlighter.has_color_region("#"))
	assert(highlighter.has_color_region('&"'))
	assert(highlighter.has_color_region('^"'))
	pass


static func recognizes_extended_languages_test() -> void:
	var shader := GitCodeHighlighter.create("effects/water.gdshader")
	assert(shader.get_keyword_color("shader_type") == CodeColors.declaration)
	assert(shader.get_keyword_color("sampler2D") == CodeColors.type)
	var sql := GitCodeHighlighter.create("schema.sql")
	assert(sql.get_keyword_color("SELECT") == CodeColors.keyword)
	assert(sql.has_color_region("--"))
	var typescript := GitCodeHighlighter.create("app.ts")
	assert(typescript.get_keyword_color("satisfies") == CodeColors.keyword)
	assert(typescript.get_keyword_color("type") == CodeColors.keyword)
	assert(typescript.get_keyword_color("infer") == CodeColors.keyword)
	assert(typescript.has_color_region("`"))
	assert(not typescript.has_color_region("#"))
	var jsx := GitCodeHighlighter.create("Button.tsx")
	assert(jsx.has_color_region("<"))
	var markdown := GitCodeHighlighter.create("README.md")
	assert(markdown.has_color_region("```"))
	assert(markdown.has_color_region("#"))
	assert(markdown.has_color_region("**"))
	assert(markdown.has_color_region("~~"))
	assert(markdown.has_color_region("<"))
	assert(markdown.get_keyword_color("NOTE") == CodeColors.declaration)
	var mdx := GitCodeHighlighter.create("docs/page.mdx")
	assert(mdx.has_color_region("`"))
	assert(mdx.has_color_region("<"))
	var sconstruct := GitCodeHighlighter.create("SConstruct")
	assert(sconstruct.get_keyword_color("lambda") == CodeColors.keyword)
	assert(sconstruct.has_color_region("#"))
	pass


static func recognizes_data_shell_diff_and_build_files_test() -> void:
	var jsonc := GitCodeHighlighter.create("settings.JSONC")
	assert(jsonc.get_keyword_color("true") == CodeColors.type)
	assert(jsonc.has_color_region("//"))
	var powershell := GitCodeHighlighter.create("build.ps1")
	assert(powershell.get_keyword_color("param") == CodeColors.keyword)
	assert(powershell.has_color_region("#"))
	var diff := GitCodeHighlighter.create("change.patch")
	assert(diff.get_keyword_color("diff") == CodeColors.function)
	assert(diff.has_color_region("@@"))
	assert(diff.has_color_region("+++"))
	var cmake := GitCodeHighlighter.create("CMakeLists.txt")
	assert(cmake.get_keyword_color("add_executable") == CodeColors.keyword)
	assert(cmake.has_color_region("#"))
	pass


static func unknown_extension_keeps_base_colors_without_language_rules_test() -> void:
	var highlighter := GitCodeHighlighter.create("asset.unknown")
	assert(highlighter.number_color == CodeColors.number)
	assert(highlighter.symbol_color == CodeColors.symbol)
	assert(highlighter.get_keyword_colors().is_empty())
	assert(not highlighter.has_color_region("#"))
	pass
