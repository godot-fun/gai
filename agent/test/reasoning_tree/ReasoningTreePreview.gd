extends Control

## Standalone Reasoning Tree preview. Run this scene with F6; no agent session or API is required.

var reasoning_tree: ReasoningTree
var demo_generation: int = 0
var tool_serial: int = 0
var pending_tool_ids: Array[String] = []
var pending_tool_names: Dictionary[String, String] = {}

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Ui/Title
@onready var hint_label: Label = $Ui/Hint
@onready var status_label: Label = $Ui/Status
@onready var play_button: Button = $Ui/PrimaryButtons/PlayDemo
@onready var reset_button: Button = $Ui/PrimaryButtons/Reset
@onready var think_button: Button = $Ui/StepButtons/Think
@onready var tool_button: Button = $Ui/StepButtons/Tool
@onready var success_button: Button = $Ui/StepButtons/Success
@onready var failure_button: Button = $Ui/StepButtons/Failure
@onready var next_turn_button: Button = $Ui/StepButtons/NextTurn
@onready var answer_button: Button = $Ui/StepButtons/Answer
@onready var finish_button: Button = $Ui/StepButtons/Finish


func _ready() -> void:
	reasoning_tree = ReasoningTree.new()
	reasoning_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$VisualLayer.add_child(reasoning_tree)
	connect_buttons()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	reset_preview()
	pass


func connect_buttons() -> void:
	play_button.pressed.connect(play_demo)
	reset_button.pressed.connect(reset_preview)
	think_button.pressed.connect(add_reasoning_growth)
	tool_button.pressed.connect(start_tool)
	success_button.pressed.connect(complete_tool.bind(false))
	failure_button.pressed.connect(complete_tool.bind(true))
	next_turn_button.pressed.connect(start_next_turn)
	answer_button.pressed.connect(add_answer_growth)
	finish_button.pressed.connect(finish_preview)
	pass


func apply_theme() -> void:
	background.color = ColorBase.app_background
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	title_label.add_theme_color_override("font_color", ColorBase.primary_text)
	for label: Label in [hint_label, status_label]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", ColorBase.secondary_text)
	for button: Button in [play_button, reset_button, think_button, tool_button, success_button, failure_button, next_turn_button, answer_button, finish_button]:
		button.add_theme_font_override("font", Fonts.medium())
		button.add_theme_font_size_override("font_size", Typography.label_large_size)
		var normal := StyleBoxHelper.create_style_box_flat(ColorBase.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, ColorBase.subtle_border, ControlSize.border_xs)
		ButtonStyle.apply(button, normal,
			ButtonStyle.filled(normal, ButtonStyle.hover_color(ColorBase.control_surface)),
			ButtonStyle.filled(normal, ButtonStyle.press_color(ColorBase.control_surface)))
		ButtonStyle.apply_font_colors(button, ColorBase.secondary_text, ColorBase.primary_text, ThemeColor.accent_theme_color())
	pass


func reset_preview() -> void:
	demo_generation += 1
	pending_tool_ids.clear()
	pending_tool_names.clear()
	reasoning_tree.reset_visual()
	reasoning_tree.set_visual_visible(true, false)
	reasoning_tree.on_agent_start(1)
	reasoning_tree.on_turn_start()
	set_status("已重置 · 可以单步触发，也可以自动播放。")
	pass


func add_reasoning_growth() -> void:
	for index in range(4):
		reasoning_tree.on_message_update("公开状态脉冲 %d" % index, OpenAiClient.STREAM_KIND_REASONING)
	set_status("Reasoning 活动推动主干生长；文字内容不会出现在树上。")
	pass


func start_tool(tool_name: String = "read_file") -> void:
	tool_serial += 1
	var tool_id := "preview-tool-%d" % tool_serial
	pending_tool_ids.append(tool_id)
	pending_tool_names[tool_id] = tool_name
	reasoning_tree.on_tool_execution_start(tool_id, tool_name, {})
	set_status("工具分支正在生长：%s" % ReasoningTree.public_tool_name(tool_name))
	pass


