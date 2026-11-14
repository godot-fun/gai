extends Object

## Regression guard for the chat-history jumps behind the user-message and reply shortcuts.
##
## Going back lands on the last match whose bubble has scrolled above the viewport top. A history
## ends with a reply, so reading the viewport top instead skipped one match in two cases: the tail of
## the history parks its reveal on the bottom edge, and a reply taller than the view keeps its tail on
## screen while the user message above it is out of sight.

## Row heights of the fixture history: 0, 2 and 4 are the user messages, a reply follows each.
const ROW_HEIGHTS: Array[float] = [120.0, 320.0, 90.0, 140.0, 90.0, 140.0]
const USER_ROWS: Array[int] = [0, 2, 4]
const REPLY_ROWS: Array[int] = [1, 3, 5]
const VIEWPORT_HEIGHT := 300.0
## Last reply taller than the viewport, so the newest user message ends up off screen at the bottom.
const TALL_REPLY_HEIGHTS: Array[float] = [120.0, 320.0, 90.0, 140.0, 90.0, 900.0]


## Following the stream: the newest match parks on the bottom edge, so it is the current row.
func bottom_keeps_the_newest_match_current_test() -> void:
	var nav := build_history()
	await settled()
	scroll_to_bottom(nav)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 2)
	nav.chat_scroll.queue_free()
	pass


## The short reply after the newest user message still parks its reveal on the bottom edge;
## going back from there lands on the middle match instead of skipping it.
func prev_after_a_clamped_reveal_lands_on_the_previous_match_test() -> void:
	var nav := build_history()
	await settled()
	scroll_to_bottom(nav)
	nav.reveal_entry(4)
	assert(is_equal_approx(nav.chat_scroll.get_v_scroll_bar().value, max_scroll(nav)))
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 2)
	nav.reveal_entry(2)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 0)
	nav.chat_scroll.queue_free()
	pass


func next_walks_forward_one_match_at_a_time_test() -> void:
	var nav := build_history()
	await settled()
	nav.reveal_entry(0)
	assert(nav.find_entry_nav_index(USER_ROWS, 1) == 2)
	nav.reveal_entry(2)
	assert(nav.find_entry_nav_index(USER_ROWS, 1) == 4)
	nav.chat_scroll.queue_free()
	pass


## Fractional bubble heights must not move an entry's parked position off the bar value,
## otherwise the entry just revealed stops counting as the current one.
func fractional_rows_keep_the_revealed_match_current_test() -> void:
	var nav := build_history([120.5, 320.5, 90.5, 140.5, 90.5, 140.5])
	await settled()
	nav.reveal_entry(2)
	assert(nav.find_entry_nav_index(USER_ROWS, 1) == 4)
	nav.reveal_entry(4)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 2)
	nav.chat_scroll.queue_free()
	pass


## A match whose reveal the bar has not reached is still ahead, even with its bubble on screen.
func unreached_match_stays_ahead_test() -> void:
	var nav := build_history()
	await settled()
	nav.chat_scroll.get_v_scroll_bar().value = 200.0
	assert(nav.find_entry_nav_index(USER_ROWS, 1) == 2)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 0)
	nav.chat_scroll.queue_free()
	pass


## A history shorter than the viewport has no scroll range, so every match parks at the top.
func history_that_fits_the_view_counts_every_match_as_reached_test() -> void:
	var nav := build_history([40.0, 40.0, 40.0, 40.0, 40.0])
	await settled()
	assert(max_scroll(nav) <= 0.0)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 2)
	assert(nav.find_entry_nav_index(USER_ROWS, 1) == 4)
	nav.chat_scroll.queue_free()
	pass


## A reply taller than the viewport leaves the newest user message scrolled out of sight above the
## bottom edge; going back from the end of the stream lands on it instead of the one before.
func bottom_below_the_newest_match_lands_on_it_test() -> void:
	var nav := build_history(TALL_REPLY_HEIGHTS)
	await settled()
	scroll_to_bottom(nav)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 4)
	nav.reveal_entry(4)
	assert(nav.find_entry_nav_index(USER_ROWS, -1) == 2)
	nav.chat_scroll.queue_free()
	pass


## The same long reply keeps its own tail on screen at the bottom edge, so the reply being read
## stays current and going back still lands on the reply before it.
func bottom_below_a_tall_reply_keeps_the_previous_reply_test() -> void:
	var nav := build_history(TALL_REPLY_HEIGHTS)
	await settled()
	scroll_to_bottom(nav)
	assert(nav.find_entry_nav_index(REPLY_ROWS, -1) == 3)
	nav.reveal_entry(3)
	assert(nav.find_entry_nav_index(REPLY_ROWS, -1) == 1)
	nav.chat_scroll.queue_free()
	pass


func build_history(row_heights: Array[float] = ROW_HEIGHTS) -> ChatScroll:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(240.0, VIEWPORT_HEIGHT)
	scroll.clip_contents = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scroll)
	var container := MarginContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(container)
	var chat_list := VBoxContainer.new()
	chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_list.add_theme_constant_override("separation", Margin.ma_3)
	container.add_child(chat_list)
	for row_height: float in row_heights:
		var row := Control.new()
		row.custom_minimum_size.y = row_height
		chat_list.add_child(row)
	var nav := ChatScroll.new()
	nav.chat_scroll = scroll
	nav.active_chat_list = chat_list
	return nav


static func max_scroll(nav: ChatScroll) -> float:
	var vbar: VScrollBar = nav.chat_scroll.get_v_scroll_bar()
	return vbar.max_value - vbar.page


static func scroll_to_bottom(nav: ChatScroll) -> void:
	nav.chat_scroll.get_v_scroll_bar().value = max_scroll(nav)
	pass


static func settled() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
	pass
