class_name NeuralCore
extends VisualEffect

## Constellation brain with colored regions, white crescent, bloom field, and cortex HUD.
## Visual state follows agent streaming (reasoning / content) like ai-visualizer faces/neural.

const BLOOM_SHADER := preload("res://agent/ui/visuals/neural_core/NeuralCoreBloom.gdshader")
const BG_COLOR := Color8(2, 3, 10)
const INK := Color8(96, 140, 220)
const INK_BRIGHT := Color8(170, 210, 255)
const AMBER := Color8(255, 176, 64)
const RED := Color8(255, 52, 52)
const GREEN := Color8(74, 240, 122)
const CYAN := Color8(56, 200, 255)
const PROFILE := {
	"idle": Vector2(1.4, 0.38),
	"listening": Vector2(2.6, 0.50),
	"thinking": Vector2(13.0, 0.95),
	"speaking": Vector2(9.0, 0.78),
}
const ALERT_HOLD_SECONDS := 2.4
## 1 = full-resolution field (sharp). Raise to 2 only if splat cost needs trimming.
const FIELD_DOWNSCALE := 1
const HISTORY_LEN := 46
const STATE_HISTORY_LIMIT := 10
const CHROME_REDRAW_INTERVAL := 0.066
const HUD_PANEL_X := 172.0
const HUD_PANEL_W := 148.0
const REASONING_DRIVE_DECAY := 0.48
const CONTENT_DRIVE_DECAY := 0.58
const ENVELOPE_ATTACK := 10.0
const ENVELOPE_RELEASE := 2.2

enum FaceState { IDLE, LISTENING, THINKING, SPEAKING }

var anatomy: NeuralCoreAnatomy
var field_viewport: SubViewport
var splat_texture: ImageTexture
var splat_image: Image
var field_bytes: PackedByteArray
var touched: PackedInt32Array
var touched_count: int = 0
var splat_rect: TextureRect
var field_lines: NeuralCoreFieldLines
var bloom_rect: ColorRect
var bloom_material: ShaderMaterial
var chrome_layer: Control

var running: bool = false
var face_state: FaceState = FaceState.IDLE
var clock_seconds: float = 0.0
var warp_clock: float = 0.0
var listen_amount: float = 0.0
var listen_blend: float = 0.0
var think_blend: float = 0.0
var speak_blend: float = 0.0
var envelope: float = 0.0
var target_envelope: float = 0.0
var reasoning_drive: float = 0.0
var content_drive: float = 0.0
var listen_gate: float = 0.0
var chrome_redraw_clock: float = 0.0
var history_cursor: int = 0
var state_history: Array[Dictionary] = []
var last_logged_state: String = ""
var alert_mode: bool = false
var alert_timer: float = 0.0
var breath_scale: float = 1.0
var travelers: Array[Dictionary] = []
var mic_history: PackedFloat32Array = PackedFloat32Array()
var out_history: PackedFloat32Array = PackedFloat32Array()
var label_positions: PackedVector2Array = PackedVector2Array()
var field_size := Vector2i.ZERO
var layout_center := Vector2.ZERO
var layout_scale: float = 1.0
var awaiting_first_token: bool = false
var scratch_live := Vector3.ZERO
var scratch_project := Vector3.ZERO


func _ready() -> void:
	super._ready()
	NeuralCoreAnatomy.ensure_cluster_defs()
	anatomy = NeuralCoreAnatomy.build()
	label_positions.resize(NeuralCoreAnatomy.N_REGIONS)
	field_viewport = SubViewport.new()
	field_viewport.name = "NeuralFieldViewport"
	field_viewport.transparent_bg = true
	field_viewport.handle_input_locally = false
	field_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(field_viewport)
	splat_rect = TextureRect.new()
	splat_rect.name = "SplatLayer"
	splat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splat_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splat_rect.stretch_mode = TextureRect.STRETCH_SCALE
	field_viewport.add_child(splat_rect)
	field_lines = NeuralCoreFieldLines.new()
	field_lines.name = "FieldLines"
	field_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_lines.anatomy = anatomy
	field_lines.host = self
	var line_blend := CanvasItemMaterial.new()
	line_blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	field_lines.material = line_blend
	field_viewport.add_child(field_lines)
	splat_image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	splat_texture = ImageTexture.create_from_image(splat_image)
	bloom_material = ShaderMaterial.new()
	bloom_material.shader = BLOOM_SHADER
	bloom_material.set_shader_parameter("background_color", BG_COLOR)
	bloom_rect = ColorRect.new()
	bloom_rect.name = "BloomDisplay"
	bloom_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloom_rect.material = bloom_material
	bloom_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bloom_rect)
	chrome_layer = Control.new()
	chrome_layer.name = "Chrome"
	chrome_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome_layer.draw.connect(on_draw_chrome)
	add_child(chrome_layer)
	resized.connect(on_resized)
	on_resized()
	set_process(true)
	pass


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.42