func complete_tool(failed: bool = false) -> void:
	if pending_tool_ids.is_empty():
		start_tool("shell_command")
	var tool_id: String = pending_tool_ids.pop_back()
	var tool_name: String = pending_tool_names.get(tool_id, "preview_tool")
	pending_tool_names.erase(tool_id)
	var result := AgentToolResult.error("preview failure") if failed else AgentToolResult.ok("preview success")
	reasoning_tree.on_tool_execution_end(tool_id, tool_name, result)
	set_status("失败分支断裂并枯萎。" if failed else "成功分支形成明亮叶片。")
	pass


func start_next_turn() -> void:
	reasoning_tree.on_turn_end()
	reasoning_tree.on_turn_start()
	set_status("从已完成状态进入下一轮，主干继续生长。")
	pass


func add_answer_growth() -> void:
	for index in range(14):
		reasoning_tree.on_message_update("公开答案片段 %d" % index, OpenAiClient.STREAM_KIND_CONTENT)
	set_status("最终答案正在形成树冠。")
	pass


func finish_preview() -> void:
	reasoning_tree.on_message_complete(OpenAiUsage.new())
	reasoning_tree.on_agent_end("")
	set_status("任务完成 · 树冠完全展开。")
	pass


func play_demo() -> void:
	demo_generation += 1
	var generation := demo_generation
	pending_tool_ids.clear()
	pending_tool_names.clear()
	reasoning_tree.reset_visual()
	reasoning_tree.set_visual_visible(true, false)
	reasoning_tree.on_agent_start(1)
	reasoning_tree.on_turn_start()
	set_status("自动播放：分析任务")
	for index in range(12):
		if not await wait_step(0.055, generation):
			return
		reasoning_tree.on_message_update("reasoning activity %d" % index, OpenAiClient.STREAM_KIND_REASONING)
	# Case 1: two tools overlap, then complete in reverse order.
	start_tool("search_workspace")
	if not await wait_step(0.28, generation):
		return
	start_tool("read_project_config")
	if not await wait_step(0.55, generation):
		return
	complete_tool(false)
	if not await wait_step(0.3, generation):
		return
	complete_tool(false)
	start_next_turn()
	for index in range(9):
		if not await wait_step(0.055, generation):
			return
		reasoning_tree.on_message_update("reasoning activity %d" % index, OpenAiClient.STREAM_KIND_REASONING)
	# Case 2: a failed command creates a broken branch; a targeted retry succeeds.
	start_tool("run_full_test_suite")
	if not await wait_step(0.48, generation):
		return
	complete_tool(true)
	if not await wait_step(0.28, generation):
		return
	start_tool("run_targeted_test")
	if not await wait_step(0.48, generation):
		return
	complete_tool(false)
	start_next_turn()
	# Case 3: edit, inspect, and validate across another turn.
	start_tool("apply_patch")
	if not await wait_step(0.42, generation):
		return
	complete_tool(false)
	start_tool("inspect_render")
	if not await wait_step(0.42, generation):
		return
	complete_tool(false)
	start_next_turn()
	for index in range(8):
		if not await wait_step(0.05, generation):
			return
		reasoning_tree.on_message_update("verification activity %d" % index, OpenAiClient.STREAM_KIND_REASONING)
	start_tool("final_verification")
	if not await wait_step(0.48, generation):
		return
	complete_tool(false)
	# Case 4: stream a longer public answer so the crown grows progressively.
	for index in range(26):
		if not await wait_step(0.04, generation):
			return
		reasoning_tree.on_message_update("answer activity %d" % index, OpenAiClient.STREAM_KIND_CONTENT)
	finish_preview()
	pass


func wait_step(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return generation == demo_generation


func set_status(text: String) -> void:
	status_label.text = text
	pass
