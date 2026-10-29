class_name Murmuration
extends VisualEffect

## Starling murmuration (鸟群): a boids flock sweeps across the interface. Streamed tokens hatch new
## birds from the window edges, reasoning tightens the flock into slow rolling waves, and answers
## stretch it into fast aligned streams. Every running tool becomes a roost the flock swirls around;
## a finished tool releases it with a burst, a failed one is a hawk that scatters the birds. At the
## end the whole flock leaves the window together.

const MAX_BIRDS := 200
const START_BIRDS := 70
const NEIGHBOR_RADIUS := 80.0
const SEPARATION_RADIUS := 20.0
const FLOCK_CENTER_WEIGHT := 0.45
const FLOCK_CENTER_RANGE := 600.0
const MIN_SPEED := 90.0
const CRUISE_SPEED := 170.0
const STREAM_SPEED := 270.0
const MAX_FORCE := 420.0
const SEPARATION_WEIGHT := 1.7
const ALIGNMENT_WEIGHT := 1.0
const COHESION_WEIGHT := 0.8
const REASONING_COHESION_WEIGHT := 1.5
const ROOST_WEIGHT := 1.2
const ROOST_SWIRL := 0.9
const HAWK_RADIUS := 220.0
const HAWK_FORCE := 1500.0
const HAWK_DECAY_PER_SECOND := 1.2
const EDGE_MARGIN := 70.0
const EDGE_FORCE := 520.0
const HATCH_COST := 0.012
const STREAM_HEAT_GAIN := 8.0
const STREAM_HEAT_DECAY_PER_SECOND := 0.5
const BIRD_LENGTH := 10.0
const LEAVE_HEADING := Vector2(0.8, -0.6)
const END_LEAVE_MSEC := 1500


var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var tags: PackedFloat32Array = PackedFloat32Array()
## tool_call_id -> Vector3(x, y, tag) in pixels.
var roosts: Dictionary[String, Vector3] = {}
## (x, y, strength, 0)
var hawks: Array[Vector4] = []
var bursts: Array[Vector4] = []
var running: bool = false
var leaving: bool = false
var reasoning: bool = false
var stream_heat: float = 0.0
var hatch_charge: float = 0.0
var grid_heads: PackedInt32Array = PackedInt32Array()
var grid_next: PackedInt32Array = PackedInt32Array()
var grid_columns: int = 1
var grid_rows: int = 1
var accent_color: Color = Color(0.5, 0.7, 1.0)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	gdf.events.theme_changed.connect(sync_palette)
	gdf.events.theme_color_changed.connect(sync_palette)
	sync_palette()
	pass


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	positions.clear()
	velocities.clear()
	tags.clear()
	roosts.clear()
	hawks.clear()
	bursts.clear()
	running = true
	leaving = false
	reasoning = false
	stream_heat = 0.0
	hatch_charge = 0.0
	sync_palette()
	var viewport := view_size()
	var center := Vector2(viewport.x * 0.3, viewport.y * 0.5)
	for _index in range(START_BIRDS):
		hatch(center + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-60.0, 60.0)), Vector2.from_angle(rng.randf_range(-0.4, 0.4)) * CRUISE_SPEED, 0.5)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	leaving = true
	roosts.clear()
	if StringUtils.is_not_blank(error_message):
		scare(view_size() * 0.5, true)
	if not is_inside_tree():
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_LEAVE_MSEC and count_visible() > 0:
		await get_tree().process_frame
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
		stream_heat = minf(stream_heat + energy * STREAM_HEAT_GAIN, 1.0)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var anchor := SimulationEffect.tool_anchor(tool_name) * view_size()
	roosts[tool_call_id] = Vector3(anchor.x, anchor.y, float(absi(tool_name.hash()) % 1000) / 1000.0)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var anchor := SimulationEffect.tool_anchor(tool_name) * view_size()
	roosts.erase(tool_call_id)
	scare(anchor, result.is_error)
	pass


## A burst ring at [param point]; a failure also sends a hawk the flock flees from.
func scare(point: Vector2, failed: bool) -> void:
	bursts.append(Vector4(point.x, point.y, 0.0, 1.0 if failed else 0.0))
	hawks.append(Vector4(point.x, point.y, 1.0 if failed else 0.45, 0.0))
	pass


func hatch(position: Vector2, velocity: Vector2, tag: float) -> bool:
	if positions.size() >= MAX_BIRDS:
		return false
	positions.append(position)
	velocities.append(velocity)
	tags.append(tag)
	return true