func on_agent_start(_session_id: int) -> void:
	running = true
	face_state = FaceState.LISTENING
	awaiting_first_token = true
	envelope = 0.0
	target_envelope = 0.0
	reasoning_drive = 0.0
	content_drive = 0.0
	listen_gate = 1.0
	alert_mode = false
	alert_timer = 0.0
	for index in range(anatomy.heat.size()):
		anatomy.heat[index] = 0.0
	anatomy.cascade_index = 0
	anatomy.cascade_timer = 0.0
	travelers.clear()
	mic_history = PackedFloat32Array()
	out_history = PackedFloat32Array()
	state_history.clear()
	last_logged_state = ""
	push_state_history("LISTENING")
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	face_state = FaceState.IDLE
	if StringUtils.is_not_blank(error_message):
		trigger_alert()
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < 800:
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	face_state = FaceState.LISTENING
	awaiting_first_token = true
	listen_gate = 1.0
	pass


func on_turn_end(_session_id: int) -> void:
	if running:
		face_state = FaceState.IDLE
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	awaiting_first_token = false
	listen_gate = 0.0
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	target_envelope = maxf(target_envelope, energy)
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_drive = maxf(reasoning_drive, energy)
	else:
		content_drive = maxf(content_drive, energy)
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		trigger_alert()
	pass


func trigger_alert() -> void:
	alert_mode = true
	alert_timer = ALERT_HOLD_SECONDS
	push_state_history("ALERT")
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	clock_seconds += delta
	advance_state_blends(delta)
	advance_heat(delta)
	advance_travelers(delta)
	splat_field()
	field_lines.queue_redraw()
	bloom_material.set_shader_parameter("field_tex", field_viewport.get_texture())
	chrome_redraw_clock += delta
	if chrome_redraw_clock >= CHROME_REDRAW_INTERVAL:
		chrome_redraw_clock = 0.0
		chrome_layer.queue_redraw()
	pass


func advance_state_blends(delta: float) -> void:
	var dt_ms := delta * 1000.0
	reasoning_drive = move_toward(reasoning_drive, 0.0, delta * REASONING_DRIVE_DECAY)
	content_drive = move_toward(content_drive, 0.0, delta * CONTENT_DRIVE_DECAY)
	target_envelope = move_toward(target_envelope, 0.0, delta * ENVELOPE_RELEASE)
	var envelope_tau := ENVELOPE_ATTACK if target_envelope > envelope else ENVELOPE_RELEASE
	envelope = lerpf(envelope, target_envelope, 1.0 - exp(-delta * envelope_tau))
	sync_face_state_from_drives()
	listen_blend = lerpf(listen_blend, listen_gate, 1.0 - exp(-dt_ms / 380.0))
	speak_blend = lerpf(speak_blend, content_drive, 1.0 - exp(-dt_ms / 420.0))
	think_blend = lerpf(think_blend, reasoning_drive, 1.0 - exp(-dt_ms / (320.0 if reasoning_drive > think_blend else 180.0)))
	warp_clock += delta * (0.55 + 1.30 * think_blend + 0.45 * speak_blend + 0.20 * listen_blend)
	var mic_target := envelope if listen_blend > 0.45 else envelope * 0.25
	listen_amount = lerpf(listen_amount, mic_target, minf(1.0, dt_ms / 120.0))
	breath_scale = 1.0 + 0.008 * sin(clock_seconds * 0.5) + 0.018 * envelope
	if alert_timer > 0.0:
		alert_timer = maxf(0.0, alert_timer - delta)
		if alert_timer <= 0.0:
			alert_mode = false
			push_state_history(current_state_label())
	pass


