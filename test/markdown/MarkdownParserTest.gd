
func heading_and_inline_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("# Title\n\n**bold** and *italic*").bbcode
	assert("# Title" not in bbcode)
	assert("[b]bold[/b]" in bbcode)
	assert("[i]italic[/i]" in bbcode)
	assert("[font_size=32]" in bbcode)
	assert("[b]Title[/b]" not in bbcode)
	pass


func ordered_list_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("1. first\n2. second").bbcode
	assert("1. first" in bbcode)
	assert("2. second" in bbcode)
	assert("•" not in bbcode)
	pass


func task_list_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("- [ ] todo\n- [x] done").bbcode
	assert("☐" in bbcode)
	assert("☑" in bbcode)
	pass


func blockquote_multiline_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("> line one\n> line two").bbcode
	assert("[indent]" in bbcode)
	assert("[table=2]" in bbcode)
	assert(bbcode.count("bg=" + MarkdownParser.to_bbcode_color(ColorMarkdown.blockquote_bar_color)) == 2)
	assert(bbcode.count("[/cell]") == 4)
	assert("[color=" + MarkdownParser.to_bbcode_color(ColorMarkdown.blockquote_text_color) + "]" in bbcode)
	assert("[/table][/indent]" in bbcode)
	assert("[bgcolor=" not in bbcode)
	assert("line one" in bbcode and "line two" in bbcode)
	pass


func blockquote_single_line_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("> 快乐韭菜网使用的 chatgpt 3.5 模型").bbcode
	assert("[indent]" in bbcode)
	assert("[table=2]" in bbcode)
	assert("bg=" + MarkdownParser.to_bbcode_color(ColorMarkdown.blockquote_bar_color) in bbcode)
	assert("快乐韭菜网" in bbcode)
	pass


func github_admonition_test() -> void:
	var cases := {
		"NOTE": ["ℹ", ColorBase.info],
		"WARNING": ["⚠", ColorBase.warning],
		"TIP": ["✓", ColorBase.success],
		"IMPORTANT": ["ℹ", ColorBase.purple],
		"CAUTION": ["✕", ColorBase.error],
	}
	for kind: String in cases:
		var bbcode := MarkdownParser.to_bbcode("> [!%s]\n> **body**" % kind).bbcode
		var expectation: Array = cases[kind]
		assert(kind.capitalize() in bbcode)
		assert("[b]body[/b]" in bbcode)
		assert("bg=" + MarkdownParser.to_bbcode_color(expectation[1]) in bbcode)
	assert("[!NOTE]" not in MarkdownParser.to_bbcode("> [!NOTE]\n> body").bbcode)
	pass


func horizontal_rule_test() -> void:
	assert(MarkdownParser.is_horizontal_rule_line("---"))
	assert(MarkdownParser.is_horizontal_rule_line("- - -"))
	assert(not MarkdownParser.is_horizontal_rule_line("-_*-"))
	var bbcode := MarkdownParser.to_bbcode("---").bbcode
	assert(MarkdownParser.format_horizontal_rule_line() in bbcode)
	assert("#" in MarkdownParser.format_horizontal_rule_line())
	pass


func snake_case_underscore_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("my_var_name stays plain")
	assert("[i]" not in bbcode)
	assert("my_var_name" in bbcode)
	pass


func bold_italic_triple_asterisk_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("***both***")
	assert("[b][i]both[/i][/b]" in bbcode)
	pass


func bold_does_not_add_font_size_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("**bold**")
	assert(bbcode == "[b]bold[/b]")
	pass


func blank_lines_preserved_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("para one\n\npara two").bbcode
	assert(bbcode == "para one\n\npara two")
	pass


func code_fence_blank_lines_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("```\nline1\n\nline2\n```").bbcode
	assert("[table=1]" in bbcode)
	assert("[/table]" in bbcode)
	assert("[cell shrink=false expand=1 bg=" in bbcode)
	assert("bg=" in bbcode)
	assert("[code]" in bbcode)
	assert("line1" in bbcode and "line2" in bbcode)
	pass


