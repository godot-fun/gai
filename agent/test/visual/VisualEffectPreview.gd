extends Control

## Unified visual-effect preview. Drives [VisualControl] by emitting real [AgentEvents]
## (same sequence as [AgentLoop]), with no direct effect-method calls.
##
## Row 1 — small payload: 16 turns, short user / thinking, each registered tool appears.
## Row 2 — large payload: 64 turns, denser streams and more tool calls per turn.
## Each row has one play button per visual type.
## Optional dual concurrent sessions: two RuntimeManager runtimes, staggered agent_start, interleaved turns.

const SMALL_TURNS := 16
const LARGE_TURNS := 64

const EFFECT_SPECS: Array[Dictionary] = [
	{"type": VisualControl.Type.JARVIS, "label": "Jarvis"},
	{"type": VisualControl.Type.TRANSFORMER, "label": "Transformer"},
	{"type": VisualControl.Type.REASONING_TREE, "label": "Reasoning Tree"},
	{"type": VisualControl.Type.TOOL_CONSTELLATION, "label": "Tool Constellation"},
	{"type": VisualControl.Type.CONTEXT_MEMORY_RIVER, "label": "Context Memory River"},
	{"type": VisualControl.Type.NEURAL_AURORA, "label": "Neural Aurora"},
	{"type": VisualControl.Type.SEMANTIC_BLACK_HOLE, "label": "Semantic Black Hole"},
	{"type": VisualControl.Type.CYBER_COMMAND_DECK, "label": "Cyber Command Deck"},
	{"type": VisualControl.Type.QUANTUM_CIRCUIT, "label": "Quantum Circuit"},
	{"type": VisualControl.Type.DESKTOP_CAT, "label": "Desktop Cat"},
	{"type": VisualControl.Type.GEOMETRIC_GENESIS, "label": "Geometric Genesis"},
	{"type": VisualControl.Type.MATRIX_RAIN, "label": "Matrix Rain"},
	{"type": VisualControl.Type.FILTER_CAROUSEL, "label": "Filter Carousel"},
	{"type": VisualControl.Type.INK_LANDSCAPE, "label": "Ink Landscape"},
	{"type": VisualControl.Type.TAI_CHI, "label": "Tai Chi"},
]

const TOOL_CATALOG: Array[Dictionary] = [
	{"name": ReadTool.NAME, "args": {"path": "res://project.godot"}},
	{"name": WriteTool.NAME, "args": {"path": "res://agent/tmp_preview.gd", "content": "extends Node\n"}},
	{"name": EditTool.NAME, "args": {"path": "res://agent/tmp_preview.gd", "old_string": "extends Node", "new_string": "extends Control"}},
	{"name": BashTool.NAME, "args": {"command": "echo visual-preview"}},
	{"name": GrepTool.NAME, "args": {"pattern": "class_name", "glob": "*.gd"}},
	{"name": GlobTool.NAME, "args": {"pattern": "**/*.tscn"}},
	{"name": ListDirTool.NAME, "args": {"path": "res://agent/ui/visuals", "recursive": false}},
	{"name": DeleteTool.NAME, "args": {"path": "res://agent/tmp_preview.gd"}},
	{"name": ImageToTextTool.NAME, "args": {"path": "res://icon.svg", "prompt": "Describe this icon briefly."}},
	{"name": AudioToTextTool.NAME, "args": {"path": "res://audio/sample.wav"}},
	{"name": WebFetchTool.NAME, "args": {"url": "https://docs.godotengine.org", "max_chars": 2000}},
	{"name": WebSearchTool.NAME, "args": {"query": "godot visual effects"}},
]

@onready var background: ColorRect = $Background
@onready var visual_control: VisualControl = $VisualOverlay/VisualControl
@onready var title_label: Label = $UiLayer/Ui/Title
@onready var hint_label: Label = $UiLayer/Ui/Hint
@onready var status_label: Label = $UiLayer/Ui/Status
@onready var stop_button: Button = $UiLayer/Ui/Controls/Stop
@onready var theme_color_select_node: Button = $UiLayer/Ui/Controls/ThemeColorSelect
@onready var theme_toggle_button: Button = $UiLayer/Ui/Controls/ThemeToggle
@onready var concurrent_sessions_toggle: CheckButton = $UiLayer/Ui/Controls/ConcurrentSessions
@onready var small_row: HBoxContainer = $UiLayer/Ui/SmallRow/Buttons
@onready var large_row: HBoxContainer = $UiLayer/Ui/LargeRow/Buttons
@onready var small_row_label: Label = $UiLayer/Ui/SmallRow/Label
@onready var large_row_label: Label = $UiLayer/Ui/LargeRow/Label

