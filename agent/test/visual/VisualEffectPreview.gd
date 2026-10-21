extends Control

## Unified visual-effect preview. Drives [VisualControl] by emitting real [AgentEvents]
## (same sequence as [AgentLoop]), with no direct effect-method calls.
##
## Effect buttons are grouped by function; each click creates a new agent session.

const SMALL_TURNS := 16
const LARGE_TURNS := 64

const EFFECT_GROUPS: Array[Dictionary] = [
	{
		"title": "Agent core",
		"effects": [
			{"type": VisualControl.Type.JARVIS, "label": "Jarvis"},
			{"type": VisualControl.Type.TRANSFORMER, "label": "Transformer"},
		],
	},
	{
		"title": "Tools",
		"effects": [
			{"type": VisualControl.Type.REASONING_TREE, "label": "Reasoning Tree"},
			{"type": VisualControl.Type.TOOL_CONSTELLATION, "label": "Tool Constellation"},
			{"type": VisualControl.Type.CYBER_COMMAND_DECK, "label": "Cyber Command Deck"},
		],
	},
	{
		"title": "Context",
		"effects": [
			{"type": VisualControl.Type.CONTEXT_MEMORY_RIVER, "label": "Context Memory River"},
			{"type": VisualControl.Type.MATRIX_RAIN, "label": "Matrix Rain"},
		],
	},
	{
		"title": "Memory & semantics",
		"effects": [
			{"type": VisualControl.Type.NEURAL_AURORA, "label": "Neural Aurora"},
			{"type": VisualControl.Type.SEMANTIC_BLACK_HOLE, "label": "Semantic Black Hole"},
		],
	},
	{
		"title": "Systems & circuits",
		"effects": [
			{"type": VisualControl.Type.QUANTUM_CIRCUIT, "label": "Quantum Circuit"},
		],
	},
	{
		"title": "Motion & style",
		"effects": [
			{"type": VisualControl.Type.DESKTOP_CAT, "label": "Desktop Cat"},
			{"type": VisualControl.Type.GEOMETRIC_GENESIS, "label": "Geometric Genesis"},
			{"type": VisualControl.Type.FILTER_CAROUSEL, "label": "Filter Carousel"},
			{"type": VisualControl.Type.INK_LANDSCAPE, "label": "Ink Landscape"},
			{"type": VisualControl.Type.TAI_CHI, "label": "Tai Chi"},
		],
	},
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
@onready var title_label: Label = $UiLayer/Scroll/Ui/Intro/Title
@onready var hint_label: Label = $UiLayer/Scroll/Ui/Intro/Hint
@onready var status_label: Label = $UiLayer/Scroll/Ui/Run/Status
@onready var stop_button: Button = $UiLayer/Scroll/Ui/Run/Controls/Stop
@onready var theme_color_select_node: Button = $UiLayer/Scroll/Ui/Run/Controls/ThemeColorSelect
@onready var theme_toggle_button: Button = $UiLayer/Scroll/Ui/Run/Controls/ThemeToggle
@onready var payload_label: Label = $UiLayer/Scroll/Ui/Run/Payload/PayloadLabel
@onready var small_payload_button: Button = $UiLayer/Scroll/Ui/Run/Payload/SmallPayload
@onready var large_payload_button: Button = $UiLayer/Scroll/Ui/Run/Payload/LargePayload
@onready var effects_label: Label = $UiLayer/Scroll/Ui/Effects/Label
@onready var effect_groups: VBoxContainer = $UiLayer/Scroll/Ui/Effects/Groups
var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select: ThemeColorSelect = ThemeColorSelect.new()

var demo_generation: int = 0
var demo_active_session_ids: Array[int] = []
var tool_serial: int = 0
var play_buttons: Array[Button] = []
var section_labels: Array[Label] = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	TransformerController.complete_animation_on_agent_end = true
	TaiChi.complete_animation_on_agent_end = true
	I18nHelper.init_i18n()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AgentSessionManager.load_from_disk()
	theme_color_select.setup(theme_color_select_node)
	theme_toggle.setup(theme_toggle_button)
	setup_payload_buttons()
	build_effect_buttons()
	stop_button.pressed.connect(on_stop_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	set_status("Pick an effect button to create an agent and stream simulated AgentEvents.")
	pass


func _exit_tree() -> void:
	TransformerController.complete_animation_on_agent_end = false
	TaiChi.complete_animation_on_agent_end = false
	pass


# ---------------------------------------------------------------------------
# UI build & theme
# ---------------------------------------------------------------------------

func setup_payload_buttons() -> void:
	var payload_group := ButtonGroup.new()
	small_payload_button.button_group = payload_group
	large_payload_button.button_group = payload_group
	small_payload_button.button_pressed = true
	small_payload_button.toggled.connect(on_payload_toggled)
	large_payload_button.toggled.connect(on_payload_toggled)
	pass


func on_payload_toggled(pressed: bool) -> void:
	if not pressed:
		return
	apply_theme()
	pass


func build_effect_buttons() -> void:
	for group: Dictionary in EFFECT_GROUPS:
		var heading := Label.new()
		heading.text = str(group["title"])
		section_labels.append(heading)
		effect_groups.add_child(heading)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", Margin.ma_2)
		effect_groups.add_child(buttons)
		for spec: Dictionary in group["effects"]:
			var button := make_effect_button(str(spec["label"]), int(spec["type"]))
			buttons.add_child(button)
			play_buttons.append(button)
	pass


func make_effect_button(label: String, visual_type: int) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: start_demo(visual_type as VisualControl.Type, selected_turn_count(), selected_large_payload()))
	return button


func selected_large_payload() -> bool:
	return large_payload_button.button_pressed


func selected_turn_count() -> int:
	return LARGE_TURNS if selected_large_payload() else SMALL_TURNS


func apply_theme() -> void:
	background.color = Colors.app_background
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	title_label.add_theme_color_override("font_color", Colors.primary_text)
	for label: Label in [hint_label, status_label, payload_label, effects_label]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", Colors.secondary_text)
	payload_label.add_theme_color_override("font_color", Colors.primary_text)
	for label: Label in section_labels:
		label.add_theme_font_override("font", Fonts.medium())
		label.add_theme_font_size_override("font_size", Typography.label_large_size)
		label.add_theme_color_override("font_color", Colors.primary_text)
	style_toolbar_button(stop_button)
	for button: Button in play_buttons:
		style_toolbar_button(button)
	for button: Button in [small_payload_button, large_payload_button]:
		style_payload_button(button)
	pass


func style_toolbar_button(button: Button) -> void:
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_large_size)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ThemeColor.promote(Colors.control_surface, Colors.am_2)),
		ButtonStyle.filled(normal, ThemeColor.demote(Colors.control_surface, Colors.am_2)))
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())
	pass


