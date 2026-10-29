class_name Kintsugi
extends VisualEffect

## Kintsugi (金缮): a failed tool call strikes the live interface with a flash, a shockwave and a
## short shake, shattering it at one point into 6–9 porcelain shards that spring outward over dark
## seams. The next successful tool call, or the end of the turn, snaps them home and flows molten
## gold outward along the seams, where it keeps glinting. A turn without a repair still
## leaves one hairline of gold, so every run leaves a mark. Seams stay until the run ends; a run
## that ends in error seals its last repair with vermilion lacquer instead of gold.

const KINTSUGI_SHADER: Shader = preload("res://agent/ui/visuals/kintsugi/Kintsugi.gdshader")
const MAX_CRACKS := 8
const SHARD_COUNT_MIN := 6
const SHARD_COUNT_MAX := 9
const HAIRLINE_SHARD_COUNT := 2
const FRACTURE_RADIUS_MIN := 0.20
const FRACTURE_RADIUS_MAX := 0.30
const HAIRLINE_RADIUS_MIN := 0.10
const HAIRLINE_RADIUS_MAX := 0.18
const SPRING_STIFFNESS := 170.0
const SPRING_DAMPING := 13.0
const SPRING_SUBSTEPS := 4
const LACQUER_FLOW_PER_SECOND := 0.85
const CRACKLE_PULSE := 0.55
const CRACKLE_DECAY_PER_SECOND := 0.9
const IMPACT_DECAY_PER_SECOND := 1.6
const SHAKE_DECAY_PER_SECOND := 3.2
const SHAKE_PX := 7.0
const IDLE_EPSILON := 0.001
const PLACEMENT_CANDIDATES := 7
const ERROR_SHATTER_MSEC := 350
const END_SETTLE_MSEC := 1600
const DEFAULT_ASPECT := 16.0 / 9.0
const VERMILION := 1.0
const GOLD := 0.0


class Crack extends RefCounted:
	## Center in screen UV.
	var center: Vector2
	## Reach in viewport-height units.
	var radius: float
	var noise_seed: float
	var shard_count: int
	var open: float = 0.0
	var velocity: float = 0.0
	var open_target: float = 0.0
	var flow: float = 0.0
	var flowing: bool = false
	var vermilion: float = 0.0
	## Flash and shockwave drive: 1 at the break, decaying to 0.
	var impact: float = 0.0


var screen_rect: ColorRect
var kintsugi_material: ShaderMaterial
var cracks: Array[Crack] = []
var crackle: float = 0.0
var crackle_seed: float = 0.0
var shake: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var crack_serial: int = 0
var turn_repaired: bool = false
var idle_shader_applied: bool = false


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "KintsugiSurface"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kintsugi_material = ShaderMaterial.new()
	kintsugi_material.shader = KINTSUGI_SHADER
	kintsugi_material.set_shader_parameter("toolbar_height_px", float(AgentLayout.TOOLBAR_HEIGHT))
	screen_rect.material = kintsugi_material
	add_child(screen_rect)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.12


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	reset_cracks()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	if StringUtils.is_blank(error_message):
		heal_open_cracks(GOLD)
	elif not has_open_crack():
		# The run broke without a failed tool: show the break before sealing it in vermilion.
		add_fracture("end:%d" % crack_serial)
		if is_inside_tree():
			await get_tree().create_timer(ERROR_SHATTER_MSEC / 1000.0).timeout
		heal_open_cracks(VERMILION)
	else:
		heal_open_cracks(VERMILION)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and not cracks_are_idle():
		await get_tree().process_frame
	pass


func on_turn_start(_session_id: int) -> void:
	turn_repaired = false
	pass


func on_turn_end(_session_id: int) -> void:
	heal_open_cracks(GOLD)
	if not turn_repaired:
		add_hairline("turn:%d" % crack_serial)
	turn_repaired = false
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	crackle = maxf(crackle, CRACKLE_PULSE)
	crackle_seed = float(absi(tool_call_id.hash()) % 997)
	idle_shader_applied = false
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if result.is_error:
		add_fracture(tool_call_id)
	else:
		heal_open_cracks(GOLD)
	pass


func _process(delta: float) -> void:
	if not visible:
		idle_shader_applied = false
		return
	step_cracks(delta)
	if cracks_are_idle():
		if idle_shader_applied:
			return
		idle_shader_applied = true
	else:
		idle_shader_applied = false
	apply_shader_state()
	pass


