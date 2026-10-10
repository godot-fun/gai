class_name AgentChatInput
extends RefCounted

## Floating chat input with symmetric horizontal clearance and a fixed bottom margin:
## collapse/expand, styling, and send button.

## Expanded panel height when empty or one line (wrap grows upward from bottom).
const EXPANDED_HEIGHT_MIN: float = 88.0
## Cap auto-grow so long paste does not cover most of the chat area.
const EXPANDED_HEIGHT_MAX_RATIO: float = 0.55
## Symmetric side inset: keep the input visually centered and clear of right-aligned actions.
const SIDE_INSET: float = ControlSize.md * 5.0
var input_bar: Control
var input_wrap: PanelContainer
var input_inner: Control
var input_field: TextEdit
var send_button: Button
var queue_panel: PanelContainer
var queue_rows: VBoxContainer
var border_beam: AccentBorderBeamLayer
var file_input: AgentChatInputFile = AgentChatInputFile.new()

var expanded: bool = false
var force_expanded: bool = false
var layout_tween: Tween = null

var tween_start_h: float = 0.0
var tween_target_h: float = 0.0
var tween_start_left: float = 0.0
var tween_target_left: float = 0.0
var tween_bar_size: Vector2 = Vector2.ZERO
var tween_expand_target: bool = false


# ---------------------------------------------------------------------------
# Setup & public API
# ---------------------------------------------------------------------------

func setup(
	p_input_bar: Control,
	p_input_wrap: PanelContainer,
	p_input_inner: Control,
	p_input_field: TextEdit,
	p_send_button: Button
) -> void:
	input_bar = p_input_bar
	input_wrap = p_input_wrap
	input_inner = p_input_inner
	input_field = p_input_field
	send_button = p_send_button
	setup_queue_controls()

	input_wrap.set_anchor(SIDE_LEFT, 0.0)
	input_wrap.set_anchor(SIDE_TOP, 0.0)
	input_wrap.set_anchor(SIDE_RIGHT, 0.0)
	input_wrap.set_anchor(SIDE_BOTTOM, 0.0)

	# Engine updates TextEdit minimum height from wrapped lines; outer wrap reads it in get_wrap_height().
	input_field.scroll_fit_content_height = true

	send_button.pressed.connect(on_input_action_pressed)
	input_field.gui_input.connect(on_field_gui_input)
	input_field.minimum_size_changed.connect(on_field_minimum_size_changed)
	input_field.text_changed.connect(on_field_text_changed)
	input_field.focus_entered.connect(on_field_focus_entered)
	input_field.focus_exited.connect(on_field_focus_exited)
	input_wrap.gui_input.connect(on_wrap_gui_input)
	input_bar.resized.connect(layout_bar)
	input_bar.get_window().window_input.connect(on_global_input)
	file_input.setup(input_bar, input_wrap, input_field, prepare_file_drop, focus_input_field, restore_caret)
	gdf.events.theme_changed.connect(on_ui_theme_changed)
	gdf.events.theme_color_changed.connect(on_ui_theme_changed)
	gdf.events.locale_changed.connect(on_ui_theme_changed)
	AgentEvents.events.session_selected.connect(on_session_selected)
	AgentEvents.events.session_queue_changed.connect(on_session_queue_changed)
	AgentEvents.events.chat_input_prefill.connect(on_chat_input_prefill)
	setup_border_beam()
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.session_stop.connect(on_session_stop)
	apply_theme()
	refresh_from_active_session()
	pass