func style_payload_button(button: Button) -> void:
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_large_size)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	var selected := ButtonStyle.filled(normal, ThemeColor.promote(Colors.control_surface, Colors.am_2), ThemeColor.accent_theme_color())
	if button.button_pressed:
		ButtonStyle.apply(button, selected, selected, selected)
		ButtonStyle.apply_font_colors(button, ThemeColor.accent_theme_color(), ThemeColor.accent_theme_color(), ThemeColor.accent_theme_color())
	else:
		ButtonStyle.apply(button, normal,
			ButtonStyle.filled(normal, ThemeColor.promote(Colors.control_surface, Colors.am_2)),
			ButtonStyle.filled(normal, ThemeColor.demote(Colors.control_surface, Colors.am_2)))
		ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())
	pass


func set_status(text: String) -> void:
	status_label.text = text
	pass


# ---------------------------------------------------------------------------
# Demo control
# ---------------------------------------------------------------------------

func on_stop_pressed() -> void:
	stop_demo("Stopped.", true)
	pass


func start_demo(visual_type: VisualControl.Type, turn_count: int, large: bool) -> void:
	select_visual(visual_type)
	var session := AgentSessionManager.create_session()
	demo_active_session_ids.append(session.id)
	var generation := demo_generation
	await run_agent_events(session.id, turn_count, large, generation)
	pass


