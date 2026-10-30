class_name NeuralCore
extends VisualEffect

## Constellation brain with colored regions, white crescent, bloom field, and cortex HUD.
## Visual state follows agent streaming (reasoning / content) like ai-visualizer faces/neural.

const BLOOM_SHADER := preload("res://agent/ui/visuals/neural_core/NeuralCoreBloom.gdshader")
const INK := Color8(96, 140, 220)
const INK_BRIGHT := Color8(170, 210, 255)
const AMBER := Color8(255, 176, 64)
const RED := Color8(255, 52, 52)
const GREEN := Color8(74, 240, 122)
const CYAN := Color8(56, 200, 255)
const SPLAT_GAIN := 1.32
const HALO_RADIUS_SCALE := 0.52
const PROFILE := {
	"idle": Vector2(1.4, 0.48),
	"listening": Vector2(2.6, 0.58),
	"thinking": Vector2(13.0, 0.95),
	"speaking": Vector2(9.0, 0.78),
}
const ALERT_HOLD_SECONDS := 2.4
## 1 = full-resolution field (sharp). Raise to 2 only if splat cost needs trimming.
const FIELD_DOWNSCALE := 1
const HISTORY_LEN := 46
const STATE_HISTORY_LIMIT := 10
const STATE_LOG_ROW_STEP := 22.0
const STATE_LOG_TITLE_GAP := 20.0
const STATE_LOG_LINE_GAP := 16.0
const METER_BAR_MAX_H := 28.0
## [SimulationEffect.stream_energy_for_length] tops out here; meters need 0..1 drive.
const METER_ENERGY_NORM := 0.045
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
var state_history: Array[StateEntry] = []
var last_logged_state: String = ""
## HUD + STATE LOG label; driven by [method on_chat_entry_add] and tool hooks, not stream drives.
var activity_label: String = "IDLE"
var alert_mode: bool = false
var alert_timer: float = 0.0
var breath_scale: float = 1.0
var travelers: Array[Traveler] = []
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
	bloom_rect = ColorRect.new()
	bloom_rect.name = "BloomDisplay"
	bloom_rect.color = Color(0.0, 0.0, 0.0, 0.0)
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
	out_history = PackedFloat32Array()
	state_history.clear()
	last_logged_state = ""
	set_activity("RUN")
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
		set_activity("IDLE")
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


