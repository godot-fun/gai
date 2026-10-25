## Full-session chat search. Lists matching transcript entries and jumps to the selected bubble.
class_name SearchWindow
extends CommonWindow

const MAX_RESULTS := 100
const MAX_SNIPPET_LENGTH := 260
## Typing pause before the scan runs — it walks every entry of every session, so per-keystroke is too heavy.
const SEARCH_DEBOUNCE_MILLIS := 1000
const QUERY_ICON_PATH := "res://agent/asset/image/icon/search.svg"

static var query: String = ""

var query_input: PrefixLineEdit
var status_label: Label
var results_scroll: ScrollContainer
var results_list: VBoxContainer
var debounce_timer: Timer


func _init() -> void:
	super()
	gdf.events.locale_changed.connect(apply_locale)
	build_layout()
	apply_locale()
	pass


func build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Margin.ma_3)
	margin.add_theme_constant_override("margin_right", Margin.ma_3)
	margin.add_theme_constant_override("margin_top", Margin.ma_2)
	margin.add_theme_constant_override("margin_bottom", Margin.ma_3)
	container.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", Margin.ma_2)
	margin.add_child(content)
	query_input = PrefixLineEdit.new()
	query_input.apply_prefix(QUERY_ICON_PATH)
	query_input.line_edit.keep_editing_on_text_submit = true
	query_input.line_edit.text = query
	query_input.line_edit.text_changed.connect(on_query_changed)
	query_input.line_edit.text_submitted.connect(on_query_submitted)
	content.add_child(query_input)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	content.add_child(status_label)
	results_scroll = ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(results_scroll)
	var results_pad := MarginContainer.new()
	results_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_pad.add_theme_constant_override("margin_right", Margin.ma_1)
	results_scroll.add_child(results_pad)
	results_list = VBoxContainer.new()
	results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_list.add_theme_constant_override("separation", Margin.ma_1)
	results_pad.add_child(results_list)
	debounce_timer = Timer.new()
	debounce_timer.one_shot = true
	debounce_timer.wait_time = SEARCH_DEBOUNCE_MILLIS / float(TimeUtils.MILLIS_PER_SECOND)
	debounce_timer.timeout.connect(on_debounce_timeout)
	add_child(debounce_timer)
	pass


func apply_theme() -> void:
	super()
	style_content()
	status_label.add_theme_color_override("font_color", Colors.secondary_text)
	style_results_scroll()
	query_input.apply_theme_style()
	pass


## Match [AgentSettingDialog]: [CommonWindow] paints the frame; [member container] is the inset reading surface.
func style_content() -> void:
	container.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface))
	pass


func dismiss_on_focus_out() -> bool:
	return false

func style_results_scroll() -> void:
	results_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ScrollBarStyle.apply_custom(results_scroll.get_v_scroll_bar(), ScrollBarStyle.thickness_md, ThemeColor.body_color,
		ThemeColor.promote(ThemeColor.theme_color, Colors.am_8), ThemeColor.promote(ThemeColor.theme_color, Colors.am_4), true)
	for child: Node in results_list.get_children():
		if child is Button:
			style_result_button(child as Button)
	pass


func style_result_button(result: Button) -> void:
	result.text = ""
	ButtonStyle.apply_font_colors(result, Colors.primary_text, Colors.primary_text, Colors.primary_text, Colors.secondary_text)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1,
		Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ThemeColor.selected_surface
	hover.border_color = ThemeColor.accent_theme_color()
	ButtonStyle.apply(result, normal, hover, hover.duplicate(), normal.duplicate(), normal.duplicate())
	style_result_labels(result)
	pass


func style_result_labels(result: Button) -> void:
	var title_label := result.get_node_or_null("ResultText/Title") as Label
	var snippet_label := result.get_node_or_null("ResultText/Snippet") as Label
	if title_label != null:
		title_label.add_theme_font_override("font", Fonts.regular())
		title_label.add_theme_font_size_override("font_size", Typography.title_medium_size)
		title_label.add_theme_color_override("font_color", Colors.primary_text)
	if snippet_label != null:
		snippet_label.add_theme_font_override("font", Fonts.light())
		snippet_label.add_theme_font_size_override("font_size", Typography.label_large_size)
		snippet_label.add_theme_color_override("font_color", Colors.secondary_text)
	pass