func add_fracture(key: String) -> Crack:
	make_room_for_fracture()
	var rng := crack_rng(key)
	var crack := Crack.new()
	crack.center = pick_center(rng)
	crack.radius = rng.randf_range(FRACTURE_RADIUS_MIN, FRACTURE_RADIUS_MAX)
	crack.noise_seed = rng.randf()
	crack.shard_count = rng.randi_range(SHARD_COUNT_MIN, SHARD_COUNT_MAX)
	crack.open_target = 1.0
	crack.impact = 1.0
	shake = 1.0
	cracks.append(crack)
	idle_shader_applied = false
	return crack


## Returns null when every slot is taken: hairlines never evict earlier seams.
func add_hairline(key: String) -> Crack:
	if cracks.size() >= MAX_CRACKS:
		return null
	var rng := crack_rng(key)
	var crack := Crack.new()
	crack.center = pick_center(rng)
	crack.radius = rng.randf_range(HAIRLINE_RADIUS_MIN, HAIRLINE_RADIUS_MAX)
	crack.noise_seed = rng.randf()
	crack.shard_count = HAIRLINE_SHARD_COUNT
	crack.flowing = true
	cracks.append(crack)
	idle_shader_applied = false
	return crack


## Evicts the oldest hairline first, then the oldest healed crack, then the oldest crack.
func make_room_for_fracture() -> void:
	if cracks.size() < MAX_CRACKS:
		return
	var evict_index := 0
	var healed_index := -1
	for index in range(cracks.size()):
		var crack := cracks[index]
		if crack.shard_count <= HAIRLINE_SHARD_COUNT:
			healed_index = index
			break
		if healed_index < 0 and crack.open_target <= 0.0:
			healed_index = index
	if healed_index >= 0:
		evict_index = healed_index
	cracks.remove_at(evict_index)
	pass


## Snaps every open crack shut and starts its lacquer flow. Returns the number healed.
func heal_open_cracks(vermilion: float) -> int:
	var healed := 0
	for crack: Crack in cracks:
		if crack.open_target <= 0.0:
			continue
		crack.open_target = 0.0
		crack.flow = 0.0
		crack.flowing = true
		crack.vermilion = vermilion
		healed += 1
	if healed > 0:
		turn_repaired = true
		idle_shader_applied = false
	return healed


func has_open_crack() -> bool:
	for crack: Crack in cracks:
		if crack.open_target > 0.0:
			return true
	return false


func crack_rng(key: String) -> RandomNumberGenerator:
	crack_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#%d" % [key, crack_serial])
	return rng


## Picks the candidate farthest from existing cracks so seams spread over the body.
func pick_center(rng: RandomNumberGenerator) -> Vector2:
	var aspect := size.x / size.y if size.y > 0.0 else DEFAULT_ASPECT
	var top := clampf(float(AgentLayout.TOOLBAR_HEIGHT) / size.y, 0.0, 0.3) if size.y > 0.0 else 0.06
	var best := Vector2(0.5, 0.5)
	var best_score := -1.0
	for _index in range(PLACEMENT_CANDIDATES):
		var candidate := Vector2(rng.randf_range(0.14, 0.86), rng.randf_range(top + 0.12, 0.86))
		var score := 10.0
		for crack: Crack in cracks:
			score = minf(score, ((candidate - crack.center) * Vector2(aspect, 1.0)).length())
		if score > best_score:
			best_score = score
			best = candidate
	return best


func step_cracks(delta: float) -> void:
	var safe_delta := minf(delta, 1.0 / 20.0)
	for crack: Crack in cracks:
		var spring := step_spring(crack.open, crack.velocity, crack.open_target, safe_delta)
		crack.open = spring.x
		crack.velocity = spring.y
		if absf(crack.open - crack.open_target) < IDLE_EPSILON and absf(crack.velocity) < IDLE_EPSILON * 10.0:
			crack.open = crack.open_target
			crack.velocity = 0.0
		if crack.flowing:
			crack.flow = minf(crack.flow + LACQUER_FLOW_PER_SECOND * safe_delta, 1.0)
			crack.flowing = crack.flow < 1.0
		crack.impact = move_toward(crack.impact, 0.0, IMPACT_DECAY_PER_SECOND * safe_delta)
	crackle = move_toward(crackle, 0.0, CRACKLE_DECAY_PER_SECOND * safe_delta)
	shake = move_toward(shake, 0.0, SHAKE_DECAY_PER_SECOND * safe_delta)
	shake_offset = Vector2.from_angle(randf() * TAU) * shake * shake * SHAKE_PX if shake > 0.0 else Vector2.ZERO
	pass