func on_tool_execution_start(_session_id: int, _tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	set_activity(ToolVisualDisplay.upper_name(tool_name))
	pass


func on_tool_execution_end(_session_id: int, _tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		set_activity("ERROR")
		trigger_alert()
	pass


func on_chat_entry_add(_session_id: int, entry: ChatEntry) -> void:
	if not running:
		return
	var label := label_for_chat_entry(entry)
	if label.is_empty():
		return
	set_activity(label)
	pass


static func label_for_chat_entry(entry: ChatEntry) -> String:
	if ChatEntry.is_context_kind(entry.kind):
		return ""
	match entry.kind:
		ChatEntry.KIND_USER:
			return "USER"
		ChatEntry.KIND_THINKING:
			return "THINKING"
		ChatEntry.KIND_AGENT:
			return "RESPONDING"
		ChatEntry.KIND_ERROR:
			return "ERROR"
		ChatEntry.KIND_TOOL, ChatEntry.KIND_WEB_TOOL, ChatEntry.KIND_FILE_TOOL, ChatEntry.KIND_EXPLORER_TOOL:
			return ToolVisualDisplay.upper_name(entry.title)
		ChatEntry.KIND_RESULT:
			return "RESULT"
		ChatEntry.KIND_WEB:
			return "WEB"
		ChatEntry.KIND_GIT_DIFF:
			return "GIT DIFF"
	return ""


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
	sync_bloom_uniforms()
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
		var tendril_index := randi() % anatomy.tendrils.size()
		travelers.append(Traveler.new(tendril_index, 0.35 + randf() * 0.35))
	var speed_scale := 1.0 + 1.6 * think_blend + 0.6 * speak_blend
	var write_index := 0
	while write_index < travelers.size():
		var traveler := travelers[write_index]
		traveler.progress += delta * traveler.speed * speed_scale
		if traveler.progress >= 1.0:
			travelers.remove_at(write_index)
			continue
		write_index += 1
	while travelers.size() > 60:
		travelers.pop_back()
	if out_history.size() != HISTORY_LEN:
		out_history.resize(HISTORY_LEN)
		out_history.fill(0.0)
	var slot := history_cursor % HISTORY_LEN
	out_history[slot] = meter_level_for_display()
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
	pass


func set_activity(label: String) -> void:
	activity_label = label
	match label:
		"THINKING":
			face_state = FaceState.THINKING
		"RESPONDING", "SPEAKING":
			face_state = FaceState.SPEAKING
		"USER", "LISTENING", "RUN":
			face_state = FaceState.LISTENING
		"IDLE":
			face_state = FaceState.IDLE
		_:
			if label != "ERROR" and label != "ALERT":
				face_state = FaceState.THINKING
	push_state_history(label)
	pass


func current_state_label() -> String:
	if alert_mode:
		return "ALERT"
	return activity_label


func push_state_history(label: String) -> void:
	if label == last_logged_state:
		return
	last_logged_state = label
	var now := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
	state_history.insert(0, StateEntry.new(label, clock))
	while state_history.size() > STATE_HISTORY_LIMIT:
		state_history.pop_back()
	pass


func state_color(label: String) -> Color:
	match label:
		"ALERT", "ERROR":
			return RED
		"THINKING":
			return CYAN
		"SPEAKING", "RESPONDING":
			return GREEN
		"LISTENING", "USER", "RUN":
			return AMBER
		"IDLE":
			return INK
		_:
			return CYAN


func meter_level_for_display() -> float:
	var level := clampf(maxf(envelope, maxf(content_drive, reasoning_drive)) / METER_ENERGY_NORM, 0.0, 1.0)
	level = maxf(level, maxf(speak_blend, think_blend * 0.88))
	if not running:
		return level
	if listen_blend > 0.38:
		var mic := 0.22 + 0.58 * absf(sin(clock_seconds * 2.7)) * absf(sin(clock_seconds * 0.61))
		level = maxf(level, mic * listen_blend)
	match activity_label:
		"THINKING":
			level = maxf(level, (0.28 + 0.52 * absf(sin(clock_seconds * 4.6 + history_cursor * 0.05))) * maxf(think_blend, 0.42))
		"RESPONDING", "SPEAKING":
			level = maxf(level, (0.32 + 0.62 * absf(sin(clock_seconds * 7.4 + history_cursor * 0.08))) * maxf(speak_blend, 0.45))
		"IDLE", "RUN", "USER", "LISTENING":
			pass
		_:
			if activity_label != "ERROR" and activity_label != "ALERT":
				level = maxf(level, 0.26 + 0.44 * absf(sin(clock_seconds * 5.8 + float(activity_label.hash() % 97) * 0.02)))
	return clampf(level, 0.0, 1.0)


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
			color = Color(color.r * bright * SPLAT_GAIN, color.g * bright * SPLAT_GAIN, color.b * bright * SPLAT_GAIN)
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


func sync_bloom_uniforms() -> void:
	scratch_live = Vector3(NeuralCoreAnatomy.CRESCENT_CENTER.x, NeuralCoreAnatomy.CRESCENT_CENTER.y, 0.0)
	scratch_project = project_brain(scratch_live, warp_clock)
	bloom_material.set_shader_parameter("crescent_px", Vector2(scratch_project.x, scratch_project.y))
	bloom_material.set_shader_parameter("halo_radius_px", layout_scale * HALO_RADIUS_SCALE)
	bloom_material.set_shader_parameter("halo_strength", 0.28 + 0.25 * envelope)
	bloom_material.set_shader_parameter("alert_mix", 1.0 if alert_mode else 0.0)
	pass


func field_point_to_screen(field_point: Vector2) -> Vector2:
	if field_size.x < 1 or field_size.y < 1:
		return field_point
	return Vector2(field_point.x * size.x / float(field_size.x), field_point.y * size.y / float(field_size.y))


func on_draw_chrome() -> void:
	var canvas := chrome_layer
	var size_px := canvas.size
	if size_px.x < 8.0:
		return
	var ink := RED if alert_mode else INK
	var ink_bright := RED if alert_mode else INK_BRIGHT
	var font_sm := Fonts.regular()
	var font_size_sm := Typography.label_small_size
	draw_region_labels(canvas, font_sm, font_size_sm)
	draw_state_history_panel(canvas, font_sm, font_size_sm, ink, ink_bright)
	draw_meters(canvas, font_sm, font_size_sm, ink, ink_bright, size_px)
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
		var pos := field_point_to_screen(label_positions[region_index] + Vector2(10.0, -18.0))
		var width := font.get_string_size(cluster.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_rect(Rect2(pos.x - 3.0, pos.y - 2.0, width + 6.0, 15.0), VisualColor.stroke(color, alpha * 0.55), false, 1.0)
		canvas.draw_string(font, pos, cluster.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(color, alpha))
	pass


func draw_state_history_panel(canvas: Control, font_sm: Font, font_size: int, ink: Color, ink_bright: Color) -> void:
	var panel_x := canvas.size.x - HUD_PANEL_X
	var panel_w := HUD_PANEL_W
	var panel_y := 16.0
	canvas.draw_string(font_sm, Vector2(panel_x, panel_y), "STATE LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(ink_bright, 1.0))
	panel_y += STATE_LOG_TITLE_GAP
	canvas.draw_line(Vector2(panel_x, panel_y), Vector2(panel_x + panel_w, panel_y), VisualColor.stroke(ink, 0.55), 1.0, true)
	panel_y += STATE_LOG_LINE_GAP
	var shown := mini(state_history.size(), STATE_HISTORY_LIMIT)
	for index in range(shown):
		var entry := state_history[index]
		var row_color := state_color(entry.label)
		canvas.draw_string(font_sm, Vector2(panel_x, panel_y), entry.clock, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(ink, 0.65))
		var label_width := font_sm.get_string_size(entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_string(font_sm, Vector2(panel_x + panel_w - label_width, panel_y), entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(row_color, 0.95 if index == 0 else 0.72))
		panel_y += STATE_LOG_ROW_STEP
	if shown == 0:
		panel_y += 6.0
	pass


func draw_meters(canvas: Control, font_sm: Font, font_size: int, ink: Color, _ink_bright: Color, size_px: Vector2) -> void:
	var base_y := size_px.y - 46.0
	var speaking := speak_blend > 0.25 or content_drive > 0.1
	var meter_span := float(HISTORY_LEN) * 4.0
	var out_x := size_px.x - 28.0 - meter_span
	var state_label := current_state_label()
	var state_col := state_color(state_label)
	var label_width := font_sm.get_string_size(state_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font_sm, Vector2(out_x + meter_span - label_width, base_y - 16.0), state_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, VisualColor.stroke(state_col, 1.0))
	for index in range(HISTORY_LEN):
		var height := maxi(1, int(meter_sample_at(out_history, index) * METER_BAR_MAX_H))
		canvas.draw_rect(Rect2(out_x + index * 4.0, base_y + METER_BAR_MAX_H - height, 3.0, height), VisualColor.stroke(state_col if speaking else ink, 1.0 if speaking else 0.55))
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


class StateEntry:
	extends RefCounted

	## One line in the top-right STATE LOG (label + wall-clock time).

	var label: String
	var clock: String

	func _init(p_label: String, p_clock: String) -> void:
		label = p_label
		clock = p_clock
		pass


class Traveler:
	extends RefCounted

	## A dot gliding along a tendril curve (0..1 along the bezier).

	var tendril_index: int
	var progress: float
	var speed: float

	func _init(p_tendril_index: int, p_speed: float) -> void:
		tendril_index = p_tendril_index
		progress = 0.0
		speed = p_speed
		pass
