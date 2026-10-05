extends Control

## Jarvis orb preview — simulates AgentEvents without a real agent run.
## Run with F6 (Run Current Scene) on `agent/test/JarvisOrbTest.tscn`.

const DEMO_PROMPT := "请为 Jarvis Orb 添加一个独立测试场景，方便预览全息科幻效果"

var demo_session_id: int = 0
var demo_running: bool = false
var demo_generation: int = 0

@onready var background: ColorRect = $Background
@onready var orb_controller: AgentOrbController = $OrbLayer/AgentOrbController
@onready var title_label: Label = $Ui/Title
@onready var hint_label: Label = $Ui/Hint
@onready var status_label: Label = $Ui/StatusLabel
@onready var play_button: Button = $Ui/Buttons/PlayDemo
@onready var stop_button: Button = $Ui/Buttons/Stop
@onready var theme_color_select: Button = $Ui/Buttons/ThemeColorSelect
@onready var theme_toggle_button: Button = $Ui/Buttons/ThemeToggle
@onready var reasoning_button: Button = $Ui/StepButtons/Reasoning
@onready var generate_button: Button = $Ui/StepButtons/Generate
@onready var tool_button: Button = $Ui/StepButtons/Tool
@onready var error_button: Button = $Ui/StepButtons/ErrorEnd

var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select_ctrl: ThemeColorSelect = ThemeColorSelect.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	setup_demo_session()
	theme_color_select_ctrl.setup(theme_color_select)
	theme_toggle.setup(theme_toggle_button)
	gdf.events.theme_changed.connect(apply_scene_theme)
	apply_scene_theme()
	play_button.pressed.connect(on_play_demo_pressed)
	stop_button.pressed.connect(on_stop_pressed)
	reasoning_button.pressed.connect(on_reasoning_pressed)
	generate_button.pressed.connect(on_generate_pressed)
	tool_button.pressed.connect(on_tool_pressed)
	error_button.pressed.connect(on_error_end_pressed)
	set_status("按 Play Demo 自动播放完整流程，或用下方按钮单步触发。")
	pass


func apply_scene_theme() -> void:
	background.color = ColorBase.app_background
	title_label.add_theme_color_override("font_color", ColorBase.primary_text)
	hint_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	status_label.add_theme_color_override("font_color", ColorBase.secondary_text)
	pass


func setup_demo_session() -> void:
	# load_from_disk always leaves a session selected — it creates one when the index is empty.
	AgentSessionManager.load_from_disk()
	demo_session_id = AgentSessionManager.active_session_id
	seed_demo_user_prompt()
	pass


func seed_demo_user_prompt() -> void:
	var session := AgentSessionStore.load_session(demo_session_id)
	if session == null:
		return
	for i in range(session.chat_entries.size() - 1, -1, -1):
		var entry: ChatEntry = session.chat_entries[i]
		if entry.kind == ChatEntry.KIND_USER and entry.body == DEMO_PROMPT:
			return
	AgentSessionManager.add_chat_entry(
		demo_session_id,
		ChatEntry.KIND_USER,
		ChatEntry.TITLE_USER,
		DEMO_PROMPT,
	)
	pass


func set_status(text: String) -> void:
	status_label.text = text
	pass


func mark_running() -> bool:
	var session_index := AgentSessionManager.get_session_index(demo_session_id)
	if session_index == null:
		return false
	if session_index.run == null:
		session_index.run = AgentSessionIndexes.RunState.new()
	return true


func clear_running() -> void:
	var session_index := AgentSessionManager.get_session_index(demo_session_id)
	if session_index != null:
		session_index.stop_running()
	pass


func ensure_orb_visible() -> void:
	if not mark_running():
		return
	if orb_controller.visible:
		return
	AgentEvents.events.agent_start.emit(demo_session_id)
	AgentEvents.events.turn_start.emit(demo_session_id)
	pass


func on_play_demo_pressed() -> void:
	if demo_running:
		return
	demo_running = true
	demo_generation += 1
	var gen := demo_generation
	run_full_demo(gen)
	pass


func on_stop_pressed() -> void:
	demo_generation += 1
	demo_running = false
	clear_running()
	AgentEvents.events.agent_end.emit(demo_session_id, "Stop.")
	set_status("已停止")
	pass


