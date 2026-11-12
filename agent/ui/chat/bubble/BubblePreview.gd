class_name BubblePreview
extends Object

## Shared text-preview calculations for chat bubbles.
## Result / Thinking keep the last PREVIEW_LINES, then the last PREVIEW_CHARS of that window.

const PREVIEW_LINES := 6
const PREVIEW_CHARS := 600


static func hidden_line_count(body: String, visible_line_count: int) -> int:
	if StringUtils.is_blank(body):
		return 0
	return maxi(0, body.count(FileUtils.NEWLINE_LF) + 1 - visible_line_count)


static func apply(rich_text: MarkdownRichTextLabel, view_button: Button, line_label: Label, body: String, fixed_height_at_limit: bool = false, preview_lines: int = PREVIEW_LINES) -> void:
	if not is_instance_valid(rich_text):
		return
	var text := StringUtils.last_lines(body, preview_lines)
	if text.length() > PREVIEW_CHARS:
		text = text.substr(text.length() - PREVIEW_CHARS)
	view_button.visible = text != body
	var extra_lines := 0 if StringUtils.is_empty(body) else maxi(0, body.count(FileUtils.NEWLINE_LF) + 1 - preview_lines)
	line_label.visible = extra_lines > 0
	if extra_lines > 0:
		var line_key := "agent.chat.more_line" if extra_lines == 1 else "agent.chat.more_lines"
		line_label.text = StringUtils.format(I18n.t(line_key), extra_lines)
	rich_text.text = text
	rich_text.visible = StringUtils.is_not_blank(body)
	if fixed_height_at_limit:
		apply_height_limit(rich_text, extra_lines > 0, preview_lines)
	pass


## Stay compact for short content; lock the viewport only once preview truncation starts.
static func apply_height_limit(rich_text: MarkdownRichTextLabel, limit_reached: bool, preview_lines: int = PREVIEW_LINES) -> void:
	if not limit_reached:
		rich_text.fit_content = true
		rich_text.scroll_active = false
		rich_text.custom_minimum_size.y = 0.0
		return
	rich_text.fit_content = false
	# The label keeps its own view pinned to the tail while the reply streams in, so the
	# only thing to size here is the window.
	rich_text.scroll_active = true
	rich_text.scroll_following = true
	var scroll_bar := rich_text.get_v_scroll_bar()
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_bar.modulate.a = 0.0
	apply_preview_height(rich_text, preview_lines)
	pass


## Sizes the preview window to [param preview_lines] rendered lines.
##
## The height comes from the rendered line offsets: the font's line box is taller than the
## [RichTextLabel] line, and the extra pixels left a sliver of the line above the window
## visible while the reply was streaming in.
static func apply_preview_height(rich_text: MarkdownRichTextLabel, preview_lines: int) -> void:
	var line_count := rich_text.get_line_count()
	if line_count <= 0:
		# A bubble is built before it enters the tree, so the first call has no text layout
		# to measure; retry once the label is inside the tree.
		if rich_text.is_inside_tree() or StringUtils.is_blank(rich_text.text):
			return
		gdf.callable_deferred(func() -> void:
			if is_instance_valid(rich_text) and not rich_text.fit_content:
				apply_preview_height(rich_text, preview_lines)
		)
		return
	if line_count < 2:
		rich_text.custom_minimum_size.y = rich_text.get_content_height()
		return
	rich_text.custom_minimum_size.y = (rich_text.get_line_offset(1) - rich_text.get_line_offset(0)) * preview_lines
	pass