var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select: ThemeColorSelect = ThemeColorSelect.new()

var demo_session_id: int = 1_0000
var demo_session_id_b: int = 0
var demo_generation: int = 0
var demo_running: bool = false
var tool_serial: int = 0
var play_buttons: Array[Button] = []


func _ready() -> void:
	# This preview runs directly with F6 and bypasses Agent._ready(), where the application normally
	# initializes translations. Keep this first so effects created below receive translated labels.
	TransformerController.complete_animation_on_agent_end = true
	TaiChi.complete_animation_on_agent_end = true
	I18nHelper.init_i18n()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AgentSessionManager.load_from_disk()
	demo_session_id = AgentSessionManager.active_session_id
	theme_color_select.setup(theme_color_select_node)
	theme_toggle.setup(theme_toggle_button)
	build_effect_buttons()
	stop_button.pressed.connect(on_stop_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	set_status("Pick an effect row to stream simulated AgentEvents in real time.")
	pass


func _exit_tree() -> void:
	TransformerController.complete_animation_on_agent_end = false
	TaiChi.complete_animation_on_agent_end = false
	pass


func build_effect_buttons() -> void:
	for spec: Dictionary in EFFECT_SPECS:
		var small_button := make_effect_button(str(spec["label"]), int(spec["type"]), SMALL_TURNS, false)
		small_row.add_child(small_button)
		play_buttons.append(small_button)
		var large_button := make_effect_button(str(spec["label"]), int(spec["type"]), LARGE_TURNS, true)
		large_row.add_child(large_button)
		play_buttons.append(large_button)
	pass


func make_effect_button(label: String, visual_type: int, turn_count: int, large: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: start_demo(visual_type as VisualControl.Type, turn_count, large))
	return button


func apply_theme() -> void:
	background.color = Colors.app_background
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	title_label.add_theme_color_override("font_color", Colors.primary_text)
	for label: Label in [hint_label, status_label, small_row_label, large_row_label]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", Colors.secondary_text)
	var buttons: Array[Button] = [stop_button]
	buttons.append_array(play_buttons)
	for button: Button in buttons:
		button.add_theme_font_override("font", Fonts.medium())
		button.add_theme_font_size_override("font_size", Typography.label_large_size)
		var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
		ButtonStyle.apply(button, normal,
			ButtonStyle.filled(normal, ThemeColor.promote(Colors.control_surface, Colors.am_2)),
			ButtonStyle.filled(normal, ThemeColor.demote(Colors.control_surface, Colors.am_2)))
		ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())
	concurrent_sessions_toggle.add_theme_font_override("font", Fonts.medium())
	concurrent_sessions_toggle.add_theme_font_size_override("font_size", Typography.label_large_size)
	ButtonStyle.apply_check_button(concurrent_sessions_toggle, Colors.secondary_text, Colors.primary_text)
	pass


func on_stop_pressed() -> void:
	stop_demo("Stopped.", true)
	pass


func start_demo(visual_type: VisualControl.Type, turn_count: int, large: bool) -> void:
	if demo_running:
		# Cancel the in-flight simulation without agent_end — a follow-up agent_start owns the effect.
		demo_generation += 1
		demo_running = false
		clear_running_sessions(get_demo_session_ids())
		await get_tree().process_frame
	demo_running = true
	demo_generation += 1
	var generation := demo_generation
	select_visual(visual_type)
	await run_agent_events(turn_count, large, generation)
	pass


func select_visual(visual_type: VisualControl.Type) -> void:
	if AgentSetting.get_visual_type() != visual_type:
		AgentSetting.set_visual_type(visual_type as int)
	pass


func stop_demo(status_text: String, as_error: bool = false) -> void:
	demo_generation += 1
	demo_running = false
	var session_ids := get_demo_session_ids()
	clear_running_sessions(session_ids)
	if as_error:
		for session_id: int in session_ids:
			if session_id != 0:
				AgentEvents.events.agent_end.emit(session_id, "Stop.")
	if StringUtils.is_not_blank(status_text):
		set_status(status_text)
	pass


