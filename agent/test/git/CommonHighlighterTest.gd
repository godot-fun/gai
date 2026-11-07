## CodeEdit syntax highlighter tests.

static func palette_matches_godot_editor_test() -> void:
	assert(CodeColors.DARK_KEYWORD == Color(1.0, 0.44, 0.52))
	assert(CodeColors.DARK_TYPE == Color(0.26, 1.0, 0.76))
	assert(CodeColors.DARK_STRING == Color(1.0, 0.93, 0.63))
	assert(CodeColors.DARK_FUNCTION == Color(0.34, 0.7, 1.0))
	assert(CodeColors.LIGHT_KEYWORD == Color(0.9, 0.135, 0.51))
	assert(CodeColors.LIGHT_TYPE == Color(0.0, 0.6, 0.2))
	assert(CodeColors.LIGHT_STRING == Color(0.6, 0.42, 0.0))
	assert(CodeColors.LIGHT_FUNCTION == Color(0.0, 0.225, 0.9))
	pass

static func recognizes_bare_suffix_test() -> void:
	var script := CommonHighlighter.create("gd")
	assert(script is GdScriptHighlighter)
	assert(CommonHighlighter.create("md") is MarkdownHighlighter)
	assert(CommonHighlighter.create(".md") is MarkdownHighlighter)
	var docker := CommonHighlighter.create("Dockerfile")
	assert(docker.get_keyword_color("FROM") == CodeColors.declaration)
	pass


static func recognizes_gdscript_test() -> void:
	var highlighter := CommonHighlighter.create("scripts/player.gd")
	assert(highlighter is GdScriptHighlighter)
	var edit := CodeEdit.new()
	CodeEditStyle.apply_base(edit)
	assert(edit.get_theme_font("font") == Fonts.code())
	var contextual_alternates := TextServerManager.get_primary_interface().name_to_tag("calt")
	assert((Fonts.code() as FontVariation).opentype_features[contextual_alternates] == 0)
	var code_base := (Fonts.code() as FontVariation).base_font as FontFile
	assert(code_base.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_AUTO)
	assert(code_base.keep_rounding_remainders)
	assert(code_base.force_autohinter)
	assert(edit.get_theme_constant("line_spacing") == 4)
	edit.syntax_highlighter = highlighter
	edit.text = "class_name Player\nextends CharacterBody2D\n@export var speed: float = 220.0\nfunc _physics_process(delta: float) -> void:\n\tInput.get_vector(\"left\")\n\tpass # done\n"
	var base_color := edit.get_theme_color("font_color")
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(0), 0, base_color) == CodeColors.keyword)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(0), 11, base_color) == CodeColors.engine_type)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(2), 0, base_color) == CodeColors.tag)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(2), 8, base_color) == CodeColors.keyword)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(3), 5, base_color) == CodeColors.function_definition)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(4), 1, base_color) == CodeColors.engine_type)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(4), 7, base_color) == CodeColors.function)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(5), 1, base_color) == CodeColors.declaration)
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(5), 6, base_color) == CodeColors.comment)
	edit.text = "const REQUEST_TIMEOUT_MILLIS := 5\n"
	assert(MarkdownHighlighter.color_at_column(highlighter.get_line_syntax_highlighting(0), 6, base_color) == base_color)
	edit.text = "5 * TimeUtils.MILLIS_PER_MINUTE\n"
	var millis_line := highlighter.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(millis_line, 4, base_color) == CodeColors.engine_type)
	assert(MarkdownHighlighter.color_at_column(millis_line, "5 * TimeUtils.MILLIS_PER_MINUTE".find("MILLIS"), base_color) == CodeColors.member)
	edit.text = "base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY\n"
	var assign_line := highlighter.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(assign_line, "base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY".find("antialiasing"), base_color) == CodeColors.member)
	assert(MarkdownHighlighter.color_at_column(assign_line, "base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY".find("FONT_ANTIALIASING_GRAY"), base_color) == CodeColors.member)
	edit.text = "[StringUtils.format(\"x\", api_key)]\n"
	var format_line := highlighter.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(format_line, "[StringUtils.format(\"x\", api_key)]".find("format"), base_color) == CodeColors.function)
	assert(MarkdownHighlighter.color_at_column(format_line, "[StringUtils.format(\"x\", api_key)]".find("api_key"), base_color) == base_color)
	edit.free()
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
	assert(markdown_edit.get_theme_color("font_readonly_color") == Colors.primary_text)
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
	var link_open := link_sample.find("[")
	var label_close := link_sample.find("]")
	var link_close := link_sample.find(")")
	assert(MarkdownHighlighter.color_at_column(link_line, link_open, prose_color) == Colors.info)
	assert(MarkdownHighlighter.color_at_column(link_line, link_open + 1, prose_color) == Colors.info)
	assert(MarkdownHighlighter.color_at_column(link_line, label_close, prose_color) == Colors.info)
	assert(MarkdownHighlighter.color_at_column(link_line, link_close, prose_color) == FileColors.color_for_path("readme.md"))
	assert(MarkdownHighlighter.color_at_column(link_line, link_close + 1, prose_color) == prose_color)
	assert(MarkdownHighlighter.syntax_color_for_link_destination("https://godotengine.org") == ThemeColor.promote(Colors.info, Weights.w_4))
	assert(MarkdownHighlighter.syntax_color_for_link_destination("mailto:user@example.com") == null)
	var http_sample := "[Godot Engine](https://godotengine.org), trailing text"
	markdown_edit.text = http_sample + "\n"
	var http_line := markdown.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(http_line, http_sample.find("("), prose_color) == ThemeColor.promote(Colors.info, Weights.w_4))
	assert(MarkdownHighlighter.color_at_column(http_line, http_sample.find("https://"), prose_color) == ThemeColor.promote(Colors.info, Weights.w_4))
	assert(MarkdownHighlighter.color_at_column(http_line, http_sample.find(")"), prose_color) == ThemeColor.promote(Colors.info, Weights.w_4))
	assert(MarkdownHighlighter.color_at_column(http_line, http_sample.find(")") + 1, prose_color) == prose_color)
	assert(MarkdownHighlighter.color_at_column(http_line, http_sample.find("trailing"), prose_color) == prose_color)
	var previous_column := -1
	for column in http_line.keys():
		assert(int(column) > previous_column)
		previous_column = int(column)
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
	assert(jsonc is JsonHighlighter)
	assert((jsonc as JsonHighlighter).allow_comments)
	var powershell := CommonHighlighter.create("build.ps1")
	assert(powershell is WindowsHighlighter)
	assert((powershell as WindowsHighlighter).is_powershell)
	var batch := CommonHighlighter.create("build.bat")
	assert(batch is WindowsHighlighter)
	assert(not (batch as WindowsHighlighter).is_powershell)
	var latex := CommonHighlighter.create("notes.tex")
	assert(latex.has_color_region("%"))
	assert(latex.has_color_region("{"))
	var diff := CommonHighlighter.create("change.patch")
	assert(diff.get_keyword_color("diff") == CodeColors.function)
	assert(diff.has_color_region("@@"))
	assert(diff.has_color_region("+++"))
	var cmake := CommonHighlighter.create("CMakeLists.txt")
	assert(cmake.get_keyword_color("add_executable") == CodeColors.keyword)
	assert(cmake.has_color_region("#"))
	pass


