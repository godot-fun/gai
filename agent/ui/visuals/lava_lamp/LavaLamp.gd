class_name LavaLamp
extends VisualEffect

## Lava lamp (熔岩灯): glossy wax metaballs drift over the interface and refract it like liquid
## glass. A heater along the bottom warms the wax so blobs rise, cool near the top and sink, and
## merge and split as they pass. Streamed answers turn the heater up, every tool drops in a blob of
## its own color that shoots up when the tool succeeds or bursts into red droplets when it fails.
## The end of the run switches the heater off and the wax sinks away.

const LAVA_SHADER: Shader = preload("res://agent/ui/visuals/lava_lamp/LavaLamp.gdshader")
const MAX_BLOBS := 12
const START_BLOBS := 5
const BASE_RADIUS := 0.075
const TOOL_RADIUS := 0.06
const DROPLET_RADIUS := 0.032
const RUN_HEAT := 0.55
const REASONING_HEAT := 0.75
const MAX_HEAT_BOOST := 0.9
const HEAT_BOOST_GAIN := 9.0
const HEAT_BOOST_DECAY_PER_SECOND := 0.3
const HEATER_BAND := 0.24
const HEATING_PER_SECOND := 0.9
const COOLING_PER_SECOND := 0.22
const BUOYANCY := 260.0
const DRAG_PER_SECOND := 1.4
const WANDER := 22.0
const REPULSION := 90.0
const PULSE_DECAY_PER_SECOND := 1.6
const GLOW_DECAY_PER_SECOND := 0.7
const ERROR_DECAY_PER_SECOND := 0.25
const END_SHRINK_PER_SECOND := 0.55
const END_SETTLE_MSEC := 1600
const PRESENCE_PER_SECOND := 3.0


class Blob extends RefCounted:
	var key: String = ""
	## Position in pixels.
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	## Radius in viewport-height units.
	var radius: float
	var temperature: float = 0.5
	var hue_tag: float = 0.5
	var wander_seed: float = 0.0
	var pulse: float = 0.0
	var glow: float = 0.0
	var error: float = 0.0
	var shrink: float = 1.0


var screen_rect: ColorRect
var lava_material: ShaderMaterial
var blobs: Array[Blob] = []
var running: bool = false
var reasoning: bool = false
var heat_boost: float = 0.0
var presence: float = 0.0
var lamp_time: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "LavaSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lava_material = ShaderMaterial.new()
	lava_material.shader = LAVA_SHADER
	lava_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	screen_rect.material = lava_material
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
	heat_boost = 0.0
	presence = 0.0
	blobs.clear()
	var viewport := viewport_size()
	for index in range(START_BLOBS):
		var x := viewport.x * (0.16 + 0.68 * (float(index) + rng.randf_range(0.2, 0.8)) / float(START_BLOBS))
		var blob := add_blob("", Vector2(x, viewport.y * rng.randf_range(0.82, 0.96)), BASE_RADIUS * rng.randf_range(0.75, 1.25), 0.5 + rng.randf_range(-0.12, 0.12))
		blob.temperature = rng.randf_range(0.3, 0.8)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	heat_boost = 0.0
	if StringUtils.is_not_blank(error_message):
		for blob: Blob in blobs:
			blob.error = 1.0
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and not blobs.is_empty():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	reasoning = false
	heat_boost = minf(heat_boost + 0.3, MAX_HEAT_BOOST)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	if not reasoning:
		heat_boost = minf(heat_boost + SimulationEffect.stream_energy_for_length(chunk.length()) * HEAT_BOOST_GAIN, MAX_HEAT_BOOST)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if find_blob(tool_call_id) != null:
		return
	make_room_for_blob()
	var anchor := SimulationEffect.tool_anchor(tool_name) * viewport_size()
	var blob := add_blob(tool_call_id, anchor, TOOL_RADIUS, hue_tag_for(tool_name))
	blob.temperature = 0.6
	blob.pulse = 1.0
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	var blob := find_blob(tool_call_id)
	if blob == null:
		return
	blob.key = ""
	if not result.is_error:
		blob.temperature = 1.0
		blob.pulse = 1.0
		blob.glow = 1.0
		return
	blob.error = 1.0
	blob.radius *= 0.6
	for index in range(2):
		if blobs.size() >= MAX_BLOBS:
			break
		var droplet := add_blob("", blob.position, DROPLET_RADIUS, blob.hue_tag)
		droplet.error = 1.0
		droplet.velocity = Vector2.from_angle(rng.randf_range(0.0, TAU)) * 220.0
	blob.velocity += Vector2(rng.randf_range(-1.0, 1.0), -1.0) * 120.0
	pass


func add_blob(key: String, position: Vector2, radius: float, hue_tag: float) -> Blob:
	var blob := Blob.new()
	blob.key = key
	blob.position = position
	blob.radius = radius
	blob.hue_tag = hue_tag
	blob.wander_seed = rng.randf() * TAU
	blobs.append(blob)
	return blob


func find_blob(key: String) -> Blob:
	for blob: Blob in blobs:
		if blob.key == key:
			return blob
	return null