func code_fence_language_title_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("```gdscript\nvar answer := 42\n```").bbcode
	assert("⌨ gdscript" in bbcode)
	assert("[color=" + MarkdownParser.to_bbcode_color(ColorBase.teal) in bbcode)
	assert("[b]⌨ gdscript[/b]" not in bbcode)
	assert("[code]var" in bbcode)
	var plain_bbcode := MarkdownParser.to_bbcode("```\nplain\n```").bbcode
	assert("⌨" not in plain_bbcode)
	pass


## The fence fill follows the theme accent instead of a hex the caller passes in.
func code_block_bg_themed_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("```\nx\n```").bbcode
	assert("bg=" + MarkdownParser.to_bbcode_color(ColorMarkdown.code_block_bg) in bbcode)
	pass


func code_fence_right_gutter_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("```\nx\n```").bbcode
	assert(bbcode.begins_with("[table=1][cell padding=" + MarkdownParser.CODE_BLOCK_RIGHT_GUTTER + "]"))
	assert(bbcode.ends_with("[/cell][/table]"))
	pass


func inline_code_tinted_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("`x`")
	assert(bbcode.begins_with(MarkdownParser.INLINE_CODE_MARGIN))
	assert(bbcode.ends_with(MarkdownParser.INLINE_CODE_MARGIN))
	assert("[bgcolor=" + MarkdownParser.to_bbcode_color(ColorMarkdown.inline_code_bg) + "]" in bbcode)
	assert("[code]x[/code]" in bbcode)
	assert("[table=" not in bbcode)
	pass


## The engine's default 3px highlight padding paints the chip over the line above and
## below it, so the box is pinned to the glyphs instead.
func inline_code_box_padding_test() -> void:
	var label := MarkdownHelper.create_rich_text_label(Color.WHITE, "`x`", true)
	assert(label.get_theme_constant("text_highlight_v_padding") == MarkdownHelper.HIGHLIGHT_V_PADDING)
	assert(label.get_theme_constant("text_highlight_h_padding") == MarkdownHelper.HIGHLIGHT_H_PADDING)
	assert(label.get_theme_constant("table_h_separation") == MarkdownHelper.TABLE_H_SEPARATION)
	label.free()
	pass


## A highlight over a bubble follows the theme color ([ThemeColor]) instead of the
## engine's default tint, and both label kinds share it.
func selection_theme_test() -> void:
	var labels: Array[RichTextLabel] = [
		MarkdownHelper.create_rich_text_label(Color.WHITE, "select me", true),
		MarkdownHelper.create_plain_rich_text_label(Color.WHITE),
	]
	for label: RichTextLabel in labels:
		assert(label.get_theme_color("selection_color") == ThemeColor.selection_color)
		assert(label.get_theme_color("font_selected_color") == ThemeColor.title_color)
		label.free()
	pass


func html_underline_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("<u>图生图</u>, plain")
	assert(bbcode == "[u]图生图[/u], plain")
	assert("<u>" not in bbcode)
	pass


func brackets_escaped_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("array[0]")
	assert(bbcode == "array[lb]0[rb]")
	assert("[lb[rb]" not in bbcode)
	pass


func inline_code_protects_markdown_test() -> void:
	var link_in_code := MarkdownParser.inline_to_bbcode("`[text](url)`")
	assert("[code]" in link_in_code)
	assert("[url=" not in link_in_code)
	assert("[lb]text[rb](url)" in link_in_code)

	var bold_in_code := MarkdownParser.inline_to_bbcode("`**x**`")
	assert("[code]" in bold_in_code)
	assert("[b]" not in bold_in_code)
	assert("**x**" in bold_in_code)
	pass


func dunder_not_bold_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("call __init__ now")
	assert("__init__" in bbcode)
	assert("[b]" not in bbcode)
	assert("[i]" not in bbcode)
	pass


func nested_emphasis_test() -> void:
	var bold_italic := MarkdownParser.inline_to_bbcode("**foo *bar* baz**")
	assert(bold_italic == "[b]foo [i]bar[/i] baz[/b]")
	var italic_bold := MarkdownParser.inline_to_bbcode("*foo **bar** baz*")
	assert(italic_bold == "[i]foo [b]bar[/b] baz[/i]")
	pass