func run_agent_events(turn_count: int, large: bool, generation: int) -> void:
	var session_ids := get_demo_session_ids()
	for session_id: int in session_ids:
		seed_user_prompt_for_session(session_id, large, session_id == demo_session_id_b)
	if not mark_running_sessions(session_ids):
		demo_running = false
		set_status("Cannot start session.")
		return
	var payload_label := "Large payload · %d turns" % turn_count if large else "Small payload · %d turns" % turn_count
	var mode_label := "%s · dual sessions" % payload_label if session_ids.size() > 1 else payload_label
	set_status("%s · %s · started" % [mode_label, visual_label()])
	AgentEvents.events.agent_start.emit(session_ids[0])
	if session_ids.size() > 1:
		if not await wait_step(pace(0.22, 0.12, large), generation):
			return
		AgentEvents.events.agent_start.emit(session_ids[1])
	if not await wait_step(pace(0.35, 0.18, large), generation):
		return

	for turn_index in range(turn_count):
		for session_index in range(session_ids.size()):
			var session_id: int = session_ids[session_index]
			if not await play_turn(session_id, turn_index, turn_count, large, generation, session_index):
				return

	if not await wait_step(pace(0.45, 0.2, large), generation):
		return
	for session_index in range(session_ids.size()):
		var session_id: int = session_ids[session_index]
		if session_index > 0:
			if not await wait_step(pace(0.2, 0.1, large), generation):
				return
		RuntimeManager.remove_runtime(session_id)
		AgentEvents.events.agent_end.emit(session_id, "")
	if generation != demo_generation:
		return
	demo_running = false
	set_status("%s · %s · complete" % [mode_label, visual_label()])
	pass


func play_turn(session_id: int, turn_index: int, turn_count: int, large: bool, generation: int, catalog_offset: int) -> bool:
	var session_tag := session_tag_for_id(session_id)
	var status_prefix := "%s · %s" % [visual_label(), session_tag] if StringUtils.is_not_blank(session_tag) else visual_label()
	set_status("%s · turn %d / %d" % [status_prefix, turn_index + 1, turn_count])
	AgentEvents.events.turn_start.emit(session_id)
	if not await wait_step(pace(0.12, 0.05, large), generation):
		return false

	var reasoning_chunks := build_reasoning_chunks(turn_index, large, session_tag)
	for chunk: String in reasoning_chunks:
		AgentEvents.events.message_update.emit(session_id, chunk, OpenAiClient.STREAM_KIND_REASONING)
		if not await wait_step(pace(0.08, 0.03, large), generation):
			return false

	var tool_calls := build_tool_calls(turn_index, turn_count, large, catalog_offset)
	for tool_spec: Dictionary in tool_calls:
		if not await play_tool(session_id, tool_spec, large, generation):
			return false

	var is_final := turn_index == turn_count - 1
	var content_chunks := build_content_chunks(turn_index, large, is_final, session_tag)
	for chunk: String in content_chunks:
		AgentEvents.events.message_update.emit(session_id, chunk, OpenAiClient.STREAM_KIND_CONTENT)
		if not await wait_step(pace(0.07, 0.025, large), generation):
			return false

	var usage := OpenAiUsage.new()
	usage.prompt_tokens = mini(124_000, 4_000 + (turn_index + 1) * (1_750 if large else 900))
	usage.completion_tokens = 180 + turn_index * (35 if large else 18)
	usage.total_tokens = usage.prompt_tokens + usage.completion_tokens
	AgentEvents.events.message_complete.emit(session_id, usage)
	if not await wait_step(pace(0.1, 0.04, large), generation):
		return false
	AgentEvents.events.turn_end.emit(session_id)
	return await wait_step(pace(0.16, 0.06, large), generation)


func play_tool(session_id: int, tool_spec: Dictionary, large: bool, generation: int) -> bool:
	tool_serial += 1
	var tool_id := "preview-tool-%d" % tool_serial
	var tool_name := str(tool_spec["name"])
	var args: Dictionary[String, Variant] = {}
	var raw_args: Dictionary = tool_spec["args"]
	for key: Variant in raw_args.keys():
		args[str(key)] = raw_args[key]
	AgentEvents.events.tool_execution_start.emit(session_id, tool_id, tool_name, args)
	if not await wait_step(pace(0.45, 0.16, large), generation):
		return false
	var failed := bool(tool_spec.get("failed", false))
	var result := AgentToolResult.error("preview tool failure") if failed else AgentToolResult.ok("preview tool success for %s" % tool_name)
	AgentEvents.events.tool_execution_end.emit(session_id, tool_id, tool_name, result)
	return await wait_step(pace(0.22, 0.08, large), generation)


func build_tool_calls(turn_index: int, turn_count: int, large: bool, catalog_offset: int) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	# Final turn answers without tools, matching a typical AgentLoop finish.
	if turn_index >= turn_count - 1:
		return calls
	if large:
		var count := 1 + (turn_index % 3)
		for offset in range(count):
			var catalog: Dictionary = TOOL_CATALOG[(turn_index * 2 + offset + catalog_offset) % TOOL_CATALOG.size()]
			var call := catalog.duplicate(true)
			call["failed"] = (turn_index + offset + catalog_offset) % 7 == 0
			calls.append(call)
		return calls
	# Small: one tool most turns; cycle the full catalog across 16 rounds.
	if turn_index % 4 == 3:
		return calls
	var catalog_small: Dictionary = TOOL_CATALOG[(turn_index + catalog_offset) % TOOL_CATALOG.size()]
	var small_call := catalog_small.duplicate(true)
	small_call["failed"] = (turn_index + catalog_offset) % 5 == 4
	calls.append(small_call)
	return calls