func advance_heat(delta: float) -> void:
	var state_key := profile_key()
	var decay := 1.6 + 3.4 * think_blend
	for index in range(anatomy.heat.size()):
		anatomy.heat[index] *= maxf(0.0, 1.0 - delta * decay)
	if listen_blend > 0.35:
		anatomy.heat[2] = maxf(anatomy.heat[2], 0.60 + 0.40 * listen_amount)
		anatomy.heat[5] = maxf(anatomy.heat[5], 0.30 + 0.30 * listen_amount)
		anatomy.heat[8] = maxf(anatomy.heat[8], 0.25 + 0.25 * listen_amount)
	if content_drive > 0.08 or speak_blend > 0.2:
		var speak_heat := maxf(envelope, content_drive)
		anatomy.heat[4] = maxf(anatomy.heat[4], 0.60 + 0.40 * speak_heat)
		anatomy.heat[0] = maxf(anatomy.heat[0], 0.45 + 0.45 * speak_heat)
		anatomy.heat[1] = maxf(anatomy.heat[1], 0.30 + 0.45 * speak_heat)
		anatomy.heat[3] = maxf(anatomy.heat[3], 0.35 + 0.40 * speak_heat)
	if reasoning_drive > 0.12 or think_blend > 0.25:
		anatomy.cascade_timer += delta
		if anatomy.cascade_timer > 0.14:
			anatomy.cascade_timer = 0.0
			anatomy.cascade_index = (anatomy.cascade_index + 1) % NeuralCoreAnatomy.N_REGIONS
		for trail in range(4):
			var idx := (anatomy.cascade_index - trail + NeuralCoreAnatomy.N_REGIONS * 2) % NeuralCoreAnatomy.N_REGIONS
			anatomy.heat[idx] = maxf(anatomy.heat[idx], 1.0 - float(trail) * 0.23)
	pass


func advance_travelers(delta: float) -> void:
	var state_key := profile_key()
	var profile: Vector2 = PROFILE[state_key]
	var rate := profile.x * (1.0 + 1.5 * envelope)
	if randf() < rate * delta:
		travelers.append({"ti": randi() % anatomy.tendrils.size(), "t": 0.0, "s": 0.35 + randf() * 0.35})
	var speed_scale := 1.0 + 1.6 * think_blend + 0.6 * speak_blend
	var write_index := 0
	while write_index < travelers.size():
		var traveler: Dictionary = travelers[write_index]
		traveler["t"] = float(traveler["t"]) + delta * float(traveler["s"]) * speed_scale
		if float(traveler["t"]) >= 1.0:
			travelers.remove_at(write_index)
			continue
		write_index += 1
	while travelers.size() > 60:
		travelers.pop_back()
	if mic_history.size() != HISTORY_LEN:
		mic_history.resize(HISTORY_LEN)
		mic_history.fill(0.0)
	if out_history.size() != HISTORY_LEN:
		out_history.resize(HISTORY_LEN)
		out_history.fill(0.0)
	var slot := history_cursor % HISTORY_LEN
	mic_history[slot] = listen_amount if listen_blend > 0.45 else listen_amount * 0.25
	out_history[slot] = envelope
	history_cursor += 1
	pass


func sync_face_state_from_drives() -> void:
	if not running:
		face_state = FaceState.IDLE
		return
	if reasoning_drive > content_drive + 0.07:
		face_state = FaceState.THINKING
	elif content_drive > 0.1:
		face_state = FaceState.SPEAKING
	elif listen_gate > 0.2 or listen_blend > 0.45:
		face_state = FaceState.LISTENING
	else:
		face_state = FaceState.IDLE
	push_state_history(current_state_label())
	pass


func current_state_label() -> String:
	if alert_mode:
		return "ALERT"
	return profile_key().to_upper()


func push_state_history(label: String) -> void:
	if label == last_logged_state:
		return
	last_logged_state = label
	var now := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
	state_history.insert(0, {"label": label, "time": clock})
	while state_history.size() > STATE_HISTORY_LIMIT:
		state_history.pop_back()
	pass


func state_color(label: String) -> Color:
	match label:
		"ALERT":
			return RED
		"THINKING":
			return CYAN
		"SPEAKING":
			return GREEN
		"LISTENING":
			return AMBER
		_:
			return INK_BRIGHT