func select_visual(visual_type: VisualControl.Type) -> void:
	if AgentSetting.get_visual_type() != visual_type:
		AgentSetting.set_visual_type(visual_type as int)
	pass


func stop_demo(status_text: String, as_error: bool = false) -> void:
	demo_generation += 1
	var session_ids := demo_active_session_ids.duplicate()
	clear_running_sessions(session_ids)
	if as_error:
		for session_id: int in session_ids:
			if session_id != 0:
				AgentEvents.events.agent_end.emit(session_id, "Stop.")
	demo_active_session_ids.clear()
	if StringUtils.is_not_blank(status_text):
		set_status(status_text)
	pass


# ---------------------------------------------------------------------------
# AgentEvents playback (AgentLoop-shaped)
# ---------------------------------------------------------------------------

func run_agent_events(session_id: int, turn_count: int, large: bool, generation: int) -> void:
	seed_user_prompt(session_id, large)
	if not mark_running(session_id):
		unregister_demo_session(session_id)
		set_status("Cannot start session.")
		return
	var mode_label := format_payload_label(turn_count, large)
	set_status(StringUtils.format("{} · {} · started", mode_label, visual_label()))
	AgentEvents.events.agent_start.emit(session_id)
	if not await wait_step(pace(0.35, 0.18, large), generation):
		unregister_demo_session(session_id)
		return

	for turn_index in range(turn_count):
		if not await play_turn(session_id, turn_index, turn_count, large, generation):
			unregister_demo_session(session_id)
			return

	if not await wait_step(pace(0.45, 0.2, large), generation):
		unregister_demo_session(session_id)
		return
	if generation != demo_generation:
		unregister_demo_session(session_id)
		return
	RuntimeManager.remove_runtime(session_id)
	AgentEvents.events.agent_end.emit(session_id, "")
	unregister_demo_session(session_id)
	set_status(StringUtils.format("{} · {} · complete", mode_label, visual_label()))
	pass


func play_turn(session_id: int, turn_index: int, turn_count: int, large: bool, generation: int) -> bool:
	var session_tag := session_tag_for_id(session_id)
	var status_prefix := StringUtils.format("{} · {}", visual_label(), session_tag) if StringUtils.is_not_blank(session_tag) else visual_label()
	set_status(StringUtils.format("{} · turn {} / {}", status_prefix, turn_index + 1, turn_count))
	AgentEvents.events.turn_start.emit(session_id)
	if not await wait_step(pace(0.12, 0.05, large), generation):
		return false

	var catalog_offset := absi(session_id) % 2
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
	var tool_id := StringUtils.format("preview-tool-{}", tool_serial)
	var tool_name := str(tool_spec["name"])
	var args: Dictionary[String, Variant] = {}
	var raw_args: Dictionary = tool_spec["args"]
	for key: Variant in raw_args.keys():
		args[str(key)] = raw_args[key]
	AgentEvents.events.tool_execution_start.emit(session_id, tool_id, tool_name, args)
	if not await wait_step(pace(0.45, 0.16, large), generation):
		return false
	var failed := bool(tool_spec.get("failed", false))
	var result := AgentToolResult.error("preview tool failure") if failed else AgentToolResult.ok(StringUtils.format("preview tool success for {}", tool_name))
	AgentEvents.events.tool_execution_end.emit(session_id, tool_id, tool_name, result)
	return await wait_step(pace(0.22, 0.08, large), generation)


