extends Control

## Unified visual-effect preview. Drives [VisualControl] by emitting real [AgentEvents]
## (same sequence as [AgentLoop]), with no direct effect-method calls.
##
## Row 1 — small payload: 16 turns, short user / thinking, each registered tool appears.
## Row 2 — large payload: 64 turns, denser streams and more tool calls per turn.
## Each row has one play button per visual type.

const SMALL_TURNS := 16
const LARGE_TURNS := 64

const EFFECT_SPECS: Array[Dictionary] = [
	{"type": VisualType.Type.JARVIS, "label": "Jarvis"},
	{"type": VisualType.Type.TRANSFORMER, "label": "Transformer"},
	{"type": VisualType.Type.REASONING_TREE, "label": "Reasoning Tree"},
	{"type": VisualType.Type.TOOL_CONSTELLATION, "label": "Tool Constellation"},
	{"type": VisualType.Type.CONTEXT_MEMORY_RIVER, "label": "Context Memory River"},
	{"type": VisualType.Type.NEURAL_AURORA, "label": "Neural Aurora"},
	{"type": VisualType.Type.SEMANTIC_BLACK_HOLE, "label": "Semantic Black Hole"},
	{"type": VisualType.Type.CYBER_COMMAND_DECK, "label": "Cyber Command Deck"},
	{"type": VisualType.Type.QUANTUM_CIRCUIT, "label": "Quantum Circuit"},
	{"type": VisualType.Type.DESKTOP_CAT, "label": "Desktop Cat"},
	{"type": VisualType.Type.GEOMETRIC_GENESIS, "label": "Geometric Genesis"},
	{"type": VisualType.Type.MATRIX_RAIN, "label": "Matrix Rain"},
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
	{"name": WebSearchToolProxy.NAME, "args": {"query": "godot visual effects"}},
]

@onready var background: ColorRect = $Background
@onready var visual_control: VisualControl = $VisualOverlay/VisualControl
@onready var title_label: Label = $UiLayer/Ui/Title
@onready var hint_label: Label = $UiLayer/Ui/Hint
@onready var status_label: Label = $UiLayer/Ui/Status
@onready var stop_button: Button = $UiLayer/Ui/Controls/Stop
@onready var theme_color_select: Button = $UiLayer/Ui/Controls/ThemeColorSelect
@onready var theme_toggle_button: Button = $UiLayer/Ui/Controls/ThemeToggle
@onready var small_row: HBoxContainer = $UiLayer/Ui/SmallRow/Buttons
@onready var large_row: HBoxContainer = $UiLayer/Ui/LargeRow/Buttons
@onready var small_row_label: Label = $UiLayer/Ui/SmallRow/Label
@onready var large_row_label: Label = $UiLayer/Ui/LargeRow/Label

var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select_ctrl: ThemeColorSelect = ThemeColorSelect.new()

var demo_session_id: int = 1_0000
var demo_generation: int = 0
var demo_running: bool = false
var tool_serial: int = 0
var play_buttons: Array[Button] = []