static func recognizes_json_test() -> void:
	var highlighter := CommonHighlighter.create("config.json")
	assert(highlighter is JsonHighlighter)
	var edit := CodeEdit.new()
	CodeEditStyle.apply_base(edit)
	edit.syntax_highlighter = highlighter
	var source := "{\"name\": \"Godot\", \"count\": -12.5e+2, \"enabled\": true, \"empty\": null}"
	edit.text = source + "\n"
	var base_color := edit.get_theme_color("font_color")
	var highlighting := highlighter.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(highlighting, source.find("name"), base_color) == CodeColors.member)
	assert(MarkdownHighlighter.color_at_column(highlighting, source.find("Godot"), base_color) == CodeColors.string)
	assert(MarkdownHighlighter.color_at_column(highlighting, source.find("-12.5"), base_color) == CodeColors.number)
	assert(MarkdownHighlighter.color_at_column(highlighting, source.find("true"), base_color) == CodeColors.type)
	assert(MarkdownHighlighter.color_at_column(highlighting, source.find("null"), base_color) == CodeColors.type)
	assert(MarkdownHighlighter.color_at_column(highlighting, 0, base_color) == CodeColors.symbol)
	var jsonc := JsonHighlighter.create("jsonc")
	edit.syntax_highlighter = jsonc
	edit.text = "{\"enabled\": true} // optional comment\n"
	assert(MarkdownHighlighter.color_at_column(jsonc.get_line_syntax_highlighting(0), edit.text.find("//"), base_color) == CodeColors.comment)
	edit.free()
	pass


static func recognizes_windows_scripts_test() -> void:
	var powershell := CommonHighlighter.create("agent.ps1")
	assert(powershell is WindowsHighlighter)
	var edit := CodeEdit.new()
	CodeEditStyle.apply_base(edit)
	edit.syntax_highlighter = powershell
	var base_color := edit.get_theme_color("font_color")
	var powershell_source := "$env:APPDATA = Join-Path $Root \".godot\" # portable data"
	edit.text = powershell_source + "\n"
	var powershell_line := powershell.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(powershell_line, 0, base_color) == CodeColors.member)
	assert(MarkdownHighlighter.color_at_column(powershell_line, powershell_source.find("Join-Path"), base_color) == CodeColors.function)
	assert(MarkdownHighlighter.color_at_column(powershell_line, powershell_source.find(".godot"), base_color) == CodeColors.string)
	assert(MarkdownHighlighter.color_at_column(powershell_line, powershell_source.find("#"), base_color) == CodeColors.comment)
	var batch := CommonHighlighter.create("agent.bat")
	assert(batch is WindowsHighlighter)
	edit.syntax_highlighter = batch
	var batch_source := "powershell -File %~dp0agent.ps1 %*"
	edit.text = batch_source + "\n"
	var batch_line := batch.get_line_syntax_highlighting(0)
	assert(MarkdownHighlighter.color_at_column(batch_line, batch_source.find("%~dp0"), base_color) == CodeColors.member)
	assert(MarkdownHighlighter.color_at_column(batch_line, batch_source.find("%*"), base_color) == CodeColors.member)
	edit.text = "rem launcher comment\n"
	assert(MarkdownHighlighter.color_at_column(batch.get_line_syntax_highlighting(0), 0, base_color) == CodeColors.comment)
	edit.free()
	pass


static func unknown_extension_keeps_base_colors_without_language_rules_test() -> void:
	var highlighter := CommonHighlighter.create("asset.unknown")
	assert(highlighter.number_color == CodeColors.number)
	assert(highlighter.symbol_color == CodeColors.symbol)
	assert(highlighter.get_keyword_colors().is_empty())
	assert(not highlighter.has_color_region("#"))
	pass
