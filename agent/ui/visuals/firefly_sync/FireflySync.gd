class_name FireflySync
extends VisualEffect

## Firefly synchrony (萤火虫同步): a swarm of fireflies blinks over the interface, each one a
## Kuramoto oscillator coupled only to its neighbors. The run starts as scattered twinkles;
## streamed text hatches newcomers with random phases, while every finished message and successful
## tool strengthens the coupling so patches lock together and the rhythm spreads. A running tool
## hangs a lantern that pulses as a pacemaker and gathers a synchronized cluster; a failed tool
## scatters the nearby phases in red. A successful run ends with the whole swarm flashing as one.

const MAX_FLIES := 160
const START_FLIES := 90
const BASE_FREQUENCY_HZ := 0.42
const FREQUENCY_SPREAD_HZ := 0.1
## Side of a neighbor cell; each firefly couples to the 3x3 cells around its own.
const COUPLING_RADIUS := 150.0
const START_COUPLING := 0.3
const MAX_COUPLING := 3.2
const SUCCESS_COUPLING_STEP := 0.35
const MESSAGE_COUPLING_STEP := 0.12
const STREAM_COUPLING_GAIN := 0.6
const ERROR_COUPLING_SCALE := 0.75
const ERROR_RADIUS := 260.0
const ERROR_KICK_SPEED := 140.0
const LANTERN_RADIUS := 230.0
const LANTERN_COUPLING := 2.4
const LANTERN_ORBIT := 70.0
const LANTERN_PULL := 60.0
const FINALE_COUPLING := 8.0
const FINALE_COHERENCE := 0.93
const FINALE_LIMIT_MSEC := 2600
const FINALE_HOLD_MSEC := 320
const ERROR_END_MSEC := 600
## A firefly brightens before phase zero, then fades more slowly after the peak.
const FLASH_RISE_WIDTH := 1.35
const FLASH_FADE_WIDTH := 2.25
const REST_GLOW := 0.1
const MIN_SIZE_SCALE := 0.65
const MAX_SIZE_SCALE := 1.35
const WANDER_ACCEL := 60.0
const CRUISE_SPEED := 34.0
const REASONING_SPEED_SCALE := 0.55
const SPEED_RECOVERY := 80.0
const EDGE_MARGIN := 50.0
const EDGE_FORCE := 60.0
const HATCH_COST := 0.03
const BURST_PER_SECOND := 1.4
const RED_DECAY_PER_SECOND := 0.5
const FAILURE_DECAY_PER_SECOND := 0.7
const BLOOM_DECAY_PER_SECOND := 0.8
const FIREFLY_COLOR := Color(0.8, 1.0, 0.38)


class Lantern extends RefCounted:
	var key: String
	var center: Vector2
	var phase: float


