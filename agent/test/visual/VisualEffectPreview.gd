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
	var chunks := PackedStringArray([
		StringUtils.format("{}Turn {}.", prefix, turn_index + 1),
		StringUtils.format("{}Active visual: {} — tune chunk delay so overlays keep up without stutter.", prefix, visual_label()),
		StringUtils.format("{}One tool.", prefix),
		StringUtils.format("{}Draft the visible reply only after the fake tool result lands, and keep it aligned with whatever the preview catalog returned for this turn index.", prefix),
	])
	if large:
		chunks.append(StringUtils.format("{}Repo sweep.", prefix))
		chunks.append(StringUtils.format("{}Matrix Rain, Context Memory River, Jarvis, Transformer, Reasoning Tree — each listens to the same AgentEvents bus, so the text needs both tiny tokens and fat paragraphs to stress layout.", prefix))
		chunks.append(StringUtils.format("{}Large mode.", prefix))
		chunks.append(StringUtils.format("{}Batch read/grep/glob/bash calls; stagger failures on turn_index so success and error styling both get air time.", prefix))
		chunks.append(StringUtils.format("{}Risk: preview delete paths, web_fetch caps.", prefix))
		chunks.append(StringUtils.format("{}When stdout comes back, fold the interesting lines into the assistant stream — skip boilerplate, keep one sharp sentence the user can skim.", prefix))
		chunks.append(StringUtils.format("{}If a tool fails: retry once, swap catalog entry, or bail with partial context.", prefix))
	chunks.append_array(chinese_reasoning_chunks(turn_index, large))
	return chunks


func build_content_chunks(turn_index: int, large: bool, is_final: bool, session_tag: String) -> PackedStringArray:
	var prefix := StringUtils.format("{} · ", session_tag) if StringUtils.is_not_blank(session_tag) else ""
	if is_final:
		var chunks := PackedStringArray([
			StringUtils.format("{}Done.", prefix),
			StringUtils.format("{}Turn {} was the last; agent_end should fire after this stream drains.", prefix, turn_index + 1),
			StringUtils.format("{}Try another effect, or flip Large payload.", prefix),
		])
		if large:
			chunks.append(StringUtils.format("{}Summary ({} turns):", prefix, turn_index + 1))
			chunks.append(StringUtils.format("{}Tools.", prefix))
			chunks.append(StringUtils.format("{}Reasoning tree and tool constellation saw start/end pairs, argument JSON blobs, and occasional AgentToolResult.error — all synthetic, but the timing matches production.", prefix))
			chunks.append(StringUtils.format("{}Memory visuals ate mixed-length chunks.", prefix))
			chunks.append(StringUtils.format("{}Prompt tokens climbed each message_complete; completion_tokens ticked up with turn_index so usage bars have something to draw.", prefix))
			chunks.append(StringUtils.format("{}No real deletes. Fixtures only.", prefix))
		chunks.append_array(chinese_content_chunks(turn_index, large, true))
		return chunks
	var chunks := PackedStringArray([
		StringUtils.format("{}Reply · turn {}.", prefix, turn_index + 1),
		StringUtils.format("{}Small payload: fewer tools, slower pace — still multiple message_update slices so rain/river animations never idle.", prefix),
		StringUtils.format("{}OK.", prefix),
	])
	if large:
		chunks.append(StringUtils.format("{}Catalog output applied.", prefix))
		chunks.append(StringUtils.format("{}The reasoning block above was deliberately uneven — one-word beats, then a long clause — so glyph layout and scroll velocity get exercised the way real models stream.", prefix))
		chunks.append(StringUtils.format("{}Jarvis / Transformer: watch turn_start → tools → content.", prefix))
		chunks.append(StringUtils.format("{}More turns left.", prefix))
	chunks.append_array(chinese_content_chunks(turn_index, large, false))
	return chunks


func seed_user_prompt(session_id: int, large: bool) -> void:
	var prompt := user_prompt(large)
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER and entry.body == prompt:
			return
	AgentSessionManager.add_chat_entry(session_id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, prompt)
	pass