func link_title_stripped_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("[hi](https://a.com \"t\")")
	assert("[url=https://a.com]" in bbcode)
	assert("[url]hi[/url]" not in bbcode)
	assert("hi" in bbcode)
	assert("\"t\"" not in bbcode)
	pass


func url_with_parens_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("[w](https://en.wikipedia.org/wiki/Foo_(bar))")
	assert("Foo_(bar)" in bbcode)
	assert("[url=https://en.wikipedia.org/wiki/Foo_(bar)]" in bbcode)
	pass


func link_label_blue_test() -> void:
	var bbcode := MarkdownParser.inline_to_bbcode("[hi](https://a.com)")
	assert("🔗 " in bbcode)
	assert("[color=%s]🔗 [/color]" % MarkdownParser.to_bbcode_color(ColorBase.info) in bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorMarkdown.link_color) in bbcode)
	var bold_label := MarkdownParser.inline_to_bbcode("[**hi**](https://a.com)")
	assert("[b]hi[/b]" in bold_label)
	assert("[/color][/url]" in bold_label)
	pass


func crlf_normalized_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("# Title\r\n\r\n**bold**").bbcode
	assert("[font_size=32]" in bbcode)
	assert("[b]bold[/b]" in bbcode)
	assert("\r" not in bbcode)
	pass


func tilde_fence_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("~~~\ncode\n~~~").bbcode
	assert("[code]" in bbcode)
	assert("code" in bbcode)
	pass


func heading_trailing_hashes_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("# Title ##").bbcode
	assert("[font_size=32]" in bbcode)
	assert("Title" in bbcode)
	assert("##" not in bbcode)
	pass


func indented_heading_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("  # Title").bbcode
	assert("[font_size=32]" in bbcode)
	assert("Title" in bbcode)
	pass


func ordered_paren_list_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("1) first").bbcode
	assert("1. first" in bbcode)
	pass


func literal_bbcode_tag_escaped_test() -> void:
	assert(MarkdownParser.inline_to_bbcode("press [b] to bold") == "press [lb]b[rb] to bold")
	assert(MarkdownParser.inline_to_bbcode("the [/code] tag") == "the [lb]/code[rb] tag")
	assert(MarkdownParser.inline_to_bbcode("[lb]") == "[lb]lb[rb]")
	assert(
			MarkdownParser.inline_to_bbcode("[url=https://a.com]x[/url]")
			== "[lb]url=https://a.com[rb]x[lb]/url[rb]"
	)
	pass


func brackets_inside_emphasis_escaped_test() -> void:
	assert(MarkdownParser.inline_to_bbcode("**a[0]b**") == "[b]a[lb]0[rb]b[/b]")
	assert(MarkdownParser.inline_to_bbcode("**[b]**") == "[b][lb]b[rb][/b]")
	assert(MarkdownParser.inline_to_bbcode("*[i]*") == "[i][lb]i[rb][/i]")
	pass


func literal_tag_in_block_escaped_test() -> void:
	assert(MarkdownParser.to_bbcode("- use [i] for italic").bbcode == "• use [lb]i[rb] for italic")
	assert("[lb]center[rb]" in MarkdownParser.to_bbcode("# [center] title").bbcode)
	pass


func image_metadata_test() -> void:
	var result := MarkdownParser.to_bbcode("before ![Landscape](https://example.com/image.png) after")
	assert(result.bbcode == "before [img]https://example.com/image.png[/img] after")
	assert(result.images.size() == 1)
	assert(result.images[0].alt_text == "Landscape")
	assert(result.images[0].image_url == "https://example.com/image.png")
	var code_result := MarkdownParser.to_bbcode("```\n![not an image](https://example.com/code.png)\n```")
	assert(code_result.images.is_empty())
	pass


func local_markdown_image_test() -> void:
	var label := MarkdownHelper.create_rich_text_label(
			Color.WHITE,
			"before ![Girl](res://.ai/test/image/girl.png) after",
			true
	)
	assert("before" in label.get_parsed_text())
	assert("after" in label.get_parsed_text())
	label.free()
	pass