func hatch_from_edge() -> void:
	var viewport := view_size()
	var top := float(AgentLayout.TOOLBAR_HEIGHT)
	var y := rng.randf_range(top + 40.0, viewport.y - 40.0)
	var from_left := rng.randf() < 0.5
	var position := Vector2(-8.0 if from_left else viewport.x + 8.0, y)
	var heading := Vector2(1.0 if from_left else -1.0, rng.randf_range(-0.3, 0.3)).normalized()
	hatch(position, heading * CRUISE_SPEED, rng.randf_range(0.35, 0.65))
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func count_visible() -> int:
	var viewport := view_size()
	var count := 0
	for position: Vector2 in positions:
		if position.x > -20.0 and position.y > -20.0 and position.x < viewport.x + 20.0 and position.y < viewport.y + 20.0:
			count += 1
	return count


func _process(delta: float) -> void:
	if not visible:
		return
	step_flock(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func step_flock(delta: float) -> void:
	stream_heat = move_toward(stream_heat, 0.0, STREAM_HEAT_DECAY_PER_SECOND * delta)
	while running and hatch_charge >= HATCH_COST:
		hatch_charge -= HATCH_COST
		hatch_from_edge()
	for index in range(hawks.size() - 1, -1, -1):
		var hawk := hawks[index]
		hawk.z = move_toward(hawk.z, 0.0, HAWK_DECAY_PER_SECOND * delta)
		if hawk.z <= 0.0:
			hawks.remove_at(index)
		else:
			hawks[index] = hawk
	for index in range(bursts.size() - 1, -1, -1):
		var burst := bursts[index]
		burst.z += delta * 1.6
		if burst.z >= 1.0:
			bursts.remove_at(index)
		else:
			bursts[index] = burst
	build_grid()
	var target_speed := lerpf(CRUISE_SPEED, STREAM_SPEED, stream_heat) * (0.75 if reasoning else 1.0)
	var cohesion_weight := REASONING_COHESION_WEIGHT if reasoning else COHESION_WEIGHT
	var next_velocities := velocities.duplicate()
	var centroid := flock_centroid()
	for index in range(positions.size()):
		var steer := flock_force(index, cohesion_weight) + roost_force(index) + hawk_force(index) + edge_force(index)
		if not leaving:
			steer += (centroid - positions[index]).limit_length(FLOCK_CENTER_RANGE) / FLOCK_CENTER_RANGE * CRUISE_SPEED * FLOCK_CENTER_WEIGHT
		if leaving:
			steer += (LEAVE_HEADING.normalized() * STREAM_SPEED - velocities[index]) * 2.0
		steer = steer.limit_length(MAX_FORCE * (2.0 if leaving else 1.0))
		var velocity := velocities[index] + steer * delta
		var speed := velocity.length()
		var wanted := STREAM_SPEED * 1.4 if leaving else target_speed
		speed = clampf(lerpf(speed, wanted, 0.6 * delta), MIN_SPEED, STREAM_SPEED * 1.6)
		next_velocities[index] = velocity.normalized() * speed if velocity.length_squared() > 0.0001 else Vector2.RIGHT * speed
	velocities = next_velocities
	for index in range(positions.size()):
		positions[index] += velocities[index] * delta
	pass


func flock_centroid() -> Vector2:
	if positions.is_empty():
		return view_size() * 0.5
	var sum := Vector2.ZERO
	for position in positions:
		sum += position
	return sum / float(positions.size())


func flock_force(index: int, cohesion_weight: float) -> Vector2:
	var position := positions[index]
	var separation := Vector2.ZERO
	var alignment := Vector2.ZERO
	var cohesion := Vector2.ZERO
	var neighbors := 0
	var cell := grid_cell(position)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cx := cell.x + dx
			var cy := cell.y + dy
			if cx < 0 or cy < 0 or cx >= grid_columns or cy >= grid_rows:
				continue
			var other := grid_heads[cx + cy * grid_columns]
			while other >= 0:
				if other != index:
					var offset := positions[other] - position
					var distance_squared := offset.length_squared()
					if distance_squared < NEIGHBOR_RADIUS * NEIGHBOR_RADIUS:
						neighbors += 1
						alignment += velocities[other]
						cohesion += positions[other]
						if distance_squared < SEPARATION_RADIUS * SEPARATION_RADIUS and distance_squared > 0.0001:
							separation -= offset / distance_squared * SEPARATION_RADIUS
				other = grid_next[other]
	if neighbors == 0:
		return Vector2.ZERO
	var velocity := velocities[index]
	alignment = (alignment / float(neighbors)).normalized() * CRUISE_SPEED - velocity
	cohesion = (cohesion / float(neighbors) - position).limit_length(NEIGHBOR_RADIUS) / NEIGHBOR_RADIUS * CRUISE_SPEED
	return separation * SEPARATION_WEIGHT * 60.0 + alignment * ALIGNMENT_WEIGHT + cohesion * cohesion_weight


## Pulls toward the nearest roost and circles it, so each tool gathers a swirling ball.
func roost_force(index: int) -> Vector2:
	if roosts.is_empty():
		return Vector2.ZERO
	var position := positions[index]
	var nearest := Vector2.ZERO
	var best := INF
	for roost: Vector3 in roosts.values():
		var distance := position.distance_squared_to(Vector2(roost.x, roost.y))
		if distance < best:
			best = distance
			nearest = Vector2(roost.x, roost.y)
	var offset := nearest - position
	var distance := maxf(offset.length(), 1.0)
	var toward := offset / distance
	var swirl := toward.orthogonal()
	var pull := clampf((distance - 60.0) / 200.0, -0.4, 1.0)
	return (toward * pull + swirl * ROOST_SWIRL) * CRUISE_SPEED * ROOST_WEIGHT


func hawk_force(index: int) -> Vector2:
	var force := Vector2.ZERO
	for hawk: Vector4 in hawks:
		var offset := positions[index] - Vector2(hawk.x, hawk.y)
		var distance := offset.length()
		if distance < HAWK_RADIUS and distance > 0.001:
			force += offset / distance * HAWK_FORCE * hawk.z * (1.0 - distance / HAWK_RADIUS)
	return force


func edge_force(index: int) -> Vector2:
	if leaving:
		return Vector2.ZERO
	var viewport := view_size()
	var top := float(AgentLayout.TOOLBAR_HEIGHT)
	var position := positions[index]
	var force := Vector2.ZERO
	if position.x < EDGE_MARGIN:
		force.x += EDGE_FORCE * (1.0 - position.x / EDGE_MARGIN)
	elif position.x > viewport.x - EDGE_MARGIN:
		force.x -= EDGE_FORCE * (1.0 - (viewport.x - position.x) / EDGE_MARGIN)
	if position.y < top + EDGE_MARGIN:
		force.y += EDGE_FORCE * (1.0 - (position.y - top) / EDGE_MARGIN)
	elif position.y > viewport.y - EDGE_MARGIN:
		force.y -= EDGE_FORCE * (1.0 - (viewport.y - position.y) / EDGE_MARGIN)
	return force


## Buckets birds into a uniform grid of neighbor-radius cells as linked lists.
func build_grid() -> void:
	var viewport := view_size()
	grid_columns = maxi(1, ceili(viewport.x / NEIGHBOR_RADIUS))
	grid_rows = maxi(1, ceili(viewport.y / NEIGHBOR_RADIUS))
	grid_heads.resize(grid_columns * grid_rows)
	grid_heads.fill(-1)
	grid_next.resize(positions.size())
	for index in range(positions.size()):
		var cell := grid_cell(positions[index])
		var slot := cell.x + cell.y * grid_columns
		grid_next[index] = grid_heads[slot]
		grid_heads[slot] = index
	pass


func grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(position.x / NEIGHBOR_RADIUS), 0, grid_columns - 1), clampi(floori(position.y / NEIGHBOR_RADIUS), 0, grid_rows - 1))


