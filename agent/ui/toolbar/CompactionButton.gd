class_name CompactionButton
extends RefCounted

## Circular toolbar progress for the current context length from the latest LLM request.
##
## Shows [member OpenAiUsage.prompt_tokens] from the last API call (input context size, not session total).
## The ring uses the theme color until [constant THRESHOLD_WARN], then a traffic-light scale
## against [constant MAX_CONTEXT_TOKENS]:
##
## ```
## 50% ── yellow ──► 75% ── orange ──► 90% ── red
## ```

## Reference context window for badge color / percentage. Update when switching to a model with a different limit (e.g. GPT-4o 128k vs DeepSeek V4 1M).
const MAX_CONTEXT_TOKENS: int = 1_000_000
const THRESHOLD_WARN: float = 0.50
const THRESHOLD_CAUTION: float = 0.75
const THRESHOLD_CRITICAL: float = 0.90
const RING_WIDTH: float = 2.0
const RING_INSET: float = 3.0
const SPINNER_ARC: float = PI * 1.35

var wrap: PanelContainer
var label: Label
var usage_ratio: float = 0.0
var usage_color: Color
var compacting: bool = false
var spinner_angle: float = 0.0
var spinner_tween: Tween = null


func setup(p_wrap: PanelContainer) -> void:
	wrap = p_wrap
	label = wrap.get_child(0) as Label
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wrap.custom_minimum_size = ControlSize.square(ControlSize.sm)
	label.custom_minimum_size = ControlSize.square(ControlSize.sm)
	label.text = ""
	label.draw.connect(draw_ring)
	wrap.gui_input.connect(on_gui_input)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	AgentEvents.events.session_selected.connect(refresh)
	AgentEvents.events.message_complete.connect(on_message_complete)
	AgentEvents.events.compaction_start.connect(on_compaction_start)
	AgentEvents.events.compaction_end.connect(on_compaction_end)
	apply_theme()
	pass


func on_message_complete(session_id: int, usage: OpenAiUsage) -> void:
	if session_id == AgentSessionManager.active_session_id:
		refresh_usage(usage)
	pass


func refresh(_session_id: int = 0, _previous_session_id: int = 0) -> void:
	if label == null or wrap == null:
		return
	sync_compaction_state()
	var session: AgentSession = AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return
	refresh_usage(session.usage)
	pass


func refresh_usage(usage: OpenAiUsage) -> void:
	var n: int = usage.prompt_tokens
	usage_ratio = token_ratio(n)
	usage_color = text_color_for_tokens(n)
	wrap.tooltip_text = StringUtils.format(
		I18n.t("agent.tokens.tooltip"),
		n,
		int(round(usage_ratio * 100.0)),
		usage.completion_tokens,
		usage.total_tokens
	)
	if compacting:
		wrap.tooltip_text = I18n.t("agent.tokens.compacting")
	label.queue_redraw()
	pass


func sync_compaction_state() -> void:
	var should_compact := CompactionManager.is_compacting(AgentSessionManager.active_session_id)
	if should_compact == compacting:
		return
	compacting = should_compact
	wrap.mouse_default_cursor_shape = Control.CURSOR_ARROW if compacting else Control.CURSOR_POINTING_HAND
	if compacting:
		start_spinner()
	else:
		stop_spinner()
	pass


func on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	CompactionManager.compact_session(AgentSessionManager.active_session_id)
	wrap.get_viewport().set_input_as_handled()
	pass


func on_compaction_start(session_id: int) -> void:
	if not AgentSessionManager.is_active(session_id):
		return
	compacting = true
	wrap.mouse_default_cursor_shape = Control.CURSOR_ARROW
	wrap.tooltip_text = I18n.t("agent.tokens.compacting")
	start_spinner()
	pass


func on_compaction_end(session_id: int, success: bool, error_code: String) -> void:
	if success:
		Alert.alert(I18n.t("agent.tokens.compact_success"), Colors.success)
	elif error_code == CompactionManager.ERROR_RUNNING:
		Alert.alert(I18n.t("agent.tokens.compact_running"), Colors.warning)
	elif error_code == CompactionManager.ERROR_EMPTY:
		Alert.alert(I18n.t("agent.tokens.compact_empty"), Colors.warning)
	else:
		Alert.alert(I18n.t("agent.tokens.compact_failed"), Colors.error)
	if not AgentSessionManager.is_active(session_id):
		return
	compacting = false
	wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stop_spinner()
	refresh()
	pass


func start_spinner() -> void:
	if spinner_tween != null:
		spinner_tween.kill()
	spinner_angle = 0.0
	spinner_tween = wrap.create_tween().set_loops()
	spinner_tween.tween_method(set_spinner_angle, 0.0, TAU, 0.8)
	pass


func stop_spinner() -> void:
	if spinner_tween != null:
		spinner_tween.kill()
		spinner_tween = null
	spinner_angle = 0.0
	label.queue_redraw()
	pass


func set_spinner_angle(angle: float) -> void:
	spinner_angle = angle
	label.queue_redraw()
	pass


func apply_theme() -> void:
	if label == null:
		return
	var panel := StyleBoxEmpty.new()
	panel.content_margin_right = Margin.ma_2
	wrap.add_theme_stylebox_override("panel", panel)
	refresh()
	label.queue_redraw()
	pass


func draw_ring() -> void:
	var center := label.size * 0.5
	var radius: float = minf(label.size.x, label.size.y) * 0.5 - RING_INSET
	label.draw_arc(center, radius, 0.0, TAU, 48, Colors.control_surface, RING_WIDTH, true)
	if compacting:
		var spinner_color := ThemeColor.accent_theme_color()
		label.draw_arc(center, radius, spinner_angle, spinner_angle + SPINNER_ARC, 32, spinner_color, RING_WIDTH, true)
		return
	if usage_ratio <= 0.0:
		return
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * usage_ratio
	label.draw_arc(center, radius, start_angle, end_angle, maxi(2, int(48.0 * usage_ratio)), usage_color, RING_WIDTH, true)
	var cap_radius: float = RING_WIDTH * 0.5
	label.draw_circle(center + Vector2.UP * radius, cap_radius, usage_color)
	label.draw_circle(center + Vector2(cos(end_angle), sin(end_angle)) * radius, cap_radius, usage_color)
	pass


## Compact badge text: 999 → "999", 1500 → "1.5k", 12000 → "12k", 2M+ → "2M".
static func format_count(n: int) -> String:
	if n >= 1_000_000:
		return StringUtils.format("{}M", n / 1_000_000)
	if n >= 10_000:
		return StringUtils.format("{}k", n / 1000)
	if n >= 1000:
		return StringUtils.format("{}k", snappedf(float(n) / 1000.0, 0.1))
	return str(n)


static func token_ratio(n: int) -> float:
	return clampf(float(n) / float(MAX_CONTEXT_TOKENS), 0.0, 1.0)


static func text_color_for_tokens(n: int) -> Color:
	var ratio: float = token_ratio(n)
	if ratio >= THRESHOLD_CRITICAL:
		return Colors.error
	if ratio >= THRESHOLD_CAUTION:
		return Colors.warning
	if ratio >= THRESHOLD_WARN:
		return Color(0.94, 0.84, 0.35) if ThemeColor.is_dark_theme() else Color("#CA8A04")
	return ThemeColor.accent_theme_color()