func dropped_file_markdown_test() -> void:
	assert(MarkdownHelper.format_file_as_markdown("C:\\My Files\\notes.md") == "[notes.md](<C:/My Files/notes.md>)")
	assert(MarkdownHelper.format_file_as_markdown("C:\\My Files\\voice.WAV") == "[voice.WAV](<C:/My Files/voice.WAV>)")
	assert(MarkdownHelper.format_file_as_markdown("C:\\My Files\\photo.png") == "![photo.png](<C:/My Files/photo.png>)")
	assert(MarkdownHelper.format_file_as_markdown("C:\\My Files\\demo.MP4") == "![demo.MP4](<C:/My Files/demo.MP4>)")
	pass


func local_file_link_prefix_test() -> void:
	var folder_path := ProjectSettings.globalize_path("res://zfoo/markdown").replace("\\", "/")
	var file_bbcode := MarkdownParser.inline_to_bbcode(MarkdownHelper.format_file_as_markdown("C:\\My Files\\notes.bin"))
	var audio_bbcode := MarkdownParser.inline_to_bbcode(MarkdownHelper.format_file_as_markdown("C:\\My Files\\voice.WAV"))
	var folder_bbcode := MarkdownParser.inline_to_bbcode(MarkdownHelper.format_file_as_markdown(folder_path))
	var config_bbcode := MarkdownParser.inline_to_bbcode("[settings.json](<C:/My Files/settings.json>)")
	var document_bbcode := MarkdownParser.inline_to_bbcode("[README.md](<C:/My Files/README.md>)")
	var website_bbcode := MarkdownParser.inline_to_bbcode("[website](https://example.com/file.txt)")
	var email_bbcode := MarkdownParser.inline_to_bbcode("[email](mailto:user@example.com)")
	assert("📄 " in file_bbcode and "notes.bin" in file_bbcode)
	assert("🎵 " in audio_bbcode and "voice.WAV" in audio_bbcode)
	assert("📁 " in folder_bbcode and "markdown" in folder_bbcode)
	assert("⚙ " in config_bbcode and "settings.json" in config_bbcode)
	assert("📝 " in document_bbcode and "README.md" in document_bbcode)
	assert("🔗 " in website_bbcode and "website" in website_bbcode)
	assert("✉ " in email_bbcode and "email" in email_bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorFile.audio_color) in audio_bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorFile.folder_color) in folder_bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorBase.teal) in config_bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorFile.text_color) in document_bbcode)
	assert("[color=%s]" % MarkdownParser.to_bbcode_color(ColorBase.purple) in email_bbcode)
	pass


func markdown_video_preview_test() -> void:
	assert(VideoHelper.is_video_path("C:/clips/demo.mp4"))
	assert(VideoHelper.is_video_path("C:/clips/demo.WEBM"))
	assert(VideoHelper.is_video_path("https://example.com/demo.mp4?token=1"))
	assert(not VideoHelper.is_video_path("C:/clips/demo.png"))
	var placeholder := VideoHelper.create_placeholder_texture()
	assert(placeholder.get_size() == Vector2(160, 90))
	pass


func remote_image_download_state_test() -> void:
	var label := RichTextLabel.new()
	var image_url := "https://example.com/image.png"
	assert(MarkdownRender.image_download_meta_key(image_url) != MarkdownRender.image_download_meta_key("https://example.com/other.png"))
	assert(not label.has_meta(MarkdownRender.image_download_meta_key(image_url)))
	MarkdownRender.set_image_downloading(label, image_url, true)
	assert(label.has_meta(MarkdownRender.image_download_meta_key(image_url)))
	MarkdownRender.set_image_downloading(label, image_url, false)
	assert(not label.has_meta(MarkdownRender.image_download_meta_key(image_url)))
	label.free()
	pass