## Drops the smallest blob that no running tool owns.
func make_room_for_blob() -> void:
	if blobs.size() < MAX_BLOBS:
		return
	var evict_index := -1
	for index in range(blobs.size()):
		if blobs[index].key.is_empty() and (evict_index < 0 or blobs[index].radius < blobs[evict_index].radius):
			evict_index = index
	blobs.remove_at(evict_index if evict_index >= 0 else 0)
	pass


func heater_power() -> float:
	if not running:
		return 0.0
	return (REASONING_HEAT if reasoning else RUN_HEAT) + heat_boost


func viewport_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func _process(delta: float) -> void:
	if not visible:
		return
	step_lamp(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_lamp(delta: float) -> void:
	lamp_time += delta
	heat_boost = move_toward(heat_boost, 0.0, HEAT_BOOST_DECAY_PER_SECOND * delta)
	presence = move_toward(presence, 1.0 if not blobs.is_empty() else 0.0, PRESENCE_PER_SECOND * delta)
	var viewport := viewport_size()
	var top := float(AgentLayout.TOOLBAR_HEIGHT)
	var power := heater_power()
	for blob: Blob in blobs:
		var radius_px := blob.radius * viewport.y
		var height := clampf((viewport.y - blob.position.y) / maxf(viewport.y - top, 1.0), 0.0, 1.0)
		if height < HEATER_BAND:
			blob.temperature += power * HEATING_PER_SECOND * delta
		blob.temperature -= COOLING_PER_SECOND * (0.4 + height) * delta
		blob.temperature = clampf(blob.temperature, 0.0, 1.0)
		blob.velocity.y -= (blob.temperature - 0.5) * BUOYANCY * delta
		blob.velocity.x += sin(lamp_time * 0.7 + blob.wander_seed) * WANDER * delta
		for other: Blob in blobs:
			if other == blob:
				continue
			var gap := blob.position - other.position
			var reach := (blob.radius + other.radius) * viewport.y * 0.55
			var distance := gap.length()
			if distance > 0.001 and distance < reach:
				blob.velocity += gap / distance * REPULSION * (1.0 - distance / reach) * delta
		blob.velocity *= exp(-DRAG_PER_SECOND * delta)
		blob.position += blob.velocity * delta
		blob.position.x = clampf(blob.position.x, radius_px * 0.6, viewport.x - radius_px * 0.6)
		if blob.position.y < top + radius_px * 0.6:
			blob.position.y = top + radius_px * 0.6
			blob.velocity.y = absf(blob.velocity.y) * 0.3
		if blob.position.y > viewport.y + radius_px * 0.25:
			blob.position.y = viewport.y + radius_px * 0.25
			blob.velocity.y = -absf(blob.velocity.y) * 0.3
		blob.pulse = move_toward(blob.pulse, 0.0, PULSE_DECAY_PER_SECOND * delta)
		blob.glow = move_toward(blob.glow, 0.0, GLOW_DECAY_PER_SECOND * delta)
		if running:
			blob.error = move_toward(blob.error, 0.0, ERROR_DECAY_PER_SECOND * delta)
		else:
			blob.shrink = move_toward(blob.shrink, 0.0, END_SHRINK_PER_SECOND * delta)
	if not running:
		for index in range(blobs.size() - 1, -1, -1):
			if blobs[index].shrink <= 0.0:
				blobs.remove_at(index)
	pass


func apply_shader_state() -> void:
	if lava_material == null:
		return
	screen_rect.visible = presence > 0.001
	if not screen_rect.visible:
		return
	var viewport := viewport_size()
	var shapes := PackedVector4Array()
	var effects := PackedVector4Array()
	shapes.resize(MAX_BLOBS)
	effects.resize(MAX_BLOBS)
	for index in range(mini(blobs.size(), MAX_BLOBS)):
		var blob := blobs[index]
		var radius := blob.radius * (1.0 + blob.pulse * 0.22) * blob.shrink
		shapes[index] = Vector4(blob.position.x / viewport.x, blob.position.y / viewport.y, radius, blob.hue_tag)
		effects[index] = Vector4(blob.error, blob.glow, 0.0, 0.0)
	lava_material.set_shader_parameter("blob_count", mini(blobs.size(), MAX_BLOBS))
	lava_material.set_shader_parameter("blobs", shapes)
	lava_material.set_shader_parameter("blob_fx", effects)
	lava_material.set_shader_parameter("presence", presence)
	pass


func update_theme_presentation() -> void:
	if lava_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	lava_material.set_shader_parameter("accent_color", VisualColor.appearance_color(ThemeColor.accent_theme_color()))
	lava_material.set_shader_parameter("error_color", Colors.error)
	lava_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	lava_material.set_shader_parameter("wax_opacity", 0.62 if dark else 0.55)
	pass


## Stable hue offset for a tool's wax, mapped around the accent hue by the shader.
static func hue_tag_for(tool_name: String) -> float:
	return float(absi(tool_name.hash()) % 1000) / 1000.0