func user_prompt(large: bool) -> String:
	var parts := PackedStringArray([
		"Stress-test the visual preview. ",
		"Grep class_name, glob agent/**/*.tscn, read one config — nothing destructive. ",
		"Mix short and long streaming chunks. ",
	])
	if large:
		parts.append("Heavy run. ")
		parts.append("Rotate every preview tool in the catalog; alternate tool_execution_end success and failure; keep reasoning verbose and assistant replies uneven in length. ")
		parts.append("Hit Jarvis, Transformer, Reasoning Tree, Tool Constellation, Cyber Command Deck, Context Memory River, Matrix Rain, Neural Aurora, Semantic Black Hole, Quantum Circuit — same AgentEvents as AgentLoop. ")
		parts.append("Large payload: more turns, parallel tools, faster timers, fat token usage on message_complete. ")
		parts.append("Close with a long final summary.")
	else:
		parts.append("Small payload — readable, still choppy text.")
	return "".join(parts) + chinese_user_prompt(large)


# ---------------------------------------------------------------------------
# Chinese preview payloads (appended after English; keep independent)
# ---------------------------------------------------------------------------

func chinese_reasoning_chunks(turn_index: int, large: bool) -> PackedStringArray:
	var chunks := PackedStringArray([
		StringUtils.format("【中文·推理】第 {} 轮。", turn_index + 1),
		"先看当前视觉特效能不能跟上流式字数。",
		"短句。",
		"等模拟工具返回后再写对外回复，内容要和 TOOL_CATALOG 里这一轮的工具名对得上，别写空话。",
	])
	if large:
		chunks.append("扫仓库。")
		chunks.append("矩阵雨、上下文记忆河、Jarvis、Transformer 共用 AgentEvents，中文也要长短交错，才能测 CJK 换行和字距。")
		chunks.append("大 payload。")
		chunks.append("同一轮里可以连发 read、grep、glob；按 turn_index 故意让部分 tool_execution_end 失败，方便看错误态。")
		chunks.append("预览里的 delete 路径是假的。")
		chunks.append("工具 stdout 很长也没关系，摘一两句写进助理流即可，其余跳过。")
		chunks.append("失败就换 catalog 条目，或者带着残缺上下文继续。")
	return chunks


func chinese_content_chunks(turn_index: int, large: bool, is_final: bool) -> PackedStringArray:
	if is_final:
		var chunks := PackedStringArray([
			"【中文·收尾】好了。",
			StringUtils.format("第 {} 轮结束，接下来应触发 agent_end。", turn_index + 1),
			"可以换特效按钮，或切 Large。",
		])
		if large:
			chunks.append(StringUtils.format("汇总：共 {} 轮模拟。", turn_index + 1))
			chunks.append("工具链。")
			chunks.append("推理树、工具星座会收到成对的 start/end，参数 JSON 和偶发的 AgentToolResult.error 都是 fixture，但时序与正式 AgentLoop 一致。")
			chunks.append("记忆类视觉会吃到这些中文块。")
			chunks.append("message_complete 里 prompt_tokens 逐轮抬高，completion_tokens 随 turn_index 增加，用量条才有变化。")
			chunks.append("不会真删文件。")
		return chunks
	var chunks := PackedStringArray([
		StringUtils.format("【中文·回复】turn {}。", turn_index + 1),
		"Small 模式工具少、节奏慢，照样多段 message_update，动画不能停。",
		"行。",
	])
	if large:
		chunks.append("已套用 catalog 假结果。")
		chunks.append("上面推理故意混极短和很长的一句，用来压 Noto 字体、竖排密度和滚动速度，贴近真实模型吐字。")
		chunks.append("Jarvis / Transformer：turn_start → 工具 → 正文。")
		chunks.append("后面还有轮次。")
	return chunks


func chinese_user_prompt(large: bool) -> String:
	var parts := PackedStringArray([
		"\n\n—— 中文测试（独立段）——\n",
		"压测视觉预览。",
		"grep class_name、glob agent 下场景、读一个小配置，别动真数据。",
		"中英文流都要长短句混搭。",
	])
	if large:
		parts.append("重压。")
		parts.append("catalog 里每个预览工具都轮换一遍；tool_execution_end 成功失败交替；推理偏长，助理回复长短不齐。")
		parts.append("Jarvis、Transformer、推理树、工具星座、赛博指挥台、上下文记忆河、矩阵雨、神经极光、语义黑洞、量子电路——走与 AgentLoop 相同的事件序列。")
		parts.append("Large：轮次多、并行工具、计时器更快、message_complete  token 数更大。")
		parts.append("最后用一段较长的中文总结收尾。")
	else:
		parts.append("Small：可读，仍要有短促中文块。")
	return "".join(parts)


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