func profile_key() -> String:
	if alert_mode:
		return "idle"
	if reasoning_drive > content_drive + 0.07 or think_blend > 0.35:
		return "thinking"
	if content_drive > 0.1 or speak_blend > 0.25:
		return "speaking"
	if listen_gate > 0.2 or listen_blend > 0.35:
		return "listening"
	return "idle"


func on_resized() -> void:
	var viewport_size := Vector2i(
		maxi(2, int(size.x) / FIELD_DOWNSCALE),
		maxi(2, int(size.y) / FIELD_DOWNSCALE)
	)
	if viewport_size == field_size:
		layout_center = Vector2(viewport_size) * Vector2(0.46, 0.52)
		layout_scale = minf(float(viewport_size.x), float(viewport_size.y)) * 0.52
		return
	field_size = viewport_size
	field_viewport.size = field_size
	splat_rect.size = Vector2(field_size)
	field_lines.size = Vector2(field_size)
	layout_center = Vector2(field_size) * Vector2(0.46, 0.52)
	layout_scale = minf(float(field_size.x), float(field_size.y)) * 0.52
	field_bytes = PackedByteArray()
	field_bytes.resize(field_size.x * field_size.y * 4)
	touched = PackedInt32Array()
	touched.resize(field_size.x * field_size.y)
	touched_count = 0
	splat_image = Image.create(field_size.x, field_size.y, false, Image.FORMAT_RGBA8)
	splat_image.fill(Color(0, 0, 0, 0))
	splat_texture = ImageTexture.create_from_image(splat_image)
	pass


func splat_field() -> void:
	if field_bytes.is_empty():
		return
	for index in range(touched_count):
		var offset: int = touched[index]
		field_bytes[offset] = 0
		field_bytes[offset + 1] = 0
		field_bytes[offset + 2] = 0
		field_bytes[offset + 3] = 0
	touched_count = 0
	var state_key := profile_key()
	var profile: Vector2 = PROFILE[state_key]
	var base_brightness := profile.y
	var t := clock_seconds
	for point_index in range(anatomy.point_positions.size()):
		var cluster_index := anatomy.point_cluster[point_index]
		var live := live_point(point_index, breath_scale)
		scratch_project = project_brain(live, warp_clock)
		var tw := 0.62 + 0.38 * sin(t * anatomy.twinkle_speed[point_index] + anatomy.twinkle_phase[point_index])
		var heat := anatomy.heat[cluster_index] if cluster_index < anatomy.heat.size() else 0.0
		var bright := minf((base_brightness + 0.32 * envelope + 0.7 * heat) * tw * scratch_project.z, NeuralCoreAnatomy.BRIGHT_CAP)
		var color := Color.WHITE
		if alert_mode:
			color = Color(1.0, (50.0 + anatomy.point_colors[point_index].g * 25.0) / 255.0, 45.0 / 255.0)
		else:
			color = anatomy.point_colors[point_index]
			if listen_blend > 0.01:
				var k := 0.55 * listen_blend
				color.r = lerpf(color.r, 70.0 / 255.0, k)
				color.g = lerpf(color.g, 185.0 / 255.0, k)
				color.b = lerpf(color.b, 1.0, k)
			color = Color(color.r * bright, color.g * bright, color.b * bright)
		splat_pixel(int(scratch_project.x), int(scratch_project.y), color, 1.0)
		splat_pixel(int(scratch_project.x) + 1, int(scratch_project.y), color, 0.45)
		splat_pixel(int(scratch_project.x), int(scratch_project.y) + 1, color, 0.45)
	for region_index in range(NeuralCoreAnatomy.N_REGIONS):
		scratch_live = Vector3(NeuralCoreAnatomy.cluster_defs[region_index].center.x, NeuralCoreAnatomy.cluster_defs[region_index].center.y, 0.0)
		scratch_project = project_brain(scratch_live, warp_clock)
		label_positions[region_index] = Vector2(scratch_project.x, scratch_project.y)
	var arc_color := Color(1.0, 90.0 / 255.0, 80.0 / 255.0) if alert_mode else Color(
		(215.0 + (150.0 - 215.0) * listen_blend) / 255.0,
		(240.0 + (215.0 - 240.0) * listen_blend) / 255.0,
		1.0
	)
	for arc_index in range(anatomy.arc_points.size()):
		var arc_point := anatomy.arc_points[arc_index] * breath_scale
		scratch_project = project_brain(arc_point, warp_clock)
		var atw := 0.75 + 0.25 * sin(t * 0.9 + anatomy.arc_twinkle[arc_index])
		var ab := minf(1.6, anatomy.arc_weight[arc_index] * atw * (0.50 + 0.90 * envelope + 0.55 * think_blend + 0.20 * listen_blend) * 1.6)
		var arc_fill := Color(arc_color.r * ab, arc_color.g * ab, arc_color.b * ab)
		var xi := int(scratch_project.x)
		var yi := int(scratch_project.y)
		splat_pixel(xi, yi, arc_fill, 1.0)
		splat_pixel(xi + 1, yi, arc_fill, 0.6)
		splat_pixel(xi, yi + 1, arc_fill, 0.6)
		splat_pixel(xi - 1, yi, arc_fill, 0.6)
		splat_pixel(xi, yi - 1, arc_fill, 0.6)
	splat_image.set_data(field_size.x, field_size.y, false, Image.FORMAT_RGBA8, field_bytes)
	splat_texture.update(splat_image)
	splat_rect.texture = splat_texture
	pass


