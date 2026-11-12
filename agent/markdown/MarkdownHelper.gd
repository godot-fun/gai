class_name MarkdownHelper
extends Object

## RichTextLabel construction and interaction helpers for rendered Markdown bodies.
##
## TODO
## ----
## Transient substring highlight (e.g. chat search jump). Godot 4.6 stable only exposes
## [method RichTextLabel.select_all] and [method RichTextLabel.deselect] — no range
## [code]select(from, to)[/code]. Wait for engine PR godotengine/godot#84715 (proposal
## godotengine/godot-proposals#5517), then add:
##
## - [code]highlight_matching_text(markdown_label: MarkdownRichTextLabel, needle: String) -> void[/code]
##   Case-insensitive match in [method RichTextLabel.get_parsed_text]; highlight every
##   non-overlapping occurrence (or first only — pick one). Uses [method apply_selection_theme]
##   colors via [method RichTextLabel.select] / [method RichTextLabel.deselect] after
##   a short hold (~2s), not BBCode [bgcolor].
## - [code]select_parsed_range(markdown_label: MarkdownRichTextLabel, start: int, end: int) -> void[/code]
##   Map parsed-text indices to engine selection (exact API TBD when #84715 merges).
## - [code]find_all_match_starts(text: String, needle: String) -> Array[int][/code]
##   Shared index scan for [method highlight_matching_text].
##
## Call site: extend [code]BubbleContainer.flash_highlight(search_needle)[/code] →
## [code]flash_search_needle(needle)[/code] → [method highlight_matching_text] (from
## [code]ChatScroll.reveal_entry[/code] when [code]chat_search_result_selected[/code] carries
## the query).

# ---------------------------------------------------------------------------
# RichTextLabel body (markdown UI)
# ---------------------------------------------------------------------------

const TABLE_H_SEPARATION := 0
const TABLE_V_SEPARATION := 0
# Inline chip box (`[bgcolor]`): RichTextLabel draws it `line_height + 2 * padding` tall
# (`_draw_line`), so the engine default of 3 spills 3px over the line above and below and
# paints on their text. 0 already fits the line box; the negative value hugs the glyphs so
# the box reads as a chip instead of a full-height row. Padding is plain arithmetic in the
# draw code, and a future clamp to 0 would only make the box line-height again.


## Formats a local file path for display in Markdown. Images and video thumbnails render inline;
## other files are links.
static func format_file_as_markdown(path: String) -> String:
	var normalized_path := path.replace("\\", "/")
	var file_name := normalized_path.get_file().replace("[", "(").replace("]", ")")
	var link := StringUtils.format("[{}](<{}>)", file_name, normalized_path)
	var extension := normalized_path.get_extension().to_lower()
	if ImageHelper.EXTENSIONS.has(extension) or VideoHelper.is_video_path(normalized_path):
		return "!" + link
	return link


## Highlight colors of a selectable body: the card palette's accent-tinted selection plus its
## primary text for the highlighted glyphs. Both come from [ThemeColor], so a bubble keeps
## readable contrast in either theme and re-tints when the user picks another accent color.
static func apply_selection_theme(markdown_label: MarkdownRichTextLabel) -> void:
	markdown_label.add_theme_color_override("selection_color", ThemeColor.selection_color)
	markdown_label.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	pass


## Reapplies the live typography tokens after the user changes the interface scale.
static func apply_typography(markdown_label: MarkdownRichTextLabel) -> void:
	markdown_label.add_theme_font_size_override("normal_font_size", Typography.body_large)
	markdown_label.add_theme_font_size_override("bold_font_size", Typography.body_large)
	markdown_label.add_theme_font_size_override("italics_font_size", Typography.body_large)
	markdown_label.add_theme_font_size_override("bold_italics_font_size", Typography.body_large)
	markdown_label.add_theme_font_size_override("mono_font_size", Typography.body_large)
	pass