func setup_queue_controls() -> void:
	queue_panel = PanelContainer.new()
	queue_panel.name = "PendingMessages"
	queue_panel.z_index = 3
	queue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	input_bar.add_child(queue_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_panel.add_child(scroll)
	queue_rows = VBoxContainer.new()
	queue_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_rows.add_theme_constant_override("separation", Margin.ma_1)
	scroll.add_child(queue_rows)
	pass


func on_ui_theme_changed() -> void:
	apply_theme()
	refresh_from_active_session()
	refresh_border_beam()
	pass


func setup_border_beam() -> void:
	input_bar.clip_contents = false
	border_beam = AccentBorderBeamLayer.new()
	border_beam.name = "BorderBeam"
	border_beam.z_index = -1
	input_bar.add_child(border_beam)
	input_bar.move_child(border_beam, 0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		border_beam.set_anchor(side, 0.0)
	send_button.z_index = 2
	send_button.mouse_filter = Control.MOUSE_FILTER_STOP
	layout_border_beam()
	refresh_border_beam()
	pass


func layout_border_beam() -> void:
	if border_beam == null:
		return
	set_border_beam_to_wrap(
		input_wrap.offset_left,
		input_wrap.offset_top,
		input_wrap.offset_right,
		input_wrap.offset_bottom
	)
	pass


func set_border_beam_to_wrap(wrap_left: float, wrap_top: float, wrap_right: float, wrap_bottom: float) -> void:
	var pad: int = Margin.ma_1
	border_beam.offset_left = wrap_left - pad
	border_beam.offset_top = wrap_top - pad
	border_beam.offset_right = wrap_right + pad
	border_beam.offset_bottom = wrap_bottom + pad
	border_beam.sync_shader_uniforms()
	pass


func refresh_border_beam() -> void:
	if border_beam == null:
		return
	border_beam.set_shape(expanded)
	var strength: float = 0.45
	if input_field.has_focus():
		strength = 1.0
	elif expanded:
		strength = 0.72
	border_beam.set_highlight_strength(strength)
	pass


func on_session_selected(_session_id: int, previous_session_id: int) -> void:
	var previous_session := AgentSessionStore.load_session(previous_session_id)
	if previous_session != null:
		previous_session.draft_text = input_field.text
	refresh_from_active_session()
	pass


func on_session_queue_changed(session_id: int) -> void:
	if AgentSessionManager.is_active(session_id):
		refresh_queue()
	pass


func on_agent_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	refresh_from_active_session()
	pass


func on_session_stop(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	refresh_from_active_session()
	pass


## A deleted / reverted bubble hands its body back here so it can be edited and resent.
func on_chat_input_prefill(text: String) -> void:
	if StringUtils.is_blank(text):
		return
	input_field.text = text
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session != null:
		session.draft_text = text
	force_expanded = false
	expand_if_collapsed()
	# Setting .text does not emit text_changed, so ask for the (possibly capped) height by hand.
	relayout_if_height_changed()
	focus_input_field.call_deferred()
	pass


func refresh_from_active_session() -> void:
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	var running: bool = AgentSessionManager.is_running(AgentSessionManager.active_session_id)
	var no_history: bool = session != null and not AgentSessionManager.has_chat_history(session.id)
	input_field.text = session.draft_text if session != null else ""
	refresh_state(running, no_history)
	refresh_queue()
	pass


func apply_theme() -> void:
	AgentChatInputTheme.apply_wrap(input_wrap, expanded)
	AgentChatInputTheme.apply_field(input_field)
	AgentChatInputTheme.apply_send_button(send_button, is_stop_action())
	apply_queue_theme()
	pass


func refresh_state(running: bool, no_history: bool = false) -> void:
	force_expanded = no_history and not running
	AgentChatInputTheme.apply_field(input_field)
	input_field.editable = true
	if force_expanded:
		set_expanded(true, false)
		focus_input_field.call_deferred()
	elif input_field.text.strip_edges().length() > 0 or input_field.has_focus():
		set_expanded(true, false)
	elif can_collapse():
		set_expanded(false, true)
	else:
		layout_bar()
	pass


func get_trimmed_text() -> String:
	return input_field.text.strip_edges()


func clear_text() -> void:
	input_field.text = ""
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session != null:
		session.draft_text = ""
	# Setting .text does not emit text_changed, so re-measure by hand. Deferred: a send collapses
	# right after this, and that tween should still start from the current (capped) height.
	relayout_if_height_changed.call_deferred()
	pass


func refresh_queue() -> void:
	for child in queue_rows.get_children():
		queue_rows.remove_child(child)
		child.queue_free()
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	queue_panel.visible = session != null and not session.pending_messages.is_empty()
	if not queue_panel.visible:
		layout_queue_panel()
		return

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_2)
	var title := Label.new()
	title.text = StringUtils.format(I18n.t("agent.input.queued"), session.pending_messages.size())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", Fonts.semibold())
	title.add_theme_color_override("font_color", ColorBase.secondary_text)
	header.add_child(title)
	if not AgentSessionManager.is_running(session.id):
		var continue_button := Button.new()
		continue_button.text = I18n.t("agent.input.continue_queue")
		continue_button.focus_mode = Control.FOCUS_NONE
		AgentChatInputTheme.apply_queue_continue_button(continue_button)
		continue_button.pressed.connect(AgentSessionManager.try_run_next.bind(session.id))
		header.add_child(continue_button)
	queue_rows.add_child(header)

	for queued: String in session.pending_messages:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Margin.ma_2)
		var label := Label.new()
		label.text = queued.replace(FileUtils.NEWLINE_LF, " ")
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = queued
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", ColorBase.primary_text)
		row.add_child(label)
		var delete_button := Button.new()
		delete_button.tooltip_text = I18n.t("agent.input.delete_queued")
		delete_button.custom_minimum_size = Vector2(ControlSize.sm, ControlSize.sm)
		delete_button.focus_mode = Control.FOCUS_NONE
		AgentChatInputTheme.apply_queue_delete_button(delete_button)
		delete_button.pressed.connect(AgentSessionManager.delete_pending_message.bind(session.id, queued))
		row.add_child(delete_button)
		queue_rows.add_child(row)
	apply_queue_theme()
	layout_queue_panel.call_deferred()
	pass


func apply_queue_theme() -> void:
	# Match the expanded composer surface and rounding, without stacking another floating shadow.
	var style := AgentChatInputTheme.build_wrap_style(true)
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = Margin.ma_3
	style.content_margin_top = Margin.ma_2
	style.content_margin_right = Margin.ma_3
	style.content_margin_bottom = Margin.ma_2
	queue_panel.add_theme_stylebox_override("panel", style)
	pass


func layout_queue_panel() -> void:
	if not queue_panel.visible:
		return
	var width := get_wrap_width(true)
	var content_height := minf(queue_rows.get_combined_minimum_size().y + Margin.ma_4, 220.0)
	var right := input_bar.size.x - SIDE_INSET
	queue_panel.position = Vector2(right - width, input_wrap.offset_top - content_height - Margin.ma_2)
	queue_panel.size = Vector2(width, content_height)
	pass


func collapse_after_send() -> void:
	input_field.release_focus()
	force_expanded = false
	set_expanded(false, true)
	pass


func on_global_input(event: InputEvent) -> void:
	if not expanded or file_input.is_drop_focus_guarded():
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		# Window input coordinates are not guaranteed to use the same canvas transform as
		# Control.global_rect (for example with viewport stretch/scaling). Query the mouse
		# through the control so both values are in canvas coordinates.
		if is_point_inside(input_wrap.get_global_mouse_position()):
			return
		input_field.release_focus()
		try_collapse()
	pass


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func is_stop_action() -> bool:
	return (expanded
		and AgentSessionManager.is_running(AgentSessionManager.active_session_id)
		and get_trimmed_text().is_empty())


func on_input_action_pressed() -> void:
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return
	if is_stop_action():
		AgentSessionManager.request_stop(session.id)
		return
	var text: String = get_trimmed_text()
	if text.is_empty():
		expand_if_collapsed()
		focus_input_field.call_deferred()
		return
	if not AgentChatInputDependencyGuard.ensure_git_installed(session.id):
		return
	if AgentSessionManager.enqueue_message(session.id, text):
		clear_text()
		collapse_after_send()
	pass


## Re-layout when line count changes (typing, paste, delete). Skip during expand tween.
func on_field_minimum_size_changed() -> void:
	relayout_if_height_changed()
	pass


## While the panel is capped the field keeps the stylebox-only minimum height, so
## minimum_size_changed never fires and a big delete (or clear) would never shrink the panel.
func on_field_text_changed() -> void:
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session != null:
		session.draft_text = input_field.text
	AgentChatInputTheme.apply_send_button(send_button, is_stop_action())
	relayout_if_height_changed()
	pass


func relayout_if_height_changed() -> void:
	if not expanded:
		return
	# Let expand/collapse tweens finish; killing here often freezes the panel at ~collapsed height.
	if layout_tween != null:
		return
	if absf(wrap_offset_height() - get_wrap_height(true)) < 1.0:
		return
	layout_bar()
	pass


func on_field_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.is_action_pressed("ui_paste") and file_input.paste_clipboard_files():
			input_field.accept_event()
			input_field.get_viewport().set_input_as_handled()
			return
		var is_enter: bool = key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
		if not is_enter:
			is_enter = key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER
		if not is_enter:
			return
		if key.shift_pressed:
			input_field.insert_text_at_caret(FileUtils.NEWLINE_LF)
			input_field.accept_event()
			input_field.get_viewport().set_input_as_handled()
			return
		on_input_action_pressed()
		input_field.accept_event()
		input_field.get_viewport().set_input_as_handled()
	pass


func prepare_file_drop() -> void:
	if layout_tween != null:
		layout_tween.kill()
		layout_tween = null
	set_expanded(true, false)
	pass


func focus_input_field() -> void:
	if not input_field.editable or not input_field.is_inside_tree():
		return
	input_field.visible = true
	var window: Window = input_field.get_window()
	if window != null:
		window.grab_focus()
	input_field.grab_click_focus()
	if not input_field.has_focus():
		input_field.grab_focus()
	restore_caret()
	pass


func on_field_focus_entered() -> void:
	if not expanded:
		set_expanded(true, true)
	else:
		layout_bar()
	refresh_border_beam()
	restore_caret()
	pass


func on_field_focus_exited() -> void:
	if file_input.is_drop_focus_guarded():
		return
	refresh_border_beam()
	try_collapse.call_deferred()
	pass


func on_wrap_gui_input(event: InputEvent) -> void:
	if expanded:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			expand()
			input_wrap.get_viewport().set_input_as_handled()
	pass


# ---------------------------------------------------------------------------
# Expand / collapse
# ---------------------------------------------------------------------------

func expand_if_collapsed() -> void:
	if not expanded:
		expand()
	pass


func restore_caret() -> void:
	if not input_field.editable:
		return
	AgentChatInputTheme.apply_field(input_field)
	var line: int = maxi(0, input_field.get_line_count() - 1)
	var col: int = input_field.get_line(line).length()
	input_field.set_caret_line(line)
	input_field.set_caret_column(col)
	input_field.queue_redraw()
	pass


func expand() -> void:
	set_expanded(true, true)
	if input_field.editable:
		focus_input_field.call_deferred()
	pass


func try_collapse() -> void:
	if send_button.is_hovered():
		return
	if not can_collapse():
		return
	set_expanded(false, true)
	pass


func can_collapse() -> bool:
	if force_expanded:
		return false
	if input_field.text.strip_edges().length() > 0:
		return false
	return not input_field.has_focus()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func is_point_inside(global_pos: Vector2) -> bool:
	return input_wrap.get_global_rect().has_point(global_pos) or (queue_panel.visible and queue_panel.get_global_rect().has_point(global_pos))


func wrap_offset_height() -> float:
	return input_wrap.offset_bottom - input_wrap.offset_top


func prepare_field_for_expand_measure() -> void:
	input_field.visible = true
	input_field.scroll_fit_content_height = true
	pass


func get_wrap_width(is_expanded: bool) -> float:
	var bar_width: float = maxf(input_bar.size.x, 1.0)
	if not is_expanded:
		# The collapsed control remains a fixed circle, only its right edge moves inward.
		return minf(ControlSize.xl, maxf(1.0, bar_width - SIDE_INSET))
	# Expanded input uses the same inset on both sides, so its horizontal margins stay symmetric.
	return maxf(1.0, bar_width - SIDE_INSET * 2.0)


func get_expanded_height_max() -> float:
	var host: Control = input_bar.get_parent() as Control
	if host == null:
		return EXPANDED_HEIGHT_MIN * 3.0
	return maxf(EXPANDED_HEIGHT_MIN, host.size.y * EXPANDED_HEIGHT_MAX_RATIO)


## Fit-content height of the field. The TextEdit only reports its stylebox-only height while
## scroll_fit_content_height is off, so measure with it temporarily enabled. Two calls in a row
## return the same value, which is what keeps layout_bar() / get_wrap_height() idempotent.
func measure_field_content_height() -> float:
	var was_fit: bool = input_field.scroll_fit_content_height
	if not was_fit:
		input_field.scroll_fit_content_height = true
	var content_h: float = float(input_field.get_minimum_size().y)
	if not was_fit:
		input_field.scroll_fit_content_height = false
	return content_h


## Collapsed: fixed circle. Expanded: follow TextEdit min height, clamped; scroll inside when capped.
## Depends only on the text content, never on the previous fit flag, so repeated calls agree.
func get_wrap_height(is_expanded: bool) -> float:
	if not is_expanded:
		return ControlSize.xl
	# An empty editor is always the compact expanded height. Do not ask TextEdit for its minimum here:
	# during startup/theme changes it can briefly return the allocated viewport height instead of one
	# text line, making the input flash at nearly full-screen height before the next layout pass.
	if input_field.text.is_empty():
		input_field.scroll_fit_content_height = true
		return EXPANDED_HEIGHT_MIN
	# Margin.ma_1 top + bottom on the wrap stylebox is padding, so it is not usable field height.
	var min_inner: float = maxf(0.0, EXPANDED_HEIGHT_MIN - Margin.ma_2)
	var max_inner: float = get_expanded_height_max() - Margin.ma_2
	var content_h: float = measure_field_content_height()
	var at_cap: bool = content_h > max_inner
	# At max height, stop growing the panel and let TextEdit scroll vertically. Fit content must be
	# off there, otherwise the field clamps its own height to the pasted line count and overflows.
	var want_fit: bool = not at_cap
	if input_field.scroll_fit_content_height != want_fit:
		input_field.scroll_fit_content_height = want_fit
	var inner_h: float = minf(maxf(content_h, min_inner), max_inner)
	return maxf(EXPANDED_HEIGHT_MIN, inner_h + Margin.ma_2)


func layout_bar() -> void:
	var bar_size: Vector2 = input_bar.size
	var wrap_w: float = get_wrap_width(expanded)
	var wrap_h: float = get_wrap_height(expanded)
	var wrap_right: float = bar_size.x - SIDE_INSET
	input_wrap.offset_left = wrap_right - wrap_w
	input_wrap.offset_right = wrap_right
	input_wrap.offset_top = bar_size.y - Margin.ma_4 - wrap_h
	input_wrap.offset_bottom = bar_size.y - Margin.ma_4
	input_inner.custom_minimum_size = Vector2(0, maxf(0.0, wrap_h - Margin.ma_2))
	input_field.visible = expanded
	if not expanded:
		input_field.scroll_fit_content_height = true
	input_wrap.tooltip_text = "" if expanded else I18n.t("agent.input.click_to_ask")
	layout_send_button(expanded)
	layout_queue_panel()
	AgentChatInputTheme.apply_wrap(input_wrap, expanded)
	layout_border_beam()
	refresh_border_beam()
	pass


func layout_send_button(is_expanded: bool) -> void:
	send_button.visible = true
	# Control grows towards GROW_DIRECTION_BEGIN when a stylebox/content margin pushes the minimum
	# size past the offsets above, which silently shifts the circle. Grow both ways instead.
	send_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	send_button.grow_vertical = Control.GROW_DIRECTION_BOTH
	var half: float = ControlSize.md * 0.5
	if is_expanded:
		send_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		send_button.offset_left = -ControlSize.md - Margin.ma_2
		send_button.offset_top = -ControlSize.md - Margin.ma_2
		send_button.offset_right = -Margin.ma_2
		send_button.offset_bottom = -Margin.ma_2
	else:
		send_button.set_anchors_preset(Control.PRESET_CENTER)
		send_button.offset_left = -half
		send_button.offset_top = -half
		send_button.offset_right = half
		send_button.offset_bottom = half
	send_button.z_index = 2
	AgentChatInputTheme.apply_send_button(send_button, is_stop_action())
	pass


func set_expanded(is_expanded: bool, animate: bool) -> void:
	if expanded == is_expanded:
		layout_bar()
		return
	expanded = is_expanded
	if is_expanded:
		prepare_field_for_expand_measure()
	else:
		input_field.visible = false
	if not animate or not input_bar.is_inside_tree():
		layout_bar()
		return

	if layout_tween != null:
		layout_tween.kill()
		layout_tween = null
	layout_tween = input_bar.create_tween()
	layout_tween.set_trans(Tween.TRANS_CUBIC)
	layout_tween.set_ease(Tween.EASE_OUT)

	tween_start_h = wrap_offset_height()
	if tween_start_h <= 1.0:
		tween_start_h = get_wrap_height(not is_expanded)
	tween_target_h = get_wrap_height(is_expanded)
	tween_bar_size = input_bar.size
	tween_start_left = input_wrap.offset_left
	var wrap_right: float = tween_bar_size.x - SIDE_INSET
	tween_target_left = wrap_right - get_wrap_width(is_expanded)
	tween_expand_target = is_expanded

	layout_tween.tween_method(apply_input_tween_step, 0.0, 1.0, 0.22)
	layout_tween.finished.connect(on_input_tween_finished, CONNECT_ONE_SHOT)
	pass


func apply_input_tween_step(value: float) -> void:
	var height: float = lerpf(tween_start_h, tween_target_h, value)
	# Keep the right edge fixed throughout the tween; only the left edge and height are animated.
	var wrap_right: float = tween_bar_size.x - SIDE_INSET
	input_wrap.offset_left = lerpf(tween_start_left, tween_target_left, value)
	input_wrap.offset_right = wrap_right
	input_wrap.offset_top = tween_bar_size.y - Margin.ma_4 - height
	input_wrap.offset_bottom = tween_bar_size.y - Margin.ma_4
	input_inner.custom_minimum_size.y = maxf(0.0, height - Margin.ma_2)
	# Bottom-right until tween ends; center preset mid-shrink looks like the button slides left.
	layout_send_button(true)
	if border_beam != null:
		set_border_beam_to_wrap(
			lerpf(tween_start_left, tween_target_left, value),
			tween_bar_size.y - Margin.ma_4 - height,
			wrap_right,
			tween_bar_size.y - Margin.ma_4
		)
		border_beam.set_shape(tween_expand_target)
	pass


func on_input_tween_finished() -> void:
	layout_tween = null
	layout_bar()
	if tween_expand_target:
		sync_expanded_height_after_layout.call_deferred()
	if tween_expand_target and input_field.editable:
		focus_input_field()
	pass


func sync_expanded_height_after_layout() -> void:
	if not expanded:
		return
	prepare_field_for_expand_measure()
	var target_h: float = get_wrap_height(true)
	if absf(wrap_offset_height() - target_h) > 1.0:
		layout_bar()
	pass