func markdown_image_cache_trims_oldest_files_test() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://markdown_cache_trim_test_" + str(randi()))
	assert(DirAccess.make_dir_recursive_absolute(cache_dir) == OK)
	var oldest_path := cache_dir.path_join("oldest.png")
	var middle_path := cache_dir.path_join("middle.png")
	var newest_path := cache_dir.path_join("newest.png")
	for file_path in [oldest_path, middle_path, newest_path]:
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(PackedByteArray([1, 2, 3, 4]))
		file = null
	assert(FileAccess.set_modified_time(oldest_path, 100) == OK)
	assert(FileAccess.set_modified_time(middle_path, 200) == OK)
	assert(FileAccess.set_modified_time(newest_path, 300) == OK)
	MarkdownRender.cleanup_image_cache(cache_dir, 8)
	assert(not FileAccess.file_exists(oldest_path))
	assert(FileAccess.file_exists(middle_path))
	assert(FileAccess.file_exists(newest_path))
	FileUtils.delete_file_or_directory(cache_dir)
	pass


func markdown_image_max_width_test() -> void:
	var image := Image.create_empty(1200, 600, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	assert(MarkdownRender.get_image_display_size(texture) == Vector2i(480, 240))
	var small_image := Image.create_empty(200, 100, false, Image.FORMAT_RGBA8)
	var small_texture := ImageTexture.create_from_image(small_image)
	assert(MarkdownRender.get_image_display_size(small_texture) == Vector2i(200, 100))
	pass


func spaced_markers_stay_plain_test() -> void:
	var stars := MarkdownParser.inline_to_bbcode("3 * 4 * 5")
	assert("[i]" not in stars)
	assert(stars == "3 * 4 * 5")
	var unders := MarkdownParser.inline_to_bbcode("a _ b _ c")
	assert("[i]" not in unders)
	assert(unders == "a _ b _ c")
	pass


func gfm_table_test() -> void:
	var md := "| 时段 | 天气 | 气温 |\n|---|---|---|\n| 12–13时 | 多云 | ~30℃ |\n| 14–16时 | 阴 | 29~30℃ |"
	var bbcode := MarkdownParser.to_bbcode(md).bbcode
	assert("[table=3]" in bbcode)
	assert("[/table]" in bbcode)
	assert("border=" in bbcode)
	assert(bbcode.count("[/cell]") == 9)
	assert("[b]时段[/b]" in bbcode)
	assert("[b]天气[/b]" in bbcode)
	assert("12–13时" in bbcode)
	assert("29~30℃" in bbcode)
	assert("| 时段 |" not in bbcode)
	pass


func table_inline_in_cell_test() -> void:
	var md := "| name | val |\n|---|---|\n| **x** | *y* |"
	var bbcode := MarkdownParser.to_bbcode(md).bbcode
	assert("[b]name[/b]" in bbcode)
	assert("[b]x[/b]" in bbcode)
	assert("[i]y[/i]" in bbcode)
	pass


func pipe_without_separator_stays_plain_test() -> void:
	var bbcode := MarkdownParser.to_bbcode("a | b\nc | d").bbcode
	assert("[table=" not in bbcode)
	assert("a | b" in bbcode)
	pass


## Bubble labels clear their highlight on a press outside them — a click on the
## (non-focusable) chat background never moves focus, so the built-in focus-loss path
## leaves the highlight behind.
func click_outside_clears_selection_test() -> void:
	var host := Control.new()
	host.size = Vector2(400, 400)
	gdf.gdf_node.add_child(host)

	var label := MarkdownHelper.create_rich_text_label(Color.WHITE, "select me", true)
	label.position = Vector2(10, 10)
	label.size = Vector2(200, 60)
	host.add_child(label)

	var viewport := host.get_viewport()
	await viewport.get_tree().process_frame
	assert(not label.is_processing_input())

	send_mouse_press(viewport, Vector2(20, 20))
	label.select_all()
	assert(label.get_selected_text() == "select me")
	assert(label.is_processing_input())

	send_mouse_press(viewport, Vector2(350, 350))
	assert(label.get_selected_text() == StringUtils.EMPTY)
	assert(not label.is_processing_input())

	host.queue_free()
	pass


func send_mouse_press(viewport: Viewport, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		viewport.push_input(event, true)
	pass
