## CodeEdit syntax highlighter tests.

static func recognizes_gdscript_test() -> void:
	var highlighter := CommonHighlighter.create("scripts/player.gd")
	assert(highlighter is CodeHighlighterInstance)
	assert(highlighter.get_keyword_color("class_name") == CodeColors.declaration)
	assert(highlighter.get_keyword_color("func") == CodeColors.keyword)
	assert(highlighter.has_color_region("#"))
	pass


static func recognizes_extended_languages_test() -> void:
	var shader := CommonHighlighter.create("effects/water.gdshader")
	assert(shader.get_keyword_color("shader_type") == CodeColors.declaration)
	assert(shader.get_keyword_color("sampler2D") == CodeColors.type)
	var sql := CommonHighlighter.create("schema.sql")
	assert(sql.get_keyword_color("SELECT") == CodeColors.keyword)
	assert(sql.has_color_region("--"))
	var typescript := CommonHighlighter.create("app.ts")
	assert(typescript.get_keyword_color("satisfies") == CodeColors.keyword)
	assert(typescript.get_keyword_color("type") == CodeColors.keyword)
	assert(typescript.get_keyword_color("infer") == CodeColors.keyword)
	assert(typescript.has_color_region("`"))
	assert(not typescript.has_color_region("#"))
	var jsx := CommonHighlighter.create("Button.tsx")
	assert(jsx.has_color_region("<"))
	var markdown := MarkdownHighlighter.create()
	var markdown_regions := markdown.region_highlighter
	assert(markdown is MarkdownHighlighter)
	assert(markdown_regions.has_color_region("```"))
	assert(markdown_regions.has_color_region("["))
	assert(not markdown_regions.has_color_region("("))
	assert(not markdown_regions.has_keyword_color("https://"))
	assert(markdown_regions.has_color_region("#"))
	assert(markdown_regions.has_color_region("**"))
	assert(markdown_regions.has_color_region("~~"))
	assert(markdown_regions.has_color_region("<"))
	assert(markdown_regions.get_keyword_color("NOTE") == CodeColors.declaration)
	var markdown_edit := CodeEdit.new()
	CodeEditStyle.apply_base(markdown_edit)
	markdown_edit.syntax_highlighter = markdown
	var long_form := "This long-form article exercises **MarkdownParser** inline."
	markdown_edit.text = long_form + "\n"
	var prose_color := markdown_edit.get_theme_color("font_color")
	var long_form_line := markdown.get_line_syntax_highlighting(0)
	assert(long_form_line[0]["color"] == prose_color)
	assert(MarkdownHighlighter.color_at_column(long_form_line, 1, prose_color) == prose_color)
	assert(MarkdownHighlighter.color_at_column(long_form_line, 4, prose_color) == prose_color)
	var bold_at := long_form.find("**")
	assert(MarkdownHighlighter.color_at_column(long_form_line, bold_at, prose_color) == CodeColors.keyword)
	markdown_edit.text = "# Title\n"
	var heading := markdown.get_line_syntax_highlighting(0)
	assert(heading[0]["color"] == CodeColors.declaration)
	var link_sample := "see [docs](readme.md) end"
	markdown_edit.text = link_sample + "\n"
	var link_line := markdown.get_line_syntax_highlighting(0)
	var link_close := link_sample.find(")")
	assert(MarkdownHighlighter.color_at_column(link_line, link_close, prose_color) == FileColors.color_for_path("readme.md"))
	assert(MarkdownHighlighter.color_at_column(link_line, link_close + 1, prose_color) == prose_color)
	assert(MarkdownHighlighter.syntax_color_for_link_destination("https://godotengine.org") == null)
	assert(FileColors.color_for_path("C:/clips/voice.wav") == FileColors.audio_color)
	var slash_sample := "/audio-trim @agent/readme.md"
	markdown_edit.text = slash_sample + "\n"
	var slash_line := markdown.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(slash_line, 0, prose_color) == CodeColors.member)
	assert(MarkdownHighlighter.color_at_column(slash_line, slash_sample.find("@"), prose_color) == FileColors.color_for_path("agent/readme.md"))
	markdown_edit.text = "hello /git\n"
	assert(MarkdownHighlighter.color_at_column(markdown.get_line_syntax_highlighting(0), "hello /git".find("/"), prose_color) == prose_color)
	markdown_edit.text = "   /git args\n"
	assert(MarkdownHighlighter.color_at_column(markdown.get_line_syntax_highlighting(0), 3, prose_color) == CodeColors.member)
	var inline_mention := "x `@agent/ui` y"
	markdown_edit.text = inline_mention + "\n"
	var mention_line := markdown.get_line_syntax_highlighting(0)
	var mention_at := inline_mention.find("@")
	assert(MarkdownHighlighter.color_at_column(mention_line, mention_at, prose_color) == CodeColors.string)
	markdown_edit.free()
	var mdx := CommonHighlighter.create("docs/page.mdx") as MarkdownHighlighter
	assert(mdx.region_highlighter.has_color_region("`"))
	assert(mdx.region_highlighter.has_color_region("<"))
	var sconstruct := CommonHighlighter.create("SConstruct")
	assert(sconstruct.get_keyword_color("lambda") == CodeColors.keyword)
	assert(sconstruct.has_color_region("#"))
	pass


static func recognizes_data_shell_diff_and_build_files_test() -> void:
	var jsonc := CommonHighlighter.create("settings.JSONC")
	assert(jsonc.get_keyword_color("true") == CodeColors.type)
	assert(jsonc.has_color_region("//"))
	var powershell := CommonHighlighter.create("build.ps1")
	assert(powershell.get_keyword_color("param") == CodeColors.keyword)
	assert(powershell.has_color_region("#"))
	var diff := CommonHighlighter.create("change.patch")
	assert(diff.get_keyword_color("diff") == CodeColors.function)
	assert(diff.has_color_region("@@"))
	assert(diff.has_color_region("+++"))
	var cmake := CommonHighlighter.create("CMakeLists.txt")
	assert(cmake.get_keyword_color("add_executable") == CodeColors.keyword)
	assert(cmake.has_color_region("#"))
	pass


static func unknown_extension_keeps_base_colors_without_language_rules_test() -> void:
	var highlighter := CommonHighlighter.create("asset.unknown")
	assert(highlighter.number_color == CodeColors.number)
	assert(highlighter.symbol_color == CodeColors.symbol)
	assert(highlighter.get_keyword_colors().is_empty())
	assert(not highlighter.has_color_region("#"))
	pass