func live_point(point_index: int, breath: float) -> Vector3:
	var base := anatomy.point_positions[point_index]
	var cluster_index := anatomy.point_cluster[point_index]
	var cluster := NeuralCoreAnatomy.cluster_defs[cluster_index]
	var bfac := 1.0 + 0.035 * sin(clock_seconds * 0.7 + float(cluster_index) * 1.7)
	var amp := anatomy.shimmer_amp[point_index]
	var freq := anatomy.shimmer_freq[point_index]
	var phase := anatomy.shimmer_phase[point_index]
	return Vector3(
		(cluster.center.x + (base.x - cluster.center.x) * bfac) * breath + amp.x * sin(clock_seconds * freq + phase.x),
		(cluster.center.y + (base.y - cluster.center.y) * bfac) * breath + amp.y * sin(clock_seconds * freq + phase.y),
		base.z * breath + amp.z * sin(clock_seconds * freq + phase.z)
	)


func project_brain(point: Vector3, warp_time: float) -> Vector3:
	var yaw := 0.16 * sin(warp_time * 0.45)
	var wob := 0.06 * sin(warp_time * 0.31 + 1.3)
	var x2 := point.x * cos(yaw) + point.z * sin(yaw)
	var z2 := -point.x * sin(yaw) + point.z * cos(yaw)
	var y2 := point.y * cos(wob) - z2 * sin(wob)
	var z3 := point.y * sin(wob) + z2 * cos(wob)
	var persp := 3.0 / (3.0 + z3)
	return Vector3(
		layout_center.x + x2 * layout_scale * persp,
		layout_center.y + y2 * layout_scale * persp * 0.98,
		persp
	)


func splat_pixel(x: int, y: int, color: Color, factor: float) -> void:
	if x < 1 or x >= field_size.x - 2 or y < 1 or y >= field_size.y - 2:
		return
	var offset := (y * field_size.x + x) * 4
	if field_bytes[offset + 3] == 0:
		touched[touched_count] = offset
		touched_count += 1
		field_bytes[offset + 3] = 255
	field_bytes[offset] = mini(255, field_bytes[offset] + int(color.r * 255.0 * factor))
	field_bytes[offset + 1] = mini(255, field_bytes[offset + 1] + int(color.g * 255.0 * factor))
	field_bytes[offset + 2] = mini(255, field_bytes[offset + 2] + int(color.b * 255.0 * factor))