func apply_locale() -> void:
	title = I18n.t("agent.search.title")
	query_input.line_edit.placeholder_text = I18n.t("agent.search.placeholder")
	if not query_input.line_edit.editable:
		status_label.text = I18n.t("agent.search.loading")
	elif StringUtils.is_blank(query_input.line_edit.text):
		status_label.text = I18n.t("agent.search.hint")
	apply_theme()
	pass


## Restarts the pause on every keystroke, so a typing burst costs one scan instead of one per character.
func on_query_changed(raw_query: String) -> void:
	query = raw_query
	if StringUtils.is_blank(raw_query):
		debounce_timer.stop()
		search(raw_query)
		return
	debounce_timer.start()
	pass


func on_query_submitted(raw_query: String) -> void:
	debounce_timer.stop()
	search(raw_query)
	pass


func on_debounce_timeout() -> void:
	search(query_input.line_edit.text)
	pass


func search(raw_query: String) -> void:
	var needle := raw_query.strip_edges().to_lower()
	if needle.is_empty():
		clear_results()
		status_label.text = I18n.t("agent.search.hint")
		return
	var session_indexes := AgentSessionManager.session_indexes
	if session_indexes.size() == 0:
		clear_results()
		status_label.text = I18n.t("agent.search.empty")
		return
	var session_ids := session_indexes.collect_session_ids()
	var active_index := session_ids.find(AgentSessionManager.active_session_id)
	if active_index > 0:
		var active_session_id: int = session_ids[active_index]
		session_ids.remove_at(active_index)
		session_ids.push_front(active_session_id)
	var restore_query_focus := query_input.line_edit.has_focus()
	query_input.line_edit.editable = false
	status_label.text = I18n.t("agent.search.loading")
	await AgentSessionStore.async_load_sessions()
	query_input.line_edit.editable = true
	if restore_query_focus and visible:
		query_input.line_edit.grab_focus()
	clear_results()
	var match_count := 0
	for session_id: int in session_ids:
		if match_count >= MAX_RESULTS:
			break
		var session := AgentSessionStore.load_session(session_id)
		if session == null:
			continue
		for entry_index: int in session.chat_entries.size():
			var entry: ChatEntry = session.chat_entries[entry_index]
			if needle not in entry.body.to_lower():
				continue
			append_result(session.id, entry_index, entry, needle)
			match_count += 1
			if match_count >= MAX_RESULTS:
				break
	var result_key := "agent.search.limited_results" if match_count >= MAX_RESULTS else "agent.search.results"
	status_label.text = StringUtils.format(I18n.t(result_key), match_count)
	pass


func append_result(session_id: int, entry_index: int, entry: ChatEntry, needle: String) -> void:
	var result := Button.new()
	result.custom_minimum_size = Vector2(0, ControlSize.xl)
	var column := VBoxContainer.new()
	column.name = "ResultText"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Margin.ma_0)
	result.add_child(column)
	var title_label := Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.text = StringUtils.format("{}  -  {}", AgentSessionManager.get_title(session_id), entry.title)
	column.add_child(title_label)
	var snippet_label := Label.new()
	snippet_label.name = "Snippet"
	snippet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	snippet_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	snippet_label.text = make_snippet(entry.body, needle)
	column.add_child(snippet_label)
	style_result_button(result)
	result.pressed.connect(on_result_pressed.bind(session_id, entry_index))
	results_list.add_child(result)
	pass


func make_snippet(body: String, needle: String) -> String:
	var one_line := body.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	var match_index := one_line.to_lower().find(needle)
	var start := maxi(0, match_index - 48)
	return one_line.substr(start, MAX_SNIPPET_LENGTH)


func on_result_pressed(session_id: int, entry_index: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		AgentSessionManager.select_session(session_id)
	AgentEvents.events.chat_search_result_selected.emit(session_id, entry_index)
	pass


func clear_results() -> void:
	for child: Node in results_list.get_children():
		child.queue_free()
	pass


####################################################################################################
# Static methods



static func show_search() -> void:
	close_open_windows()
	var window := SearchWindow.new()
	gdf.gdf_node.add_child(window)
	window.present_right(50, 70)
	window.query_input.focus_at_end.call_deferred()
	if StringUtils.is_not_blank(window.query_input.line_edit.text):
		window.debounce_timer.stop()
		window.search(window.query_input.line_edit.text)
	pass


static func close_open_windows() -> void:
	var open: Array[SearchWindow] = []
	for child in gdf.gdf_node.get_children():
		if child is SearchWindow:
			open.push_back(child)
	for window in open:
		window.on_close_requested()
	pass
