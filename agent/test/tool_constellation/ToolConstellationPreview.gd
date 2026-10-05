extends Control

## Standalone Tool Constellation preview. Run with F6; Space or Enter replays the demo.

var constellation: ToolConstellation
var demo_generation: int = 0
var status_label: Label


func _ready() -> void:
	build_preview()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	play_demo.call_deferred()
	pass


func build_preview() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	constellation = ToolConstellation.new()
	constellation.name = "ToolConstellation"
	constellation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(constellation)

	var title := Label.new()
	title.name = "Title"
	title.text = "TOOL CONSTELLATION  ·  工具星图"
	title.position = Vector2(Margin.ma_8, Margin.ma_7)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_top = -Margin.ma_12
	status_label.offset_bottom = -Margin.ma_6
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Space / Enter  重播"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.position = Vector2(-220.0, Margin.ma_7)
	hint.size = Vector2(180.0, 28.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	pass


func apply_theme() -> void:
	var background := get_node("Background") as ColorRect
	var title := get_node("Title") as Label
	var hint := get_node("Hint") as Label
	background.color = ColorBase.app_background
	title.add_theme_font_override("font", Fonts.semibold())
	title.add_theme_font_size_override("font_size", Typography.title_large_size)
	title.add_theme_color_override("font_color", ColorBase.primary_text)
	for label: Label in [status_label, hint]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", ColorBase.secondary_text)
	constellation.on_theme_changed()
	pass


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		play_demo()
		get_viewport().set_input_as_handled()
	pass


func play_demo() -> void:
	demo_generation += 1
	var generation := demo_generation
	constellation.reset_visual()
	constellation.set_visual_visible(true, false)
	constellation.on_agent_start(1)
	constellation.on_turn_start()
	set_status("第 1 轮 · 理解任务")

	if not await wait_step(0.45, generation):
		return
	start_tool("call-read", "read", {"path": "res://project.godot"})
	if not await wait_step(0.7, generation):
		return
	start_tool("call-search", "search_workspace", {"query": "visual effects"})
	if not await wait_step(0.85, generation):
		return
	finish_tool("call-read", "read", false)
	if not await wait_step(0.55, generation):
		return
	finish_tool("call-search", "search_workspace", false)

	constellation.on_turn_end()
	constellation.on_turn_start()
	set_status("第 2 轮 · 修改与验证")
	if not await wait_step(0.5, generation):
		return
	start_tool("call-write", "write", {"path": "res://effect.gd", "content": "..."})
	if not await wait_step(0.5, generation):
		return
	start_tool("call-shell", "shell", {"command": "godot --headless"})
	if not await wait_step(0.9, generation):
		return
	finish_tool("call-shell", "shell", true)
	if not await wait_step(0.65, generation):
		return
	finish_tool("call-write", "write", false)

	constellation.on_turn_end()
	constellation.on_turn_start()
	set_status("第 3 轮 · 针对性重试")
	if not await wait_step(0.55, generation):
		return
	start_tool("call-test", "targeted_test", {"scene": "ToolConstellationTest.tscn"})
	if not await wait_step(1.0, generation):
		return
	finish_tool("call-test", "targeted_test", false)
	if not await wait_step(0.75, generation):
		return
	constellation.on_turn_end()
	constellation.on_agent_end("")
	set_status("任务完成 · 调用轨迹已组成执行星图")
	pass


func start_tool(tool_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	constellation.on_tool_execution_start(tool_id, tool_name, args)
	set_status("调用工具 · %s" % ToolConstellation.public_tool_name(tool_name))
	pass


func finish_tool(tool_id: String, tool_name: String, failed: bool) -> void:
	var result := AgentToolResult.error("Preview failure") if failed else AgentToolResult.ok("Preview success")
	constellation.on_tool_execution_end(tool_id, tool_name, result)
	set_status("工具失败 · 出现断裂波纹" if failed else "工具完成 · 结果流回核心")
	pass


func wait_step(seconds: float, generation: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return generation == demo_generation


func set_status(text: String) -> void:
	status_label.text = text
	pass
