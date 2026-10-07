class_name FilterCarousel
extends VisualEffect

## Cycles through lightweight full-screen post-processing presets while an agent is running.

const SHADER_PATH := "res://agent/ui/visuals/filter_carousel/FilterCarousel.gdshader"
const HOLD_SECONDS_MIN := 2.4
const HOLD_SECONDS_MAX := 4.2
const TRANSITION_SECONDS := 0.32

## One shader mode can produce several looks through palette and tuning parameters. Keeping the
## presets as data makes new variations cheap and keeps lifecycle behavior out of shader code.
const PRESETS: Array[Dictionary] = [
	{"name": "Mono Film", "mode": 1, "contrast": 1.18, "levels": 8.0, "grain": 0.08},
	{"name": "Noir", "mode": 1, "contrast": 1.75, "levels": 4.0, "grain": 0.13, "vignette": 0.32},
	{"name": "Ink Wash", "mode": 2, "contrast": 1.45, "levels": 5.0, "grain": 0.18},
	{"name": "Newsprint", "mode": 3, "ink": Color("24201c"), "paper": Color("e7ddc7"), "scale": 3.0},
	{"name": "Green Halftone", "mode": 3, "ink": Color("174c3a"), "paper": Color("eee9d9"), "scale": 3.5},
	{"name": "Red Screen Print", "mode": 3, "ink": Color("651d24"), "paper": Color("efcfaa"), "scale": 4.5},
	{"name": "Sepia", "mode": 4, "contrast": 1.08, "grain": 0.08, "vignette": 0.22},
	{"name": "Negative", "mode": 5, "contrast": 1.08},
	{"name": "Poster", "mode": 6, "levels": 5.0, "contrast": 1.25},
	{"name": "CGA", "mode": 6, "levels": 3.0, "contrast": 1.45, "tint": Color("ff54ff")},
	{"name": "Pixel", "mode": 7, "scale": 5.0, "levels": 8.0},
	{"name": "Chunky Pixel", "mode": 7, "scale": 10.0, "levels": 5.0, "contrast": 1.2},
	{"name": "Color CRT", "mode": 8, "scale": 3.0, "grain": 0.05, "vignette": 0.25},
	{"name": "Green Terminal", "mode": 9, "ink": Color("4cff86"), "paper": Color("020d08"), "scale": 3.0},
	{"name": "Amber Terminal", "mode": 9, "ink": Color("ffb638"), "paper": Color("140b02"), "scale": 3.0},
	{"name": "Night Vision", "mode": 10, "ink": Color("87ff72"), "paper": Color("031207"), "grain": 0.13, "vignette": 0.45},
	{"name": "Thermal", "mode": 11, "contrast": 1.25},
	{"name": "RGB Split", "mode": 12, "scale": 3.0, "contrast": 1.12},
	{"name": "Data Glitch", "mode": 13, "scale": 7.0, "contrast": 1.18},
	{"name": "Blueprint", "mode": 14, "ink": Color("d7efff"), "paper": Color("082d56"), "contrast": 1.35},
	{"name": "Pencil", "mode": 15, "ink": Color("26231f"), "paper": Color("e8e1d2"), "contrast": 1.2},
	{"name": "Neon Edge", "mode": 16, "ink": Color("44f5ff"), "paper": Color("10051f"), "contrast": 1.5},
	{"name": "Game Boy", "mode": 17, "ink": Color("263b28"), "paper": Color("a8c76f"), "scale": 4.0, "levels": 4.0},
	{"name": "Dream", "mode": 18, "tint": Color("d995ff"), "vignette": 0.18},
	{"name": "Bleach Bypass", "mode": 1, "contrast": 1.5, "levels": 12.0, "grain": 0.05},
	{"name": "Soft Silver", "mode": 1, "contrast": 0.82, "levels": 12.0, "grain": 0.04},
	{"name": "Blue Screen Print", "mode": 3, "ink": Color("123d70"), "paper": Color("e7edf0"), "scale": 3.0},
	{"name": "Purple Screen Print", "mode": 3, "ink": Color("47245f"), "paper": Color("f0d9df"), "scale": 5.0},
	{"name": "Aqua Poster", "mode": 6, "levels": 4.0, "contrast": 1.35, "tint": Color("8fffee")},
	{"name": "Golden Poster", "mode": 6, "levels": 5.0, "contrast": 1.3, "tint": Color("ffd17a")},
	{"name": "Micro Pixel", "mode": 7, "scale": 3.0, "levels": 6.0, "contrast": 1.2},
	{"name": "Mega Pixel", "mode": 7, "scale": 16.0, "levels": 4.0, "contrast": 1.3},
	{"name": "Fine CRT", "mode": 8, "scale": 1.5, "grain": 0.04, "vignette": 0.18},
	{"name": "Blue Terminal", "mode": 9, "ink": Color("61caff"), "paper": Color("020a16"), "scale": 2.0},
	{"name": "Red Terminal", "mode": 9, "ink": Color("ff5e55"), "paper": Color("160202"), "scale": 4.0},
	{"name": "Heat Alarm", "mode": 11, "contrast": 1.7, "vignette": 0.25},
	{"name": "Wide RGB Split", "mode": 12, "scale": 8.0, "contrast": 1.25},
	{"name": "Hard Glitch", "mode": 13, "scale": 14.0, "contrast": 1.45, "grain": 0.08},
	{"name": "Cyan Blueprint", "mode": 14, "ink": Color("e1ffff"), "paper": Color("075d66"), "contrast": 1.55},
	{"name": "Red Blueprint", "mode": 14, "ink": Color("ffe4d7"), "paper": Color("581015"), "contrast": 1.45},
	{"name": "Charcoal", "mode": 15, "ink": Color("0e0d0c"), "paper": Color("d5caba"), "contrast": 1.75, "grain": 0.1},
	{"name": "Magenta Neon", "mode": 16, "ink": Color("ff40db"), "paper": Color("17041e"), "contrast": 1.65},
	{"name": "Amber Game", "mode": 17, "ink": Color("432305"), "paper": Color("e0a53b"), "scale": 5.0, "levels": 4.0},
	{"name": "Cyan Dream", "mode": 18, "tint": Color("72e8ff"), "vignette": 0.12},
	{"name": "Solarize", "mode": 19, "contrast": 1.25},
	{"name": "Electric Solarize", "mode": 19, "contrast": 1.7, "tint": Color("b77cff")},
	{"name": "Emboss", "mode": 20, "scale": 2.0, "contrast": 1.2},
	{"name": "Copper Emboss", "mode": 20, "scale": 4.0, "tint": Color("d98756"), "contrast": 1.35},
	{"name": "Ocean Duotone", "mode": 21, "ink": Color("071a40"), "paper": Color("5de1e6"), "contrast": 1.25},
	{"name": "Sunset Duotone", "mode": 21, "ink": Color("2b0755"), "paper": Color("ff9a4c"), "contrast": 1.4},
	{"name": "Forest Duotone", "mode": 21, "ink": Color("092719"), "paper": Color("b8dd72"), "contrast": 1.35},
	{"name": "Hue Spin", "mode": 22, "scale": 2.0, "contrast": 1.12},
	{"name": "Prism Spin", "mode": 22, "scale": 5.0, "contrast": 1.3},
	{"name": "Comic", "mode": 23, "levels": 5.0, "scale": 2.0, "contrast": 1.45},
	{"name": "Pop Comic", "mode": 23, "levels": 3.0, "scale": 4.0, "contrast": 1.7, "tint": Color("ffe36b")},
	{"name": "Water Ripple", "mode": 24, "scale": 3.0, "contrast": 1.08},
	{"name": "Heat Haze", "mode": 24, "scale": 8.0, "tint": Color("ffd0a0")},
	{"name": "Fisheye", "mode": 25, "scale": 4.0, "vignette": 0.25},
	{"name": "Bubble Lens", "mode": 25, "scale": 9.0, "vignette": 0.35},
	{"name": "Horizontal Mirror", "mode": 26, "scale": 1.0},
	{"name": "Quad Mirror", "mode": 27, "scale": 1.0},
	{"name": "Kaleidoscope Six", "mode": 28, "scale": 6.0, "contrast": 1.15},
	{"name": "Kaleidoscope Twelve", "mode": 28, "scale": 12.0, "contrast": 1.3},
	{"name": "Glass Mosaic", "mode": 29, "scale": 10.0, "contrast": 1.2},
	{"name": "Tiny Mosaic", "mode": 29, "scale": 5.0, "contrast": 1.35},
	{"name": "VHS Tracking", "mode": 30, "scale": 5.0, "grain": 0.08, "vignette": 0.18},
	{"name": "Damaged Tape", "mode": 30, "scale": 12.0, "grain": 0.14, "contrast": 1.25},
	{"name": "Oil Painting", "mode": 31, "scale": 4.0, "levels": 7.0, "contrast": 1.18},
	{"name": "Thick Oil", "mode": 31, "scale": 8.0, "levels": 4.0, "contrast": 1.35},
	{"name": "Watercolor", "mode": 32, "scale": 4.0, "levels": 8.0, "contrast": 0.85, "tint": Color("f1e4da")},
	{"name": "Bleeding Watercolor", "mode": 32, "scale": 9.0, "levels": 5.0, "contrast": 0.72, "tint": Color("d9eaff")},
	{"name": "Frosted Glass", "mode": 33, "scale": 5.0, "contrast": 1.05},
	{"name": "Crushed Ice", "mode": 33, "scale": 14.0, "contrast": 1.25},
	{"name": "Radial Rush", "mode": 34, "scale": 6.0, "contrast": 1.15, "vignette": 0.2},
	{"name": "Hyperspace", "mode": 34, "scale": 15.0, "contrast": 1.35, "tint": Color("a6c8ff")},
	{"name": "Motion Trail", "mode": 35, "scale": 5.0, "contrast": 1.08},
	{"name": "Long Exposure", "mode": 35, "scale": 14.0, "contrast": 0.9, "tint": Color("ffd6f4")},
	{"name": "Color Dither", "mode": 36, "levels": 5.0, "scale": 2.0, "contrast": 1.15},
	{"name": "Coarse Dither", "mode": 36, "levels": 3.0, "scale": 5.0, "contrast": 1.4},
	{"name": "X Ray", "mode": 37, "ink": Color("d8fbff"), "paper": Color("00162d"), "contrast": 1.35},
	{"name": "Medical Scan", "mode": 37, "ink": Color("d9e6ff"), "paper": Color("090520"), "contrast": 1.7, "grain": 0.04},
	{"name": "Security Camera", "mode": 38, "ink": Color("b9e8c0"), "paper": Color("101a13"), "scale": 3.0, "grain": 0.12, "vignette": 0.35},
	{"name": "Infrared Camera", "mode": 38, "ink": Color("ffdfcf"), "paper": Color("241010"), "scale": 5.0, "grain": 0.08, "vignette": 0.42},
	{"name": "Double Screen", "mode": 39, "scale": 2.0, "contrast": 1.12},
	{"name": "Nine Screens", "mode": 39, "scale": 3.0, "contrast": 1.25},
	{"name": "Soft Swirl", "mode": 40, "scale": 3.0, "vignette": 0.16},
	{"name": "Vortex", "mode": 40, "scale": 11.0, "contrast": 1.2, "vignette": 0.3},
	{"name": "Pixel Sort", "mode": 41, "scale": 5.0, "contrast": 1.2},
	{"name": "Melted Pixels", "mode": 41, "scale": 15.0, "contrast": 1.45, "grain": 0.04},
	{"name": "Block Corruption", "mode": 42, "scale": 8.0, "contrast": 1.25},
	{"name": "Codec Collapse", "mode": 42, "scale": 18.0, "contrast": 1.5, "tint": Color("ffc5ff")},
]