func _ready() -> void:
	# This preview runs directly with F6 and bypasses Agent._ready(), where the application normally
	# initializes translations. Keep this first so effects created below receive translated labels.
	I18nHelper.init_i18n()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AgentSessionManager.load_from_disk()
	demo_session_id = AgentSessionManager.active_session_id
	theme_color_select_ctrl.setup(theme_color_select)
	theme_toggle.setup(theme_toggle_button)
	build_effect_buttons()
	stop_button.pressed.connect(on_stop_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	set_status("选择一排特效按钮开始模拟真实 AgentEvents。")
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
	button.pressed.connect(func() -> void: start_demo(visual_type as VisualType.Type, turn_count, large))
	return button


func apply_theme() -> void:
	background.color = ColorBase.app_background
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	title_label.add_theme_color_override("font_color", ColorBase.primary_text)
	for label: Label in [hint_label, status_label, small_row_label, large_row_label]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", ColorBase.secondary_text)
	var buttons: Array[Button] = [stop_button]
	buttons.append_array(play_buttons)
	for button: Button in buttons:
		button.add_theme_font_override("font", Fonts.medium())
		button.add_theme_font_size_override("font_size", Typography.label_large_size)
		var normal := StyleBoxHelper.create_style_box_flat(ColorBase.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, ColorBase.subtle_border, ControlSize.border_xs)
		ButtonStyle.apply(button, normal,
			ButtonStyle.filled(normal, ButtonStyle.hover_color(ColorBase.control_surface)),
			ButtonStyle.filled(normal, ButtonStyle.press_color(ColorBase.control_surface)))
		ButtonStyle.apply_font_colors(button, ColorBase.secondary_text, ColorBase.primary_text, ThemeColor.accent_theme_color())
	pass


func on_stop_pressed() -> void:
	stop_demo("已停止", true)
	pass


func start_demo(visual_type: VisualType.Type, turn_count: int, large: bool) -> void:
	if demo_running:
		# Cancel the in-flight simulation without agent_end — a follow-up agent_start owns the effect.
		demo_generation += 1
		demo_running = false
		clear_running()
		await get_tree().process_frame
	demo_running = true
	demo_generation += 1
	var generation := demo_generation
	select_visual(visual_type)
	await run_agent_events(turn_count, large, generation)
	pass


func select_visual(visual_type: VisualType.Type) -> void:
	if AgentSetting.get_visual_type() != visual_type:
		AgentSetting.set_visual_type(visual_type)
	elif visual_control.current_effect == null or visual_control.current_effect.get_visual_type() != visual_type:
		visual_control.mount_selected_effect()
	pass


func stop_demo(status_text: String, as_error: bool = false) -> void:
	demo_generation += 1
	demo_running = false
	clear_running()
	if as_error and demo_session_id != 0 and visual_control.running_session_id == demo_session_id:
		AgentEvents.events.agent_end.emit(demo_session_id, "Stop.")
	if StringUtils.is_not_blank(status_text):
		set_status(status_text)
	pass


func run_agent_events(turn_count: int, large: bool, generation: int) -> void:
	seed_user_prompt(large)
	if not mark_running():
		demo_running = false
		set_status("无法启动会话")
		return
	var mode_label := "大数据 · %d 轮" % turn_count if large else "小数据 · %d 轮" % turn_count
	set_status("%s · %s · 开始" % [mode_label, visual_label()])
	AgentEvents.events.agent_start.emit(demo_session_id)
	if not await wait_step(pace(0.35, 0.18, large), generation):
		return

	for turn_index in range(turn_count):
		if not await play_turn(turn_index, turn_count, large, generation):
			return

	if not await wait_step(pace(0.45, 0.2, large), generation):
		return
	demo_running = false
	clear_running()
	AgentEvents.events.agent_end.emit(demo_session_id, "")
	set_status("%s · %s · 完成" % [mode_label, visual_label()])
	pass


func play_turn(turn_index: int, turn_count: int, large: bool, generation: int) -> bool:
	set_status("%s · 第 %d / %d 轮" % [visual_label(), turn_index + 1, turn_count])
	AgentEvents.events.turn_start.emit(demo_session_id)
	if not await wait_step(pace(0.12, 0.05, large), generation):
		return false

	var reasoning_chunks := build_reasoning_chunks(turn_index, large)
	for chunk: String in reasoning_chunks:
		AgentEvents.events.message_update.emit(demo_session_id, chunk, OpenAiClient.STREAM_KIND_REASONING)
		if not await wait_step(pace(0.08, 0.03, large), generation):
			return false

	var tool_calls := build_tool_calls(turn_index, turn_count, large)
	for tool_spec: Dictionary in tool_calls:
		if not await play_tool(tool_spec, large, generation):
			return false

	var is_final := turn_index == turn_count - 1
	var content_chunks := build_content_chunks(turn_index, large, is_final)
	for chunk: String in content_chunks:
		AgentEvents.events.message_update.emit(demo_session_id, chunk, OpenAiClient.STREAM_KIND_CONTENT)
		if not await wait_step(pace(0.07, 0.025, large), generation):
			return false

	var usage := OpenAiUsage.new()
	usage.prompt_tokens = mini(124_000, 4_000 + (turn_index + 1) * (1_750 if large else 900))
	usage.completion_tokens = 180 + turn_index * (35 if large else 18)
	usage.total_tokens = usage.prompt_tokens + usage.completion_tokens
	AgentEvents.events.message_complete.emit(demo_session_id, usage)
	if not await wait_step(pace(0.1, 0.04, large), generation):
		return false
	AgentEvents.events.turn_end.emit(demo_session_id)
	return await wait_step(pace(0.16, 0.06, large), generation)


func play_tool(tool_spec: Dictionary, large: bool, generation: int) -> bool:
	tool_serial += 1
	var tool_id := "preview-tool-%d" % tool_serial
	var tool_name := str(tool_spec["name"])
	var args: Dictionary[String, Variant] = {}
	var raw_args: Dictionary = tool_spec["args"]
	for key: Variant in raw_args.keys():
		args[str(key)] = raw_args[key]
	AgentEvents.events.tool_execution_start.emit(demo_session_id, tool_id, tool_name, args)
	if not await wait_step(pace(0.45, 0.16, large), generation):
		return false
	var failed := bool(tool_spec.get("failed", false))
	var result := AgentToolResult.error("preview tool failure") if failed else AgentToolResult.ok("preview tool success for %s" % tool_name)
	AgentEvents.events.tool_execution_end.emit(demo_session_id, tool_id, tool_name, result)
	return await wait_step(pace(0.22, 0.08, large), generation)


func build_tool_calls(turn_index: int, turn_count: int, large: bool) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	# Final turn answers without tools, matching a typical AgentLoop finish.
	if turn_index >= turn_count - 1:
		return calls
	if large:
		var count := 1 + (turn_index % 3)
		for offset in range(count):
			var catalog: Dictionary = TOOL_CATALOG[(turn_index * 2 + offset) % TOOL_CATALOG.size()]
			var call := catalog.duplicate(true)
			call["failed"] = (turn_index + offset) % 7 == 0
			calls.append(call)
		return calls
	# Small: one tool most turns; cycle the full catalog across 16 rounds.
	if turn_index % 4 == 3:
		return calls
	var catalog_small: Dictionary = TOOL_CATALOG[turn_index % TOOL_CATALOG.size()]
	var small_call := catalog_small.duplicate(true)
	small_call["failed"] = turn_index % 5 == 4
	calls.append(small_call)
	return calls


func build_reasoning_chunks(turn_index: int, large: bool) -> PackedStringArray:
	if large:
		return PackedStringArray([
			"深入分析第 %d 轮目标：" % (turn_index + 1),
			"核对上下文、依赖与边界条件；",
			"拆分执行步骤并评估风险；",
			"准备调用工具收集证据，再汇总结论。",
		])
	return PackedStringArray([
		"轮次 %d：" % (turn_index + 1),
		"短推理，选定下一步动作。",
	])


func build_content_chunks(turn_index: int, large: bool, is_final: bool) -> PackedStringArray:
	if is_final:
		if large:
			return PackedStringArray([
				"汇总全部轮次结果：",
				"关键改动已验证，相关工具调用轨迹完整；",
				"输出最终答复并结束本轮 Agent 运行。",
			])
		return PackedStringArray(["完成。短答复结束运行。"])
	if large:
		return PackedStringArray([
			"第 %d 轮进展：" % (turn_index + 1),
			"已消化工具回执，继续推进实现与校验。",
			"下一步仍按计划执行。",
		])
	return PackedStringArray([
		"第 %d 轮简短回复。" % (turn_index + 1),
	])


func seed_user_prompt(large: bool) -> void:
	var prompt := large_user_prompt() if large else small_user_prompt()
	var session := AgentSessionStore.load_session(demo_session_id)
	if session == null:
		return
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER and entry.body == prompt:
			return
	AgentSessionManager.add_chat_entry(demo_session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, prompt)
	pass


func small_user_prompt() -> String:
	return "请用短流程验证各视觉特效：读取配置、搜索代码、写一小段说明。"


func large_user_prompt() -> String:
	return (
		"请完整演练一次高密度 Agent 运行，覆盖读写改删、搜索、目录列举、图片与音频理解，以及网页抓取与搜索。"
		+ "每一轮都要有可见的思考片段与工具轨迹，最终给出结构化总结。"
		+ "目标是压测 Jarvis / Transformer / Reasoning Tree / Tool Constellation 在多轮大数据量下的表现。"
	)


func mark_running() -> bool:
	var session_index := AgentSessionManager.get_session_index(demo_session_id)
	if session_index == null:
		return false
	session_index.run = AgentSessionIndexes.RunState.new()
	return true


func clear_running() -> void:
	var session_index := AgentSessionManager.get_session_index(demo_session_id)
	if session_index != null:
		session_index.stop_running()
	pass


func pace(small_seconds: float, large_seconds: float, large: bool) -> float:
	return large_seconds if large else small_seconds


func wait_step(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return generation == demo_generation


func visual_label() -> String:
	match AgentSetting.get_visual_type():
		VisualType.Type.JARVIS:
			return "Jarvis"
		VisualType.Type.TRANSFORMER:
			return "Transformer"
		VisualType.Type.REASONING_TREE:
			return "Reasoning Tree"
		VisualType.Type.TOOL_CONSTELLATION:
			return "Tool Constellation"
		VisualType.Type.CONTEXT_MEMORY_RIVER:
			return "Context Memory River"
		VisualType.Type.NEURAL_AURORA:
			return "Neural Aurora"
		VisualType.Type.SEMANTIC_BLACK_HOLE:
			return "Semantic Black Hole"
		VisualType.Type.CYBER_COMMAND_DECK:
			return "Cyber Command Deck"
		VisualType.Type.QUANTUM_CIRCUIT:
			return "Quantum Circuit"
		VisualType.Type.DESKTOP_CAT:
			return "Desktop Cat"
		VisualType.Type.GEOMETRIC_GENESIS:
			return "Geometric Genesis"
		VisualType.Type.MATRIX_RAIN:
			return "Matrix Rain"
	return "None"


func set_status(text: String) -> void:
	status_label.text = text
	pass
