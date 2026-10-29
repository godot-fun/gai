extends Control

const OUT_DIR := "C:/Users/jaysunxiao/AppData/Local/Temp/classics_caps"
const LINES := [
	"User: refactor the visual overlay and add a few classic effects",
	"Assistant: I will read VisualControl.gd and the simulation base classes first.",
	"  > read_file agent/ui/visuals/VisualControl.gd",
	"  > grep \"SimulationEffect\" agent/ui/visuals",
	"The shared chain renders each pass into a nested SubViewport, so pass 0 reads",
	"the previous frame while later passes read the current one.",
	"func step_field(delta: float) -> void:",
	"    generation_clock += delta * current_generations_per_second()",
	"Tests: 49 passed, 0 failed.",
	"Next I will wire the factory, locale entries and preview buttons.",
]

var layer: CanvasLayer
var dark := true


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var only := OS.get_environment("CLASSICS_ONLY")
	dark = ThemeColor.is_dark_theme()
	build_fake_ui()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	await get_tree().process_frame
	var specs := [
		["warp", func() -> VisualEffect: return WarpSpeed.new()],
		["snap", func() -> VisualEffect: return SnapDissolve.new()],
		["life", func() -> VisualEffect: return GameOfLife.new()],
		["pipes", func() -> VisualEffect: return Pipes3D.new()],
		["lava", func() -> VisualEffect: return LavaLamp.new()],
		["fire", func() -> VisualEffect: return DoomFire.new()],
		["fractal", func() -> VisualEffect: return FractalZoom.new()],
		["lightning", func() -> VisualEffect: return TeslaLightning.new()],
		["boids", func() -> VisualEffect: return Murmuration.new()],
	]
	for spec: Array in specs:
		if not only.is_empty() and only != spec[0]:
			continue
		await run_effect(str(spec[0]), spec[1])
	get_tree().quit()
	pass


func build_fake_ui() -> void:
	var background := ColorRect.new()
	background.color = Colors.app_background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var toolbar := ColorRect.new()
	toolbar.color = Colors.control_surface
	toolbar.position = Vector2.ZERO
	toolbar.size = Vector2(1280, AgentLayout.TOOLBAR_HEIGHT)
	add_child(toolbar)
	for index in range(LINES.size()):
		var label := Label.new()
		label.text = LINES[index]
		label.position = Vector2(80, 90 + index * 52)
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Colors.primary_text)
		add_child(label)
	pass


func run_effect(name: String, factory: Callable) -> void:
	var effect: VisualEffect = factory.call()
	layer.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	await stream(effect, OpenAiClient.STREAM_KIND_REASONING, 1.2)
	await stream(effect, OpenAiClient.STREAM_KIND_CONTENT, 1.6)
	await capture(name, "1_stream")
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	await wait(0.9)
	await capture(name, "2_tools")
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	await wait(0.18)
	await capture(name, "3_result")
	await stream(effect, OpenAiClient.STREAM_KIND_CONTENT, 1.4)
	effect.on_agent_end(1, "")
	await wait(0.7)
	await capture(name, "4_end")
	effect.queue_free()
	await get_tree().process_frame
	pass


func stream(effect: VisualEffect, kind: String, seconds: float) -> void:
	var end_msec := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		effect.on_message_update(1, "streamed chunk of text", kind)
		await get_tree().process_frame
	pass


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	pass


func capture(name: String, stage: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s%s.png" % [OUT_DIR, name, stage, "" if dark else "_light"])
	pass