func cracks_are_idle() -> bool:
	if crackle > 0.0 or shake > 0.0:
		return false
	for crack: Crack in cracks:
		if crack.impact > 0.0 or crack.flowing or crack.open != crack.open_target or crack.velocity != 0.0:
			return false
	return true


func apply_shader_state() -> void:
	if kintsugi_material == null:
		return
	var shapes := PackedVector4Array()
	var states := PackedVector4Array()
	var effects := PackedVector4Array()
	shapes.resize(MAX_CRACKS)
	states.resize(MAX_CRACKS)
	effects.resize(MAX_CRACKS)
	for index in range(mini(cracks.size(), MAX_CRACKS)):
		var crack := cracks[index]
		shapes[index] = Vector4(crack.center.x, crack.center.y, crack.radius, crack.noise_seed)
		states[index] = Vector4(crack.open, crack.flow, crack.vermilion, float(crack.shard_count))
		effects[index] = Vector4(crack.impact, 0.0, 0.0, 0.0)
	kintsugi_material.set_shader_parameter("crack_count", mini(cracks.size(), MAX_CRACKS))
	kintsugi_material.set_shader_parameter("crack_shape", shapes)
	kintsugi_material.set_shader_parameter("crack_state", states)
	kintsugi_material.set_shader_parameter("crack_fx", effects)
	kintsugi_material.set_shader_parameter("shake_px", shake_offset)
	kintsugi_material.set_shader_parameter("crackle", crackle)
	kintsugi_material.set_shader_parameter("crackle_seed", crackle_seed)
	pass


func update_theme_presentation() -> void:
	if kintsugi_material == null:
		return
	if ThemeColor.is_dark_theme():
		kintsugi_material.set_shader_parameter("gap_color", Color(0.02, 0.016, 0.012))
		kintsugi_material.set_shader_parameter("gold_shadow", Color(0.45, 0.28, 0.06))
		kintsugi_material.set_shader_parameter("gold_color", Color(0.93, 0.71, 0.27))
		kintsugi_material.set_shader_parameter("gold_highlight", Color(1.0, 0.95, 0.74))
		kintsugi_material.set_shader_parameter("vermilion_color", Color(0.89, 0.24, 0.14))
		kintsugi_material.set_shader_parameter("crackle_color", Color(0.86, 0.93, 1.0))
		kintsugi_material.set_shader_parameter("bloom_gain", 1.0)
	else:
		kintsugi_material.set_shader_parameter("gap_color", Color(0.10, 0.08, 0.07))
		kintsugi_material.set_shader_parameter("gold_shadow", Color(0.42, 0.26, 0.04))
		kintsugi_material.set_shader_parameter("gold_color", Color(0.78, 0.56, 0.14))
		kintsugi_material.set_shader_parameter("gold_highlight", Color(0.98, 0.84, 0.46))
		kintsugi_material.set_shader_parameter("vermilion_color", Color(0.78, 0.18, 0.10))
		kintsugi_material.set_shader_parameter("crackle_color", Color(0.32, 0.37, 0.45))
		kintsugi_material.set_shader_parameter("bloom_gain", 0.35)
	pass


func reset_cracks() -> void:
	cracks.clear()
	crackle = 0.0
	shake = 0.0
	shake_offset = Vector2.ZERO
	turn_repaired = false
	idle_shader_applied = false
	apply_shader_state()
	pass


## Damped spring integrated in substeps; returns (position, velocity). Underdamped so shards
## overshoot slightly when they snap home.
static func step_spring(value: float, velocity: float, target: float, delta: float) -> Vector2:
	var step := delta / float(SPRING_SUBSTEPS)
	for _index in range(SPRING_SUBSTEPS):
		var accel := -SPRING_STIFFNESS * (value - target) - SPRING_DAMPING * velocity
		velocity += accel * step
		value += velocity * step
	return Vector2(value, velocity)