var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var phases: PackedFloat32Array = PackedFloat32Array()
var frequencies: PackedFloat32Array = PackedFloat32Array()
var hues: PackedFloat32Array = PackedFloat32Array()
var size_scales: PackedFloat32Array = PackedFloat32Array()
var reds: PackedFloat32Array = PackedFloat32Array()
var lanterns: Array[Lantern] = []
## (x, y, progress, failed)
var bursts: Array[Vector4] = []
var coupling: float = START_COUPLING
var running: bool = false
var reasoning: bool = false
var finale: bool = false
var finale_flashes: int = 0
var finale_bloom: float = 0.0
var mean_phase: float = 0.0
var hatch_charge: float = 0.0
var failure_tint: float = 0.0
var cell_sums: PackedVector2Array = PackedVector2Array()
var cell_counts: PackedInt32Array = PackedInt32Array()
var grid_columns: int = 1
var grid_rows: int = 1
var fly_color: Color = FIREFLY_COLOR
var lantern_color: Color = Color(0.5, 0.7, 1.0)
var glow_material: CanvasItemMaterial
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	glow_material = CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gdf.events.theme_changed.connect(sync_palette)
	gdf.events.theme_color_changed.connect(sync_palette)
	sync_palette()
	pass


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	positions.clear()
	velocities.clear()
	phases.clear()
	frequencies.clear()
	hues.clear()
	size_scales.clear()
	reds.clear()
	lanterns.clear()
	bursts.clear()
	coupling = START_COUPLING
	running = true
	reasoning = false
	finale = false
	finale_flashes = 0
	finale_bloom = 0.0
	hatch_charge = 0.0
	failure_tint = 0.0
	for _index in range(START_FLIES):
		hatch_random()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	lanterns.clear()
	if StringUtils.is_not_blank(error_message):
		failure_tint = 1.0
		coupling = START_COUPLING
		scatter(view_size() * 0.5, INF)
		if is_inside_tree():
			await get_tree().create_timer(ERROR_END_MSEC / 1000.0).timeout
		return
	finale = true
	finale_flashes = 0
	coupling = MAX_COUPLING
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < FINALE_LIMIT_MSEC and finale_flashes == 0:
		await get_tree().process_frame
	await get_tree().create_timer(FINALE_HOLD_MSEC / 1000.0).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	reasoning = false
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	hatch_charge += energy
	if not reasoning:
		coupling = minf(coupling + energy * STREAM_COUPLING_GAIN, MAX_COUPLING)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	coupling = minf(coupling + MESSAGE_COUPLING_STEP, MAX_COUPLING)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if find_lantern(tool_call_id) != null:
		return
	var lantern := Lantern.new()
	lantern.key = tool_call_id
	lantern.center = SimulationEffect.tool_anchor(tool_name) * view_size()
	lantern.phase = mean_phase
	lanterns.append(lantern)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var lantern := find_lantern(tool_call_id)
	var center := lantern.center if lantern != null else SimulationEffect.tool_anchor(tool_name) * view_size()
	lanterns.erase(lantern)
	bursts.append(Vector4(center.x, center.y, 0.0, 1.0 if result.is_error else 0.0))
	if result.is_error:
		failure_tint = 1.0
		coupling = maxf(coupling * ERROR_COUPLING_SCALE, START_COUPLING)
		scatter(center, ERROR_RADIUS)
	else:
		coupling = minf(coupling + SUCCESS_COUPLING_STEP, MAX_COUPLING)
	pass


func find_lantern(key: String) -> Lantern:
	for lantern: Lantern in lanterns:
		if lantern.key == key:
			return lantern
	return null


## Randomizes phases within [param radius] of [param center], kicks those fireflies outward, and
## marks them red.
func scatter(center: Vector2, radius: float) -> void:
	for index in range(positions.size()):
		var offset := positions[index] - center
		if offset.length() > radius:
			continue
		phases[index] = rng.randf() * TAU
		reds[index] = 1.0
		var heading := offset.normalized() if offset.length_squared() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
		velocities[index] = heading * ERROR_KICK_SPEED
	pass


func hatch(position: Vector2, phase: float) -> bool:
	if positions.size() >= MAX_FLIES:
		return false
	positions.append(position)
	velocities.append(Vector2.from_angle(rng.randf() * TAU) * CRUISE_SPEED * rng.randf())
	phases.append(phase)
	frequencies.append(TAU * (BASE_FREQUENCY_HZ + rng.randf_range(-FREQUENCY_SPREAD_HZ, FREQUENCY_SPREAD_HZ)))
	hues.append(rng.randf_range(-0.04, 0.04))
	size_scales.append(rng.randf_range(MIN_SIZE_SCALE, MAX_SIZE_SCALE))
	reds.append(0.0)
	return true