func _draw() -> void:
	for index in range(positions.size()):
		var position := positions[index]
		var heading := velocities[index].normalized()
		var side := heading.orthogonal()
		var speed_share := clampf(velocities[index].length() / STREAM_SPEED, 0.4, 1.4)
		var color := bird_color(tags[index])
		var nose := position + heading * BIRD_LENGTH
		var tail := position - heading * BIRD_LENGTH * 0.6
		var points := PackedVector2Array([nose, tail + side * 3.2, position - heading * BIRD_LENGTH * 0.2, tail - side * 3.2])
		draw_line(tail, tail - heading * BIRD_LENGTH * 1.6 * speed_share, VisualColor.stroke(color, 0.18), 1.2, true)
		draw_colored_polygon(points, VisualColor.stroke(color, 0.85))
	for roost: Vector3 in roosts.values():
		var center := Vector2(roost.x, roost.y)
		draw_arc(center, 14.0, 0.0, TAU, 32, VisualColor.stroke(bird_color(roost.z), 0.4), 1.5, true)
	for burst: Vector4 in bursts:
		var burst_color := Colors.error if burst.w > 0.5 else accent_color
		draw_arc(Vector2(burst.x, burst.y), 12.0 + burst.z * 90.0, 0.0, TAU, 48, VisualColor.stroke(burst_color, 0.5 * (1.0 - burst.z)), 2.0, true)
	pass


func bird_color(tag: float) -> Color:
	return accent_color if absf(tag - 0.5) < 0.16 else VisualColor.appearance_color(ThemeColor.accent_theme_color(), (tag - 0.5) * 0.5)


func sync_palette() -> void:
	accent_color = VisualColor.appearance_color(ThemeColor.accent_theme_color())
	pass