var screen_rect: ColorRect
var filter_material: ShaderMaterial
var rng := RandomNumberGenerator.new()
var preset_order: Array[int] = []
var preset_cursor: int = -1
var hold_timer: float = 0.0
var transition_tween: Tween
var active_session_id: int = 0
var current_preset_name: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_rect = ColorRect.new()
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter_material = ShaderMaterial.new()
	filter_material.shader = load(SHADER_PATH)
	filter_material.set_shader_parameter("strength", 0.0)
	screen_rect.material = filter_material
	add_child(screen_rect)
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.FILTER_CAROUSEL


func reset_visual() -> void:
	active_session_id = 0
	hold_timer = 0.0
	preset_cursor = -1
	preset_order.clear()
	current_preset_name = ""
	stop_transition()
	if filter_material != null:
		filter_material.set_shader_parameter("strength", 0.0)
	pass


func on_agent_start(session_id: int) -> void:
	active_session_id = session_id
	rng.seed = session_id * 104729 + Time.get_ticks_msec()
	rebuild_preset_order()
	show_next_preset(true)
	pass


func on_turn_start() -> void:
	if hold_timer < 0.8:
		hold_timer = 0.8
	pass


func on_tool_execution_start(_tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	show_preset_from_modes([12, 13, 16])
	pass


func on_tool_execution_end(_tool_call_id: String, _tool_name: String, agent_tool_result: AgentToolResult) -> void:
	show_preset_from_modes([3] if agent_tool_result.is_error else [8, 9, 14])
	pass


func on_message_update(_chunk: String, stream_kind: String) -> void:
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING and hold_timer < 1.2:
		hold_timer = 1.2
	pass


func on_agent_end(error_message: String) -> void:
	active_session_id = 0
	if StringUtils.is_not_blank(error_message):
		apply_preset(find_first_mode(13))
		set_filter_strength(0.82)
		await get_tree().create_timer(0.35).timeout
	stop_transition()
	transition_tween = create_tween()
	transition_tween.tween_method(set_filter_strength, current_strength(), 0.0, 0.45)
	await transition_tween.finished
	pass


func _process(delta: float) -> void:
	if active_session_id == 0 or filter_material == null:
		return
	hold_timer -= delta
	if hold_timer <= 0.0 and (transition_tween == null or not transition_tween.is_running()):
		show_next_preset()
	pass


func rebuild_preset_order() -> void:
	preset_order.clear()
	for index in range(PRESETS.size()):
		preset_order.append(index)
	for index in range(preset_order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := preset_order[index]
		preset_order[index] = preset_order[swap_index]
		preset_order[swap_index] = value
	preset_cursor = -1
	pass


func show_next_preset(immediate: bool = false) -> void:
	if preset_order.is_empty():
		rebuild_preset_order()
	preset_cursor += 1
	if preset_cursor >= preset_order.size():
		rebuild_preset_order()
		preset_cursor = 0
	transition_to_preset(preset_order[preset_cursor], immediate)
	pass


func show_preset_from_modes(modes: Array) -> void:
	var candidates: Array[int] = []
	for index in range(PRESETS.size()):
		var preset_mode := int(PRESETS[index]["mode"])
		if modes.any(func(mode: Variant) -> bool: return int(mode) == preset_mode):
			candidates.append(index)
	if candidates.is_empty():
		return
	transition_to_preset(candidates[rng.randi_range(0, candidates.size() - 1)])
	pass


func transition_to_preset(index: int, immediate: bool = false) -> void:
	stop_transition()
	if immediate or current_preset_name.is_empty():
		apply_preset(index)
		set_filter_strength(0.0)
		transition_tween = create_tween()
		transition_tween.tween_method(set_filter_strength, 0.0, 0.82, TRANSITION_SECONDS)
	else:
		transition_tween = create_tween()
		transition_tween.tween_method(set_filter_strength, current_strength(), 0.0, TRANSITION_SECONDS * 0.5)
		transition_tween.tween_callback(func() -> void: apply_preset(index))
		transition_tween.tween_method(set_filter_strength, 0.0, 0.82, TRANSITION_SECONDS * 0.5)
	hold_timer = rng.randf_range(HOLD_SECONDS_MIN, HOLD_SECONDS_MAX)
	pass


func apply_preset(index: int) -> void:
	if filter_material == null or index < 0 or index >= PRESETS.size():
		return
	var preset: Dictionary = PRESETS[index]
	current_preset_name = str(preset["name"])
	filter_material.set_shader_parameter("mode", int(preset["mode"]))
	filter_material.set_shader_parameter("contrast", float(preset.get("contrast", 1.0)))
	filter_material.set_shader_parameter("levels", float(preset.get("levels", 6.0)))
	filter_material.set_shader_parameter("effect_scale", float(preset.get("scale", 3.0)))
	filter_material.set_shader_parameter("grain_strength", float(preset.get("grain", 0.0)))
	filter_material.set_shader_parameter("vignette_strength", float(preset.get("vignette", 0.08)))
	filter_material.set_shader_parameter("ink_color", preset.get("ink", Color("181818")))
	filter_material.set_shader_parameter("paper_color", preset.get("paper", Color("eeeeea")))
	filter_material.set_shader_parameter("tint_color", preset.get("tint", Color.WHITE))
	pass


func find_first_mode(mode: int) -> int:
	for index in range(PRESETS.size()):
		if int(PRESETS[index]["mode"]) == mode:
			return index
	return 0


func set_filter_strength(value: float) -> void:
	if filter_material != null:
		filter_material.set_shader_parameter("strength", value)
	pass


func current_strength() -> float:
	if filter_material == null:
		return 0.0
	return float(filter_material.get_shader_parameter("strength"))


func stop_transition() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = null
	pass