func run_full_demo(gen: int) -> void:
	set_status("Demo 运行中…")
	clear_running()
	if not mark_running():
		demo_running = false
		return
	AgentEvents.events.agent_start.emit(demo_session_id)
	await wait_demo(0.6, gen)
	AgentEvents.events.turn_start.emit(demo_session_id)
	await wait_demo(0.4, gen)

	var reasoning_chunks: PackedStringArray = [
		"分析请求：需要独立测试场景，",
		"避免每次都要真实跑 Agent。",
		"方案：模拟 AgentEvents 流式输出。",
	]
	for chunk: String in reasoning_chunks:
		if gen != demo_generation:
			return
		AgentEvents.events.message_update.emit(
			demo_session_id,
			chunk,
			OpenAiClient.STREAM_KIND_REASONING,
		)
		await wait_demo(0.35, gen)

	await wait_demo(0.5, gen)
	var reply_chunks: PackedStringArray = [
		"我会创建 agent/test/JarvisOrbTest.tscn，",
		"通过按钮触发 reasoning、tool、生成等阶段。",
		"先读取 agent/ui/visuals/jarvis/AgentOrbController.gd…",
	]
	for chunk: String in reply_chunks:
		if gen != demo_generation:
			return
		AgentEvents.events.message_update.emit(
			demo_session_id,
			chunk,
			OpenAiClient.STREAM_KIND_CONTENT,
		)
		await wait_demo(0.28, gen)

	if gen != demo_generation:
		return
	AgentEvents.events.message_complete.emit(demo_session_id, OpenAiUsage.new())
	await wait_demo(0.6, gen)

	if gen != demo_generation:
		return
	var args: Dictionary[String, String] = {}
	args[ReadTool.ARG_PATH] = "agent/ui/visuals/jarvis/AgentOrbController.gd"
	AgentEvents.events.tool_execution_start.emit(demo_session_id, "demo-tool-1", ReadTool.NAME, args)
	await wait_demo(1.2, gen)

	if gen != demo_generation:
		return
	var result := (
		"class_name AgentOrbController\n"
		+ "extends Control\n"
		+ "## Event-driven Jarvis orb overlay — shows while the active session agent runs."
	)
	AgentEvents.events.tool_execution_end.emit(
		demo_session_id,
		"demo-tool-1",
		ReadTool.NAME,
		AgentToolResult.ok(result),
	)
	await wait_demo(0.5, gen)

	var final_chunks: PackedStringArray = [
		"已确认结构，接下来写入测试脚本与场景。",
		"浮动关键词会来自这些真实步骤文本。",
	]
	for chunk: String in final_chunks:
		if gen != demo_generation:
			return
		AgentEvents.events.message_update.emit(
			demo_session_id,
			chunk,
			OpenAiClient.STREAM_KIND_CONTENT,
		)
		await wait_demo(0.3, gen)

	if gen != demo_generation:
		return
	AgentEvents.events.turn_end.emit(demo_session_id)
	await wait_demo(0.8, gen)

	if gen != demo_generation:
		return
	demo_running = false
	clear_running()
	AgentEvents.events.agent_end.emit(demo_session_id, "")
	set_status("Demo 完成 — 可再次 Play Demo")
	pass


func wait_demo(seconds: float, gen: int) -> void:
	await get_tree().create_timer(seconds).timeout
	if gen != demo_generation:
		return
	pass


func on_reasoning_pressed() -> void:
	ensure_orb_visible()
	AgentEvents.events.message_update.emit(
		demo_session_id,
		"推理中：评估 shader 参数、bloom 强度与神经元密度…",
		OpenAiClient.STREAM_KIND_REASONING,
	)
	set_status("已注入 reasoning 片段")
	pass


func on_generate_pressed() -> void:
	ensure_orb_visible()
	AgentEvents.events.message_update.emit(
		demo_session_id,
		"生成回复：全息突触能量流随流式字符加速，关键词从步骤文本提取。",
		OpenAiClient.STREAM_KIND_CONTENT,
	)
	set_status("已注入 generating 片段")
	pass


func on_tool_pressed() -> void:
	ensure_orb_visible()
	var args: Dictionary[String, String] = {}
	args[ReadTool.ARG_PATH] = "agent/ui/visuals/jarvis/JarvisOrb.gd"
	AgentEvents.events.tool_execution_start.emit(
		demo_session_id,
		"demo-tool-manual",
		ReadTool.NAME,
		args,
	)
	set_status("已触发 tool_execution_start")
	pass


func on_error_end_pressed() -> void:
	ensure_orb_visible()
	demo_running = false
	demo_generation += 1
	clear_running()
	AgentEvents.events.agent_end.emit(demo_session_id, "Simulated error for orb preview.")
	set_status("已触发 error 结束动画")
	pass