func on_draw_chrome() -> void:
	var canvas := chrome_layer
	var size_px := canvas.size
	if size_px.x < 8.0:
		return
	var ink := RED if alert_mode else INK
	var ink_bright := RED if alert_mode else INK_BRIGHT
	var font_sm := Fonts.regular()
	var font_md := Fonts.medium()
	var font_size_sm := Typography.label_small_size
	var font_size_md := Typography.label_medium_size
	draw_region_labels(canvas, font_sm, font_size_sm)
	var cortex_y := draw_state_history_panel(canvas, font_sm, font_size_sm, ink, ink_bright, size_px)
	draw_cortex_panel(canvas, font_md, font_sm, font_size_md, font_size_sm, ink, ink_bright, size_px, cortex_y)
	draw_meters(canvas, font_sm, font_size_sm, ink, ink_bright, size_px)
	draw_current_state_panel(canvas, font_md, font_sm, font_size_md, font_size_sm, size_px)
	if alert_mode:
		var pulse := 0.45 + 0.55 * absf(sin(clock_seconds * 4.0))
		canvas.draw_rect(Rect2(0, 0, size_px.x, 6), Color(RED.r, RED.g, RED.b, 0.6 * pulse))
		canvas.draw_rect(Rect2(0, size_px.y - 6.0, size_px.x, 6), Color(RED.r, RED.g, RED.b, 0.6 * pulse))
		canvas.draw_rect(Rect2(0, 0, 6, size_px.y), Color(RED.r, RED.g, RED.b, 0.6 * pulse))
		canvas.draw_rect(Rect2(size_px.x - 6.0, 0, 6, size_px.y), Color(RED.r, RED.g, RED.b, 0.6 * pulse))
	pass