func build_reasoning_chunks(turn_index: int, large: bool, session_tag: String) -> PackedStringArray:
	var prefix := "%s · " % session_tag if StringUtils.is_not_blank(session_tag) else ""
	if large:
		return PackedStringArray([
			"%sTurn %d goal: inspect the project and plan the next tool call." % [prefix, turn_index + 1],
			"%sReview context, dependencies, and edge cases." % prefix,
			"%sBreak work into steps and assess risk." % prefix,
			"%sCall tools, feed results back to the model, then summarize." % prefix,
		])
	return PackedStringArray([
		"%sTurn %d:" % [prefix, turn_index + 1],
		"%sShort reasoning before the next action." % prefix,
	])


func build_content_chunks(turn_index: int, large: bool, is_final: bool, session_tag: String) -> PackedStringArray:
	var prefix := "%s · " % session_tag if StringUtils.is_not_blank(session_tag) else ""
	if is_final:
		if large:
			return PackedStringArray([
				"%sSummary across turns:" % prefix,
				"%sEdits verified; tool traces are complete." % prefix,
				"%sFinal answer — ending this agent run." % prefix,
			])
		return PackedStringArray(["%sDone. Short reply; run complete." % prefix])
	if large:
		return PackedStringArray([
			"%sTurn %d progress:" % [prefix, turn_index + 1],
			"%sTool results applied; continuing implementation and checks." % prefix,
			"%sNext step stays on plan." % prefix,
		])
	return PackedStringArray([
		"%sBrief reply for turn %d." % [prefix, turn_index + 1],
	])


func seed_user_prompt_for_session(session_id: int, large: bool, secondary: bool) -> void:
	var prompt := secondary_user_prompt(large) if secondary else (large_user_prompt() if large else small_user_prompt())
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER and entry.body == prompt:
			return
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, prompt)
	pass


func small_user_prompt() -> String:
	return "Inspect the project, search the codebase with grep, and write a short note — verify visual effects with a quick agent loop."


func large_user_prompt() -> String:
	return (
		"Run a dense agent loop: use read, write, edit, delete, list_dir, glob, grep, bash, web_search, and web_fetch. "
		+ "Stream responses and tool output each turn until you stop asking for tools. "
		+ "Stress-test Jarvis, Transformer, Reasoning Tree, and Tool Constellation under heavy streaming load."
	)


func secondary_user_prompt(large: bool) -> String:
	if large:
		return large_user_prompt() + " (Concurrent session B — interleaved with session A.)"
	return small_user_prompt() + " (Concurrent session B.)"


func get_demo_session_ids() -> Array[int]:
	if not concurrent_sessions_toggle.button_pressed:
		return [demo_session_id]
	if not ensure_secondary_session():
		return [demo_session_id]
	return [demo_session_id, demo_session_id_b]


func ensure_secondary_session() -> bool:
	if demo_session_id_b != 0 and AgentSessionManager.has_index(demo_session_id_b):
		return true
	var session := AgentSessionManager.create_session()
	demo_session_id_b = session.id
	return demo_session_id_b != 0


func session_tag_for_id(session_id: int) -> String:
	if not concurrent_sessions_toggle.button_pressed:
		return StringUtils.EMPTY
	if session_id == demo_session_id_b:
		return "Session B"
	return "Session A"


func mark_running_sessions(session_ids: Array[int]) -> bool:
	for session_id: int in session_ids:
		if AgentSessionManager.get_session_index(session_id) == null:
			return false
		RuntimeManager.get_or_create_runtime(session_id)
	return true


func clear_running_sessions(session_ids: Array[int]) -> void:
	for session_id: int in session_ids:
		RuntimeManager.remove_runtime(session_id)
	pass


func pace(small_seconds: float, large_seconds: float, large: bool) -> float:
	return large_seconds if large else small_seconds


func wait_step(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return generation == demo_generation


func visual_label() -> String:
	var visual_type := AgentSetting.get_visual_type()
	for spec: Dictionary in EFFECT_SPECS:
		if spec["type"] == visual_type:
			return str(spec["label"])
	return "None"


func set_status(text: String) -> void:
	status_label.text = text
	pass
