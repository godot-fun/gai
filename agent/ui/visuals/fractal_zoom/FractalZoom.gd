class_name FractalZoom
extends VisualEffect

## Infinite Mandelbrot zoom (分形无限缩放): glowing filaments of the set dive toward famous
## boundary points over the interface. Streamed answers speed the dive, reasoning cycles the
## palette, and every tool surfaces and dives into that tool's own point. A finished tool flashes
## the filaments; a failed one tints them red. The end of the run zooms back out to the whole set.

const FRACTAL_SHADER: Shader = preload("res://agent/ui/visuals/fractal_zoom/FractalZoom.gdshader")
## Boundary points as (x, y) pairs; float64 here, float32 in the shader limits the dive depth.
const TARGETS: Array[float] = [
	-0.743643887037151, 0.131825904205330,
	-0.7746806106269039, -0.1374168856037867,
	0.001643721971153, -0.822467633298876,
	-0.10109636384562, 0.95628651080914,
	-1.25066, 0.02012,
	-0.235125, 0.827215,
	0.360240443437614, -0.641313061064803,
	-1.62917, -0.0203968,
]
const HOME := Vector2(-0.6, 0.0)
const HOME_SCALE := 1.25
const MIN_SCALE := 0.00012
const MIN_ITERATIONS := 90
const MAX_ITERATIONS := 320
const BASE_DIVE_PER_SECOND := 0.035
const REASONING_DIVE_PER_SECOND := 0.045
const MAX_DIVE_BOOST := 0.09
const DIVE_BOOST_GAIN := 1.4
const DIVE_BOOST_DECAY_PER_SECOND := 0.04
const SURFACE_PER_SECOND := 0.7
const END_SURFACE_PER_SECOND := 0.85
const PALETTE_PER_SECOND := 0.03
const REASONING_PALETTE_PER_SECOND := 0.14
const ROTATION_PER_SECOND := 0.02
const PULSE_DECAY_PER_SECOND := 1.5
const FAILURE_DECAY_PER_SECOND := 0.6
const PRESENCE_PER_SECOND := 2.5
const END_SETTLE_MSEC := 1600

var screen_rect: ColorRect
var fractal_material: ShaderMaterial
var target_index: int = 0
var next_target_index: int = -1
var depth: float = 0.0
var running: bool = false
var reasoning: bool = false
var dive_boost: float = 0.0
var palette_phase: float = 0.0
var rotation_angle: float = 0.0
var pulse: float = 0.0
var failure_tint: float = 0.0
var presence: float = 0.0


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "FractalSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fractal_material = ShaderMaterial.new()
	fractal_material.shader = FRACTAL_SHADER
	screen_rect.material = fractal_material
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	running = true
	reasoning = false
	depth = 0.0
	target_index = randi() % target_count()
	next_target_index = -1
	dive_boost = 0.0
	pulse = 0.0
	failure_tint = 0.0
	presence = 0.0
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	next_target_index = -1
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and depth > 0.0:
		await get_tree().process_frame
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	if not reasoning:
		dive_boost = minf(dive_boost + SimulationEffect.stream_energy_for_length(chunk.length()) * DIVE_BOOST_GAIN, MAX_DIVE_BOOST)
	pass


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var index := target_for(tool_name)
	if index != target_index:
		next_target_index = index
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		failure_tint = 1.0
	else:
		pulse = 1.0
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_zoom(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_zoom(delta: float) -> void:
	dive_boost = move_toward(dive_boost, 0.0, DIVE_BOOST_DECAY_PER_SECOND * delta)
	pulse = move_toward(pulse, 0.0, PULSE_DECAY_PER_SECOND * delta)
	failure_tint = move_toward(failure_tint, 0.0, FAILURE_DECAY_PER_SECOND * delta)
	palette_phase += (REASONING_PALETTE_PER_SECOND if reasoning and running else PALETTE_PER_SECOND) * delta
	rotation_angle += ROTATION_PER_SECOND * delta
	presence = move_toward(presence, 1.0, PRESENCE_PER_SECOND * delta)
	if not running:
		depth = move_toward(depth, 0.0, END_SURFACE_PER_SECOND * delta)
	elif next_target_index >= 0:
		depth = move_toward(depth, 0.0, SURFACE_PER_SECOND * delta)
		if depth <= 0.0:
			target_index = next_target_index
			next_target_index = -1
	else:
		depth = move_toward(depth, 1.0, current_dive_speed() * delta)
		if depth >= 1.0:
			next_target_index = (target_index + 1) % target_count()
	pass


func current_dive_speed() -> float:
	return (REASONING_DIVE_PER_SECOND if reasoning else BASE_DIVE_PER_SECOND) + dive_boost


func current_scale() -> float:
	return HOME_SCALE * pow(MIN_SCALE / HOME_SCALE, depth)


## Keeps the target fixed on screen while zooming: the center slides from home to the target in
## proportion to the scale.
func current_center() -> Vector2:
	var share := current_scale() / HOME_SCALE
	var target_x := TARGETS[target_index * 2]
	var target_y := TARGETS[target_index * 2 + 1]
	return Vector2(target_x + (HOME.x - target_x) * share, target_y + (HOME.y - target_y) * share)


func current_iterations() -> int:
	return int(lerpf(MIN_ITERATIONS, MAX_ITERATIONS, depth))


func apply_shader_state() -> void:
	if fractal_material == null:
		return
	fractal_material.set_shader_parameter("presence", presence)
	fractal_material.set_shader_parameter("center", current_center())
	fractal_material.set_shader_parameter("scale", current_scale())
	fractal_material.set_shader_parameter("rotation", rotation_angle)
	fractal_material.set_shader_parameter("max_iterations", current_iterations())
	fractal_material.set_shader_parameter("palette_phase", palette_phase)
	fractal_material.set_shader_parameter("pulse", pulse)
	fractal_material.set_shader_parameter("failure_tint", failure_tint)
	pass


func update_theme_presentation() -> void:
	if fractal_material == null:
		return
	fractal_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	fractal_material.set_shader_parameter("error_color", Colors.error)
	fractal_material.set_shader_parameter("light_mode", 0.0 if ThemeColor.is_dark_theme() else 1.0)
	pass


static func target_count() -> int:
	return TARGETS.size() / 2


static func target_for(tool_name: String) -> int:
	return absi(tool_name.hash()) % target_count()


## Escape iteration of c, or -1 when c stays bounded for [param limit] iterations.
static func escape_iteration(cx: float, cy: float, limit: int) -> int:
	var zx := 0.0
	var zy := 0.0
	for index in range(limit):
		var next_x := zx * zx - zy * zy + cx
		zy = 2.0 * zx * zy + cy
		zx = next_x
		if zx * zx + zy * zy > 4.0:
			return index
	return -1