static func create_rich_text_label(text_color: Color, raw_text: String, markdown_enabled: bool) -> MarkdownRichTextLabel:
	var markdown_label := MarkdownRichTextLabel.new()
	markdown_label.scroll_active = false
	markdown_label.fit_content = true
	markdown_label.clip_contents = false
	markdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	markdown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	markdown_label.add_theme_color_override("default_color", text_color)
	apply_selection_theme(markdown_label)
	markdown_label.add_theme_font_override("normal_font", Fonts.regular())
	markdown_label.add_theme_font_override("bold_font", Fonts.bold())
	markdown_label.add_theme_font_override("italics_font", Fonts.regular())
	markdown_label.add_theme_font_override("bold_italics_font", Fonts.bold())
	markdown_label.add_theme_font_override("mono_font", Fonts.code())
	apply_typography(markdown_label)
	markdown_label.add_theme_constant_override("table_h_separation", TABLE_H_SEPARATION)
	markdown_label.add_theme_constant_override("table_v_separation", TABLE_V_SEPARATION)
	markdown_label.add_theme_constant_override("text_highlight_h_padding", ControlSize.border_md)
	markdown_label.add_theme_constant_override("text_highlight_v_padding", -ControlSize.border_md)
	markdown_label.custom_minimum_size = Vector2(0, ControlSize.icon_lg)
	# RichTextLabel copies what it draws, so a selection carries `[code]` NBSPs and
	# inline-chip thin margins; restore the source characters before copying.
	markdown_label.gui_input.connect(
			func(event: InputEvent) -> void:
				if not event.is_action_pressed("ui_copy"):
					return
				markdown_label.accept_event()
				copy_to_clipboard(markdown_label.get_selected_text())
	)
	markdown_label.meta_clicked.connect(handle_meta_clicked.bind(markdown_label))
	update_rich_text_label_text(markdown_label, raw_text, markdown_enabled)
	return markdown_label


## Bare selectable label for plain-text bodies (thinking / result previews) — no markdown
## pass, same click-outside deselect as [method create_rich_text_label].
static func create_plain_rich_text_label(text_color: Color) -> MarkdownRichTextLabel:
	var markdown_label := MarkdownRichTextLabel.new()
	markdown_label.scroll_active = false
	markdown_label.fit_content = true
	markdown_label.bbcode_enabled = false
	markdown_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	markdown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	markdown_label.add_theme_color_override("default_color", text_color)
	apply_selection_theme(markdown_label)
	markdown_label.add_theme_font_override("normal_font", Fonts.regular())
	apply_typography(markdown_label)
	return markdown_label


## Put [param text] on the clipboard without markdown's rendering-only spacing.
static func copy_to_clipboard(text: String) -> void:
	if StringUtils.is_blank(text):
		return
	DisplayServer.clipboard_set(text.replace(MarkdownParser.NBSP, StringUtils.SPACE).replace(MarkdownParser.INLINE_CODE_MARGIN, StringUtils.EMPTY).strip_edges())
	pass

static func update_rich_text_label_text(markdown_label: MarkdownRichTextLabel, raw_text: String, markdown_enabled: bool) -> void:
	markdown_label.raw_text = raw_text
	if markdown_enabled:
		var parse_result := MarkdownParser.to_bbcode(raw_text)
		# Enabling bbcode re-parses existing text; raw markdown may contain literal
		# `[cell]` / `[table]` (e.g. in backticks) and crash RichTextLabel.
		if parse_result.images.is_empty() and markdown_label.bbcode_enabled:
			markdown_label.text = parse_result.bbcode
		elif parse_result.images.is_empty():
			markdown_label.bbcode_enabled = false
			markdown_label.text = parse_result.bbcode
			markdown_label.bbcode_enabled = true
		else:
			markdown_label.bbcode_enabled = true
			MarkdownRender.render_markdown_with_images(markdown_label, parse_result)
	else:
		if markdown_label.bbcode_enabled:
			markdown_label.bbcode_enabled = false
		markdown_label.text = raw_text
	pass

## Absolute path of the local file a Markdown link points at, or "" when the destination is not a
## local path. Accepts absolute paths ([code]res://[/code] / [code]user://[/code] included),
## [code]file://[/code] URLs, and workspace-relative paths — replies link workspace files without a
## prefix. A GitHub-style [code]#L671[/code] anchor names a line inside the file, not part of the path.
static func resolve_local_link(destination: String) -> String:
	var path := destination.strip_edges()
	var anchor_index := path.find("#")
	if anchor_index > 0:
		path = path.substr(0, anchor_index)
	if path.begins_with("file://"):
		path = path.trim_prefix("file://")
		# `file:///C:/dir/a.md` keeps the slash before the drive letter.
		if path.begins_with("/") and path.length() > 3 and path[2] == ":":
			path = path.substr(1)
	# Any other scheme (`https://…`) reads as an absolute path to the engine, so it must be
	# rejected before the local branches below.
	if path.is_empty() or path.contains("://"):
		return StringUtils.EMPTY
	# An absolute path — `res://` / `user://` included — is local whatever its state, and
	# [method FileUtils.normalize_path] globalizes the resource prefixes; the editor reports a
	# missing file itself. Relative destinations resolve against the workspace root, like every
	# agent tool path, and only count when they exist, so a bare `example.com/page` link still opens
	# in the browser.
	if path.is_absolute_path():
		return FileUtils.normalize_path(path)
	var workspace_path := AgentWorkspace.resolve_path(path)
	if FileUtils.exists(workspace_path):
		return workspace_path
	return StringUtils.EMPTY


