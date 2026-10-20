class_name ChatBubblePreview
extends Object

## Shared preview truncation for Result / Thinking bubbles.
## Keep the last PREVIEW_LINES, then the last PREVIEW_CHARS of that window.

const PREVIEW_LINES := 6
const PREVIEW_CHARS := 600


static func preview(s: String) -> String:
	var text := StringUtils.last_lines(s, PREVIEW_LINES)
	if text.length() <= PREVIEW_CHARS:
		return text
	return text.substr(text.length() - PREVIEW_CHARS)


static func extra_line_count(s: String) -> int:
	if StringUtils.is_empty(s):
		return 0
	return maxi(0, s.count(FileUtils.NEWLINE_LF) + 1 - PREVIEW_LINES)


static func apply(rich_text: RichTextLabel, view_button: Button, line_label: Label, body: String, fixed_height_at_limit: bool = false) -> void:
	if not is_instance_valid(rich_text):
		return
	var text := preview(body)
	view_button.visible = text != body
	var extra_lines := extra_line_count(body)
	line_label.visible = extra_lines > 0
	if extra_lines > 0:
		var line_key := "common.more_line" if extra_lines == 1 else "common.more_lines"
		line_label.text = StringUtils.format(I18n.t(line_key), extra_lines)
	rich_text.text = text
	rich_text.visible = StringUtils.is_not_blank(body)
	if fixed_height_at_limit:
		apply_height_limit(rich_text, extra_lines > 0)
	pass


## Stay compact for short content; lock the viewport only once preview truncation starts.
static func apply_height_limit(rich_text: RichTextLabel, limit_reached: bool) -> void:
	if not limit_reached:
		rich_text.fit_content = true
		rich_text.scroll_active = false
		rich_text.custom_minimum_size.y = 0.0
		return
	var font := rich_text.get_theme_font("normal_font")
	var font_size := rich_text.get_theme_font_size("normal_font_size")
	var line_separation := rich_text.get_theme_constant("line_separation")
	var preview_height := ceilf(font.get_height(font_size) * PREVIEW_LINES + line_separation * (PREVIEW_LINES - 1))
	rich_text.fit_content = false
	rich_text.scroll_active = true
	rich_text.scroll_following = true
	rich_text.custom_minimum_size.y = preview_height
	var scroll_bar := rich_text.get_v_scroll_bar()
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_bar.modulate.a = 0.0
	pass