func draw_region_labels(canvas: Control, font: Font, font_size: int) -> void:
	for region_index in range(NeuralCoreAnatomy.N_REGIONS):
		var cluster := NeuralCoreAnatomy.cluster_defs[region_index]
		if cluster.label.is_empty():
			continue
		var alpha := 0.55 + 0.45 * minf(1.0, anatomy.heat[region_index])
		var color := RED if alert_mode else cluster.hue
		var pos := label_positions[region_index] + Vector2(10.0, -18.0)
		var width := font.get_string_size(cluster.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_rect(Rect2(pos.x - 3.0, pos.y - 2.0, width + 6.0, 15.0), VisualColor.stroke(color, alpha * 0.55), false, 1.0)
		canvas.draw_string(font, pos, cluster.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(color, alpha))
	pass


func draw_state_history_panel(canvas: Control, font_sm: Font, font_size: int, ink: Color, ink_bright: Color, size_px: Vector2) -> float:
	var panel_x := size_px.x - HUD_PANEL_X
	var panel_w := HUD_PANEL_W
	var panel_y := 16.0
	canvas.draw_string(font_sm, Vector2(panel_x, panel_y), "STATE LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(ink_bright, 1.0))
	panel_y += 18.0
	canvas.draw_line(Vector2(panel_x, panel_y), Vector2(panel_x + panel_w, panel_y), VisualColor.stroke(ink, 0.55), 1.0, true)
	panel_y += 10.0
	var shown := mini(state_history.size(), STATE_HISTORY_LIMIT)
	for index in range(shown):
		var entry: Dictionary = state_history[index]
		var label: String = String(entry["label"])
		var clock: String = String(entry["time"])
		var row_color := state_color(label)
		canvas.draw_string(font_sm, Vector2(panel_x, panel_y), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(ink, 0.65))
		var label_width := font_sm.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_string(font_sm, Vector2(panel_x + panel_w - label_width, panel_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(row_color, 0.95 if index == 0 else 0.72))
		panel_y += 17.0
	if shown == 0:
		panel_y += 4.0
	return panel_y + 10.0
	pass


func draw_current_state_panel(canvas: Control, font_md: Font, font_sm: Font, size_md: int, size_sm: int, size_px: Vector2) -> void:
	var label := current_state_label()
	var color := state_color(label)
	var right_x := size_px.x - 28.0
	var caption := "CURRENT"
	var caption_width := font_sm.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_sm).x
	canvas.draw_string(font_sm, Vector2(right_x - caption_width, size_px.y - 52.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_sm, VisualColor.stroke(INK, 0.72))
	var label_width := font_md.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_md).x
	canvas.draw_string(font_md, Vector2(right_x - label_width, size_px.y - 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_md, VisualColor.stroke(color, 1.0))
	pass


func draw_cortex_panel(canvas: Control, font_md: Font, font_sm: Font, size_md: int, size_sm: int, ink: Color, ink_bright: Color, size_px: Vector2, start_y: float) -> void:
	var panel_x := size_px.x - HUD_PANEL_X
	var panel_w := HUD_PANEL_W
	var panel_y := maxf(start_y, 84.0)
	canvas.draw_string(font_md, Vector2(panel_x, panel_y), "CORTEX STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, size_md, VisualColor.stroke(ink_bright, 1.0))
	canvas.draw_line(Vector2(panel_x, panel_y + 18.0), Vector2(panel_x + panel_w, panel_y + 18.0), VisualColor.stroke(ink, 0.6), 1.0, true)
	panel_y += 26.0
	var rows: Array[Array] = []
	for region_index in range(NeuralCoreAnatomy.N_REGIONS):
		rows.append([NeuralCoreAnatomy.cluster_defs[region_index].label, region_index])
	rows.append(["STT", null])
	rows.append(["TTS", null])
	rows.append(["MEMORY", null])
	rows.append(["BUS", null])
	for row: Array in rows:
		var name: String = row[0]
		var region_index = row[1]
		var chip := chip_for(name, region_index)
		canvas.draw_string(font_sm, Vector2(panel_x, panel_y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, size_sm, VisualColor.stroke(ink, 0.85))
		var chip_width := font_sm.get_string_size(chip[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size_sm).x
		canvas.draw_rect(Rect2(panel_x + panel_w - chip_width - 8.0, panel_y - 1.0, chip_width + 6.0, 14.0), Color(chip[1].r, chip[1].g, chip[1].b, 0.25))
		canvas.draw_string(font_sm, Vector2(panel_x + panel_w - chip_width - 5.0, panel_y), chip[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size_sm, VisualColor.stroke(chip[1], 1.0))
		panel_y += 19.0
	pass


func chip_for(name: String, region_index: Variant) -> Array:
	if alert_mode:
		return ["FAULT", RED]
	var flick_hash: int = absi(name.hash()) % 997
	var flick := int(clock_seconds * 3.0 + float(flick_hash)) % 240 == 0
	if region_index != null:
		var heat := anatomy.heat[int(region_index)]
		if heat > 0.55:
			return ["LIVE", GREEN]
		if heat > 0.2 or flick:
			return ["ACT", CYAN]
		return ["IDLE", dim_color(INK, 0.8)]
	if name == "STT":
		return ["LIVE", GREEN] if face_state == FaceState.LISTENING else ["RDY", dim_color(INK, 0.8)]
	if name == "TTS":
		return ["LIVE", GREEN] if face_state == FaceState.SPEAKING else ["RDY", dim_color(INK, 0.8)]
	if name == "MEMORY":
		return ["READ", CYAN] if face_state == FaceState.THINKING or flick else ["OK", dim_color(INK, 0.8)]
	return ["OK", GREEN if int(clock_seconds) % 4 == 0 else dim_color(GREEN, 0.7)]


static func dim_color(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor)


func draw_meters(canvas: Control, font_sm: Font, font_size: int, ink: Color, ink_bright: Color, size_px: Vector2) -> void:
	var base_y := size_px.y - 46.0
	var mic_x := 28.0
	var listening := listen_blend > 0.45
	var speaking := speak_blend > 0.25 or content_drive > 0.1
	canvas.draw_string(font_sm, Vector2(mic_x, base_y - 16.0), "MIC IN", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(AMBER if listening else ink, 1.0 if listening else 0.7))
	for index in range(HISTORY_LEN):
		var height := maxi(1, int(meter_sample_at(mic_history, index) * 22.0))
		canvas.draw_rect(Rect2(mic_x + index * 4.0, base_y + 22.0 - height, 3.0, height), VisualColor.stroke(AMBER if listening else ink, 1.0 if listening else 0.55))
	var out_x := size_px.x - 28.0 - 46.0 * 4.0
	canvas.draw_string(font_sm, Vector2(out_x, base_y - 16.0), "AUDIO OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(ink_bright if speaking else ink, 1.0 if speaking else 0.7))
	for index in range(HISTORY_LEN):
		var height := maxi(1, int(meter_sample_at(out_history, index) * 22.0))
		canvas.draw_rect(Rect2(out_x + index * 4.0, base_y + 22.0 - height, 3.0, height), VisualColor.stroke(CYAN if speaking else ink, 1.0 if speaking else 0.55))
	pass


func meter_sample_at(history: PackedFloat32Array, display_index: int) -> float:
	if history.size() != HISTORY_LEN or history_cursor <= 0:
		return 0.0
	if history_cursor <= HISTORY_LEN:
		if display_index >= history_cursor:
			return 0.0
		return history[display_index]
	var ring_start := history_cursor % HISTORY_LEN
	return history[(ring_start + display_index) % HISTORY_LEN]
