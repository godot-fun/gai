@abstract
class_name SimulationEffect
extends VisualEffect

## Base for effects whose field persists on the GPU between frames. A [SimulationChain] steps
## the field; one full-rect display pass reads it beside the live screen. Event hooks only queue
## impulses and move CPU scalars, so they are safe before the effect enters the tree.
## [member activity] is the presence of the effect: the display is an identity pass at zero and
## the chain stops rendering once activity, impulses, and pending resets are all idle.

const MAX_IMPULSES := 16
const RESET_FRAMES := 2
const IDLE_EPSILON := 0.001
const SETTLE_POLL_LIMIT_MSEC := 1600

var chain: SimulationChain
var display_rect: ColorRect
var display_material: ShaderMaterial
var impulse_shapes: Array[Vector4] = []
var impulse_vectors: Array[Vector4] = []
var reset_frames: int = 0
var field_time: float = 0.0
var activity: float = 0.0
## While a run is live the activity never drops below this floor; agent end releases it.
var activity_floor: float = 0.0
var failure_tint: float = 0.0


@abstract func field_shader() -> Shader


@abstract func display_shader() -> Shader


@abstract func pass_kinds() -> PackedInt32Array


## Screen pixels per field cell.
func field_downscale() -> float:
	return 4.0


func activity_decay_per_second() -> float:
	return 0.5


## Pass 0 also receives the root viewport texture from the previous frame.
func reads_previous_frame() -> bool:
	return false


## Advances CPU-side scalars; called each visible frame before uniforms are pushed.
func step_field(_delta: float) -> void:
	pass


## Pushes effect-specific uniforms to [member chain] and [member display_material].
func apply_field_state() -> void:
	pass


## Configures the display material once after it has been created.
func update_theme_presentation() -> void:
	pass


func _ready() -> void:
	super._ready()
	var field_size := compute_field_size()
	chain = SimulationChain.new()
	chain.name = "SimulationChain"
	add_child(chain)
	chain.setup(field_shader(), pass_kinds(), field_size)
	if reads_previous_frame():
		chain.set_pass_param(0, "previous_frame_tex", get_viewport().get_texture())
	display_material = ShaderMaterial.new()
	display_material.shader = display_shader()
	display_material.set_shader_parameter("field_tex", chain.get_texture())
	display_rect = ColorRect.new()
	display_rect.name = "SimulationDisplay"
	display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display_rect.material = display_material
	add_child(display_rect)
	get_viewport().size_changed.connect(on_viewport_size_changed)
	update_theme_presentation()
	reset_field()
	pass


func fade_in_seconds() -> float:
	return 0.18


func fade_out_seconds() -> float:
	return 0.36


func on_agent_start(_session_id: int) -> void:
	reset_field()
	activity_floor = 1.0
	activity = 1.0
	pass


## Releases the activity floor and waits briefly for the field to settle before the fade-out.
func on_agent_end(_session_id: int, error_message: String) -> void:
	activity_floor = 0.0
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < SETTLE_POLL_LIMIT_MSEC and activity > 0.12:
		await get_tree().process_frame
	pass


func _process(delta: float) -> void:
	if chain == null:
		return
	if not visible:
		chain.set_running(false)
		return
	var safe_delta := minf(delta, 1.0 / 20.0)
	field_time += safe_delta
	step_field(safe_delta)
	step_activity(safe_delta)
	var live := reset_frames > 0 or activity > IDLE_EPSILON or not impulse_shapes.is_empty()
	chain.set_running(live)
	display_material.set_shader_parameter("activity", activity)
	if not live:
		return
	if reset_frames > 0:
		chain.set_pass_param(0, "impulse_count", 0)
	else:
		flush_impulses()
	chain.set_param("reset", reset_frames > 0)
	chain.set_param("field_time", field_time)
	display_material.set_shader_parameter("field_time", field_time)
	display_material.set_shader_parameter("failure_tint", failure_tint)
	reset_frames = maxi(reset_frames - 1, 0)
	apply_field_state()
	pass


func step_activity(delta: float) -> void:
	activity = maxf(move_toward(activity, 0.0, activity_decay_per_second() * delta), activity_floor)
	failure_tint = move_toward(failure_tint, 0.0, 0.8 * delta)
	if activity < IDLE_EPSILON:
		activity = 0.0
	pass


## [param position] is in screen UV (y down); [param radius] is a fraction of screen height.
func queue_impulse(position: Vector2, radius: float, amount: float, vector: Vector4 = Vector4.ZERO) -> bool:
	if impulse_shapes.size() >= MAX_IMPULSES:
		return false
	impulse_shapes.append(Vector4(position.x, position.y, radius, amount))
	impulse_vectors.append(vector)
	return true


func flush_impulses() -> void:
	var shapes := PackedVector4Array()
	var vectors := PackedVector4Array()
	shapes.resize(MAX_IMPULSES)
	vectors.resize(MAX_IMPULSES)
	for index in range(impulse_shapes.size()):
		shapes[index] = impulse_shapes[index]
		vectors[index] = impulse_vectors[index]
	chain.set_pass_param(0, "impulse_shapes", shapes)
	chain.set_pass_param(0, "impulse_vectors", vectors)
	chain.set_pass_param(0, "impulse_count", impulse_shapes.size())
	impulse_shapes.clear()
	impulse_vectors.clear()
	pass


func reset_field() -> void:
	reset_frames = RESET_FRAMES
	field_time = 0.0
	failure_tint = 0.0
	impulse_shapes.clear()
	impulse_vectors.clear()
	pass


func compute_field_size() -> Vector2i:
	var screen_size := get_viewport().get_visible_rect().size
	return field_size_for_screen(screen_size, field_downscale())


func on_viewport_size_changed() -> void:
	chain.resize(compute_field_size())
	reset_frames = RESET_FRAMES
	pass


func bump_activity(amount: float) -> void:
	activity = combine_energy(activity, amount)
	pass


static func field_size_for_screen(screen_size: Vector2, downscale: float) -> Vector2i:
	var safe_downscale := maxf(downscale, 1.0)
	return Vector2i(maxi(16, ceili(screen_size.x / safe_downscale)), maxi(16, ceili(screen_size.y / safe_downscale)))


static func combine_energy(current: float, incoming: float) -> float:
	var safe_current := clampf(current, 0.0, 1.0)
	var safe_incoming := clampf(incoming, 0.0, 1.0)
	return 1.0 - (1.0 - safe_current) * (1.0 - safe_incoming)


static func stream_energy_for_length(length: int) -> float:
	return clampf(float(length) * 0.0018, 0.004, 0.045)


## Stable screen UV for a tool name, kept clear of the toolbar and window edges.
static func tool_anchor(tool_name: String) -> Vector2:
	var hash_value := absi(tool_name.hash())
	var x := 0.18 + float(hash_value % 1000) / 1000.0 * 0.64
	var y := 0.26 + float((hash_value / 1000) % 1000) / 1000.0 * 0.5
	return Vector2(x, y)