func wait_step(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return generation == demo_generation


func pace(small_seconds: float, large_seconds: float, large: bool) -> float:
	return large_seconds if large else small_seconds


# ---------------------------------------------------------------------------
# Simulated payloads (tools, streams, prompts)
# ---------------------------------------------------------------------------

func build_tool_calls(turn_index: int, turn_count: int, large: bool, catalog_offset: int) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
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
	if turn_index % 4 == 3:
		return calls
	var catalog_small: Dictionary = TOOL_CATALOG[(turn_index + catalog_offset) % TOOL_CATALOG.size()]
	var small_call := catalog_small.duplicate(true)
	small_call["failed"] = (turn_index + catalog_offset) % 5 == 4
	calls.append(small_call)
	return calls


func build_reasoning_chunks(turn_index: int, large: bool, session_tag: String) -> PackedStringArray:
	var prefix := StringUtils.format("{} · ", session_tag) if StringUtils.is_not_blank(session_tag) else ""
	if large:
		return PackedStringArray([
			StringUtils.format("{}Turn {} goal: inspect the project and plan the next tool call.", prefix, turn_index + 1),
			StringUtils.format("{}Review context, dependencies, and edge cases.", prefix),
			StringUtils.format("{}Break work into steps and assess risk.", prefix),
			StringUtils.format("{}Call tools, feed results back to the model, then summarize.", prefix),
		])
	return PackedStringArray([
		StringUtils.format("{}Turn {}:", prefix, turn_index + 1),
		StringUtils.format("{}Short reasoning before the next action.", prefix),
	])


func build_content_chunks(turn_index: int, large: bool, is_final: bool, session_tag: String) -> PackedStringArray:
	var prefix := StringUtils.format("{} · ", session_tag) if StringUtils.is_not_blank(session_tag) else ""
	if is_final:
		if large:
			return PackedStringArray([
				StringUtils.format("{}Summary across turns:", prefix),
				StringUtils.format("{}Edits verified; tool traces are complete.", prefix),
				StringUtils.format("{}Final answer — ending this agent run.", prefix),
			])
		return PackedStringArray([StringUtils.format("{}Done. Short reply; run complete.", prefix)])
	if large:
		return PackedStringArray([
			StringUtils.format("{}Turn {} progress:", prefix, turn_index + 1),
			StringUtils.format("{}Tool results applied; continuing implementation and checks.", prefix),
			StringUtils.format("{}Next step stays on plan.", prefix),
		])
	return PackedStringArray([
		StringUtils.format("{}Brief reply for turn {}.", prefix, turn_index + 1),
	])


func seed_user_prompt(session_id: int, large: bool) -> void:
	var prompt := large_user_prompt() if large else small_user_prompt()
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


# ---------------------------------------------------------------------------
# Session & display helpers
# ---------------------------------------------------------------------------

func format_payload_label(turn_count: int, large: bool) -> String:
	return StringUtils.format("Large payload · {} turns", turn_count) if large else StringUtils.format("Small payload · {} turns", turn_count)


func session_tag_for_id(session_id: int) -> String:
	if demo_active_session_ids.size() <= 1:
		return StringUtils.EMPTY
	return StringUtils.format("session {}", session_id)


func unregister_demo_session(session_id: int) -> void:
	demo_active_session_ids.erase(session_id)
	pass


func mark_running(session_id: int) -> bool:
	if AgentSessionManager.get_session_index(session_id) == null:
		return false
	RuntimeManager.get_or_create_runtime(session_id)
	return true


func clear_running_sessions(session_ids: Array[int]) -> void:
	for session_id: int in session_ids:
		RuntimeManager.remove_runtime(session_id)
	pass


func visual_label() -> String:
	var visual_type := AgentSetting.get_visual_type()
	for group: Dictionary in EFFECT_GROUPS:
		for spec: Dictionary in group["effects"]:
			if spec["type"] == visual_type:
				return str(spec["label"])
	return "None"