func hatch_random() -> void:
	var viewport := view_size()
	var top := float(AgentLayout.TOOLBAR_HEIGHT) + EDGE_MARGIN
	hatch(Vector2(rng.randf_range(EDGE_MARGIN, viewport.x - EDGE_MARGIN), rng.randf_range(top, viewport.y - EDGE_MARGIN)), rng.randf() * TAU)
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func _process(delta: float) -> void:
	if not visible:
		return
	step_swarm(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func step_swarm(delta: float) -> void:
	failure_tint = move_toward(failure_tint, 0.0, FAILURE_DECAY_PER_SECOND * delta)
	finale_bloom = move_toward(finale_bloom, 0.0, BLOOM_DECAY_PER_SECOND * delta)
	while running and hatch_charge >= HATCH_COST:
		hatch_charge -= HATCH_COST
		hatch_random()
	for lantern: Lantern in lanterns:
		lantern.phase = fposmod(lantern.phase + TAU * BASE_FREQUENCY_HZ * delta, TAU)
	for index in range(bursts.size() - 1, -1, -1):
		var burst := bursts[index]
		burst.z += BURST_PER_SECOND * delta
		if burst.z >= 1.0:
			bursts.remove_at(index)
		else:
			bursts[index] = burst
	if positions.is_empty():
		return
	build_grid()
	var global := order_vector()
	step_phases(delta, global)
	track_finale(global)
	step_motion(delta)
	pass


## Kuramoto step: each phase is pulled by coupling * mean(sin(neighbor - self)), plus any lantern
## pacemakers in reach and, during the finale, the mean field of the whole swarm.
func step_phases(delta: float, global: Vector2) -> void:
	var next_phases := phases.duplicate()
	for index in range(phases.size()):
		var phase := phases[index]
		var drive := frequencies[index]
		var local := local_field(index)
		drive += coupling * (local.y * cos(phase) - local.x * sin(phase))
		if finale:
			drive += FINALE_COUPLING * (global.y * cos(phase) - global.x * sin(phase))
		for lantern: Lantern in lanterns:
			var distance := positions[index].distance_to(lantern.center)
			if distance < LANTERN_RADIUS:
				drive += LANTERN_COUPLING * (1.0 - distance / LANTERN_RADIUS) * sin(lantern.phase - phase)
		next_phases[index] = fposmod(phase + drive * delta, TAU)
		reds[index] = move_toward(reds[index], 0.0, RED_DECAY_PER_SECOND * delta)
	phases = next_phases
	pass


## Counts a unison flash each time the coherent swarm's mean phase wraps past zero.
func track_finale(previous_global: Vector2) -> void:
	var previous_phase := fposmod(previous_global.angle(), TAU)
	var global := order_vector()
	mean_phase = fposmod(global.angle(), TAU)
	if finale and global.length() >= FINALE_COHERENCE and previous_phase > PI * 1.5 and mean_phase < PI * 0.5:
		finale_flashes += 1
		finale_bloom = 1.0
	pass


func step_motion(delta: float) -> void:
	var cruise := CRUISE_SPEED * (REASONING_SPEED_SCALE if reasoning else 1.0)
	for index in range(positions.size()):
		var velocity := velocities[index] + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * WANDER_ACCEL * delta
		velocity += (lantern_force(index) + edge_force(index)) * delta
		if velocity.length() > cruise:
			velocity = velocity.move_toward(velocity.normalized() * cruise, SPEED_RECOVERY * delta)
		velocities[index] = velocity
		positions[index] += velocity * delta
	pass


## Pulls toward the nearest lantern in reach and circles it at [constant LANTERN_ORBIT].
func lantern_force(index: int) -> Vector2:
	var position := positions[index]
	var nearest: Lantern = null
	var best := LANTERN_RADIUS * 1.4
	for lantern: Lantern in lanterns:
		var distance := position.distance_to(lantern.center)
		if distance < best:
			best = distance
			nearest = lantern
	if nearest == null:
		return Vector2.ZERO
	var offset := nearest.center - position
	var toward := offset / maxf(best, 1.0)
	var pull := clampf((best - LANTERN_ORBIT) / LANTERN_RADIUS, -0.5, 1.0)
	return (toward * pull + toward.orthogonal() * 0.5) * LANTERN_PULL


func edge_force(index: int) -> Vector2:
	var viewport := view_size()
	var top := float(AgentLayout.TOOLBAR_HEIGHT)
	var position := positions[index]
	var force := Vector2.ZERO
	if position.x < EDGE_MARGIN:
		force.x += EDGE_FORCE
	elif position.x > viewport.x - EDGE_MARGIN:
		force.x -= EDGE_FORCE
	if position.y < top + EDGE_MARGIN:
		force.y += EDGE_FORCE
	elif position.y > viewport.y - EDGE_MARGIN:
		force.y -= EDGE_FORCE
	return force


## Sums (cos, sin) of every phase into a uniform grid of [constant COUPLING_RADIUS] cells.
func build_grid() -> void:
	var viewport := view_size()
	grid_columns = maxi(1, ceili(viewport.x / COUPLING_RADIUS))
	grid_rows = maxi(1, ceili(viewport.y / COUPLING_RADIUS))
	cell_sums.resize(grid_columns * grid_rows)
	cell_sums.fill(Vector2.ZERO)
	cell_counts.resize(grid_columns * grid_rows)
	cell_counts.fill(0)
	for index in range(positions.size()):
		var slot := grid_slot(positions[index])
		cell_sums[slot] += Vector2(cos(phases[index]), sin(phases[index]))
		cell_counts[slot] += 1
	pass


func grid_slot(position: Vector2) -> int:
	var cx := clampi(floori(position.x / COUPLING_RADIUS), 0, grid_columns - 1)
	var cy := clampi(floori(position.y / COUPLING_RADIUS), 0, grid_rows - 1)
	return cx + cy * grid_columns


## Mean (cos, sin) of the neighbors in the surrounding 3x3 cells, excluding the firefly itself.
func local_field(index: int) -> Vector2:
	var slot := grid_slot(positions[index])
	var cx := slot % grid_columns
	var cy := slot / grid_columns
	var sum := -Vector2(cos(phases[index]), sin(phases[index]))
	var count := -1
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= grid_columns or y >= grid_rows:
				continue
			sum += cell_sums[x + y * grid_columns]
			count += cell_counts[x + y * grid_columns]
	return sum / float(count) if count > 0 else Vector2.ZERO


## Kuramoto order parameter as a vector: its length is coherence (0 scattered, 1 in unison) and
## its angle is the swarm's mean phase.
func order_vector() -> Vector2:
	if phases.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for phase: float in phases:
		sum += Vector2(cos(phase), sin(phase))
	return sum / float(phases.size())


func coherence() -> float:
	return order_vector().length()


static func flash_amount(phase: float) -> float:
	var offset := wrapf(phase + PI, 0.0, TAU) - PI
	if offset < 0.0:
		return smoothstep(-FLASH_RISE_WIDTH, 0.0, offset)
	return 1.0 - smoothstep(0.0, FLASH_FADE_WIDTH, offset)


func _draw() -> void:
	var bloom := 1.0 + 0.4 * finale_bloom
	for index in range(positions.size()):
		var flash := maxf(flash_amount(phases[index]), finale_bloom)
		var glow := REST_GLOW + (1.0 - REST_GLOW) * flash
		var color := VisualColor.shift_hsv(fly_color, hues[index]).lerp(Colors.error, maxf(reds[index], failure_tint * 0.5))
		var position := positions[index]
		var size_scale := size_scales[index]
		draw_circle(position, (5.0 + 22.0 * flash) * bloom * size_scale, VisualColor.stroke(color, 0.16 * glow), true, -1.0, true)
		draw_circle(position, (2.4 + 4.0 * flash) * size_scale, VisualColor.stroke(color, 0.5 * glow), true, -1.0, true)
		draw_circle(position, 1.6 * size_scale, VisualColor.stroke(color.lerp(Color.WHITE, 0.5 * flash), 0.3 + 0.6 * glow), true, -1.0, true)
	for lantern: Lantern in lanterns:
		var pulse := flash_amount(lantern.phase)
		draw_circle(lantern.center, 16.0 + 30.0 * pulse, VisualColor.stroke(lantern_color, 0.06 + 0.14 * pulse), true, -1.0, true)
		draw_arc(lantern.center, 14.0 + 6.0 * pulse, 0.0, TAU, 48, VisualColor.stroke(lantern_color, 0.35 + 0.5 * pulse), 2.0, true)
	for burst: Vector4 in bursts:
		var burst_color := Colors.error if burst.w > 0.5 else lantern_color
		draw_arc(Vector2(burst.x, burst.y), 12.0 + burst.z * 110.0, 0.0, TAU, 48, VisualColor.stroke(burst_color, 0.5 * (1.0 - burst.z)), 2.0, true)
	pass


func sync_palette() -> void:
	var dark := ThemeColor.is_dark_theme()
	fly_color = VisualColor.appearance_color(FIREFLY_COLOR)
	lantern_color = VisualColor.appearance_color(ThemeColor.accent_theme_color())
	material = glow_material if dark else null
	pass