# ---------------------------------------------------------------------------
# Link target lookup — file name search + content comparison
# ---------------------------------------------------------------------------

## Markdown characters of the body compared with a candidate file: enough to tell two documents apart.
const BODY_PROBE_LENGTH := 200

## Exact file a Markdown link points at, found by file name and content.
##
## The link names a file (`README_CN.md`; a `#L671` anchor is dropped) and the whole workspace is
## searched for that name, because a README inside a subfolder links its siblings by bare name. Same-named
## candidates are then narrowed by content: the one holding this body's text is the document being
## displayed, so `(README.md)` inside `.memory/README.md` means the file next door. Absolute paths,
## `scheme://`, and workspace-relative paths keep the [method resolve_local_link] rules; "" means the
## click is not a local file and belongs to the browser guess.
static func async_search_link_file(destination: String, markdown_body: MarkdownRichTextLabel) -> String:
	# Dropped files and `res://` links arrive absolute; they need no search at all.
	var path := destination.strip_edges()
	if path.is_absolute_path() or path.contains("://"):
		return resolve_local_link(path)
	var anchor_index := path.find("#")
	if anchor_index > 0:
		path = path.substr(0, anchor_index)
	var file_name := path.get_file()
	if file_name.is_empty() or file_name.get_extension().is_empty():
		return resolve_local_link(destination)
	var matches: Array[String] = await GlobUtils.async_glob(AgentWorkspace.get_root(), "**/" + file_name, true, FileUtils.BYTES_PER_MB, GitIgnore.ignore_rules)
	if matches.size() == 1:
		return matches[0]

	# Same name in several folders: the file holding this very Markdown is the one meant.
	var probe := markdown_body.raw_text.substr(0, BODY_PROBE_LENGTH)
	if not probe.is_empty():
		for match_path in matches:
			if FileUtils.read_file_to_string(match_path).contains(probe):
				return match_path

	# Nothing conclusive: the workspace-root rules, then the first candidate the walk returned.
	var local_path := resolve_local_link(destination)
	if StringUtils.is_not_blank(local_path) or matches.is_empty():
		return local_path
	Log.info("link search is ambiguous file:[{}] candidates:[{}] opening:[{}]", file_name, matches.size(), matches[0])
	return matches[0]


## Opens a clicked Markdown link; [param markdown_body] is the label it came from and is what tells same-named
## files apart. [method create_rich_text_label] binds it, so every rendered body always passes one.
static func handle_meta_clicked(meta: Variant, markdown_body: MarkdownRichTextLabel) -> void:
	var url := str(meta).strip_edges()
	if StringUtils.is_blank(url):
		return
	var lower := url.to_lower()
	if lower.begins_with("javascript:") or lower.begins_with("data:"):
		Log.info("blocked unsafe link:[{}]", url)
		return
	if HttpUtils.is_valid_http_url(url):
		var http_error := OS.shell_open(url)
		if http_error != OK:
			Log.error("open link failed url:[{}] err:[{}]", url, http_error)
		return
	# An existing local path wins over the `https://` guess below: replies link workspace files
	# relative to the workspace root, and that guess sent them to the browser. A bare name from a
	# subfolder is found by searching the workspace and comparing candidates with this very body.
	var local_path := await async_search_link_file(url, markdown_body)
	if StringUtils.is_not_blank(local_path):
		# A folder has nothing to show in the editor, so the OS file manager takes it.
		if DirAccess.dir_exists_absolute(local_path):
			var folder_error := FileUtils.open_file(local_path)
			if folder_error != OK:
				Log.error("open folder failed path:[{}] err:[{}]", local_path, folder_error)
			return
		if ImageHelper.EXTENSIONS.has(local_path.get_extension().to_lower()):
			ImagePreviewWindow.show_window(local_path, I18n.t("common.image_preview"))
			return
		await EditorDiscovery.async_open_file(local_path)
		return
	if not lower.begins_with("http://") and not lower.begins_with("https://") and not lower.begins_with("mailto:"):
		if url.begins_with("//"):
			url = "https:" + url
		elif url.contains(".") and not url.contains(" "):
			url = "https://" + url
		else:
			Log.info("unsupported link:[{}]", url)
			return
	var err := OS.shell_open(url)
	if err != OK:
		Log.error("open link failed url:[{}] err:[{}]", url, err)
	pass
