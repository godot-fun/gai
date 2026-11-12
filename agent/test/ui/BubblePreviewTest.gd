extends Object

## Regression guard for the truncated chat-bubble preview.
##
## The preview window must be exactly [constant PREVIEW_LINES] rendered lines and stay
## pinned to the tail of the streamed text. Sizing it from the font's line box instead of
## the rendered line offsets left the window a few pixels short, which cut the first and
## the last visible line while a reply was still arriving.

const PREVIEW_LINES := 3

const LINE := "The default parameter values of glob.bind(a, b, true, 0.0, false, 64) pass every argument explicitly, so the merge path stays explicit and should be fine."


func preview_window_shows_the_tail_test() -> void:
	var host := add_host()
	await settled()
	var markdown_label := MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	markdown_label.text = LINE
	host.add_child(markdown_label)
	await settled()

	BubblePreview.apply_height_limit(markdown_label, true, PREVIEW_LINES)
	await settled()
	assert_window(markdown_label)
	host.queue_free()
	pass


## Streams a reply into a real bubble: every refresh has to keep the window on the tail.
func streaming_preview_tracks_the_tail_test() -> void:
	var host := add_host()
	await settled()
	var entry := ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, "%s\n%s\n%s" % [LINE, LINE, LINE])
	var bubble := ThinkingBubble.new()
	bubble.apply(1, entry)
	host.add_child(bubble)
	await settled()

	for i in 6:
		entry.body += "\n" + LINE
		bubble.refresh(entry)
		await settled()
		assert_window(bubble.markdown_label)
	host.queue_free()
	pass


## Bubble kinds are built by the factory before they enter the tree, so the first apply
## cannot measure the text and has to size the window once the label has a layout.
func loaded_entry_sizes_its_window_test() -> void:
	var host := add_host()
	await settled()
	var entry := ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, "%s\n%s\n%s\n%s\n%s" % [LINE, LINE, LINE, LINE, LINE])
	var bubble := ThinkingBubble.new()
	bubble.apply(1, entry)
	host.add_child(bubble)
	await settled()

	assert(not bubble.markdown_label.fit_content)
	assert_window(bubble.markdown_label)
	host.queue_free()
	pass


## Re-wrapping at another width keeps the label's own scroll following on the tail.
func narrower_column_keeps_the_tail_test() -> void:
	var host := add_host()
	await settled()
	var markdown_label := MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	markdown_label.text = "%s\n%s\n%s" % [LINE, LINE, LINE]
	host.add_child(markdown_label)
	await settled()
	BubblePreview.apply_height_limit(markdown_label, true, PREVIEW_LINES)
	await settled()
	var wide_line_count := markdown_label.get_line_count()

	host.size.x = 180.0
	await settled()
	assert(markdown_label.get_line_count() > wide_line_count)
	assert_window(markdown_label)
	host.queue_free()
	pass


func short_preview_releases_the_limit_test() -> void:
	var markdown_label := MarkdownHelper.create_plain_rich_text_label(Colors.secondary_text)
	markdown_label.fit_content = false
	markdown_label.scroll_active = true
	markdown_label.custom_minimum_size.y = 40.0

	BubblePreview.apply_height_limit(markdown_label, false, PREVIEW_LINES)
	assert(markdown_label.fit_content)
	assert(not markdown_label.scroll_active)
	assert(markdown_label.custom_minimum_size.y == 0.0)
	markdown_label.free()
	pass


static func add_host() -> Control:
	var host := VBoxContainer.new()
	host.size = Vector2(260.0, 0.0)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(host)
	return host


static func settled() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
	pass


## Exactly [constant PREVIEW_LINES] rendered lines, scrolled to the end of the text, and
## starting on a line boundary so neither the first nor the last line is partly cut.
static func assert_window(markdown_label: MarkdownRichTextLabel) -> void:
	var line_height := markdown_label.get_line_offset(1) - markdown_label.get_line_offset(0)
	var scroll := markdown_label.get_v_scroll_bar().value
	assert(markdown_label.get_line_count() > PREVIEW_LINES)
	assert(is_equal_approx(markdown_label.custom_minimum_size.y, line_height * PREVIEW_LINES))
	assert(is_equal_approx(markdown_label.size.y, line_height * PREVIEW_LINES))
	assert(is_equal_approx(scroll, markdown_label.get_content_height() - markdown_label.size.y))
	assert(is_equal_approx(fmod(scroll, line_height), 0.0))
	pass
