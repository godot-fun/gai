class_name Pipes3D
extends VisualEffect

## The Windows 3D Pipes screensaver (3D 管道屏保). Pipes grow cell by cell through a 3D grid seen
## in perspective, turning at random and capped with ball joints. The agent's own pipe grows
## with the stream and changes color every turn; every running tool lays its own colored pipe
## until it finishes, ending in a bright cap or a red burst. When the grid fills up, the screen
## clears and starts over, just like the original.

const GRID := Vector3i(22, 13, 9)
const NEAR_DEPTH := 7.0
const PIPE_RADIUS := 0.14
const JOINT_SCALE := 1.0
const CAP_SCALE := 1.3
const MAX_SEGMENTS := 300
const MAIN_SPEED := 6.0
const REASONING_SPEED := 3.5
const MAX_STREAM_SPEED := 14.0
const STREAM_SPEED_GAIN := 120.0
const STREAM_SPEED_DECAY_PER_SECOND := 8.0
const TOOL_SPEED := 10.0
const KEEP_DIRECTION_CHANCE := 0.72
const CLEAR_SECONDS := 0.7
const BURST_SECONDS := 0.6
const END_HOLD_MSEC := 450
## Let the interface remain readable beneath the pipes.
const PIPES_OPACITY := 0.38
const LIGHT_DIR := Vector2(-0.6, -0.8)
const DIRECTIONS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

enum Item { SEGMENT, BALL }


class Pipe extends RefCounted:
	var key: String
	var cell: Vector3i
	var dir: Vector3i
	var color: Color
	var step_clock: float = 0.0
	var speed: float = 0.0
	var alive: bool = true


var occupied: PackedByteArray = PackedByteArray()
var pipes: Array[Pipe] = []
var main_pipe: Pipe
## Draw list sorted far to near; parallel arrays keep inserts cheap.
var item_sort_keys: PackedFloat32Array = PackedFloat32Array()
var item_kinds: PackedInt32Array = PackedInt32Array()
var item_from: PackedVector3Array = PackedVector3Array()
var item_to: PackedVector3Array = PackedVector3Array()
var item_scales: PackedFloat32Array = PackedFloat32Array()
var item_colors: PackedColorArray = PackedColorArray()
var segment_count: int = 0
var running: bool = false
var reasoning: bool = false
var stream_speed: float = 0.0
var turn_index: int = 0
var clear_fade: float = 0.0
## (screen position x, y, age seconds, error flag)
var bursts: Array[Vector4] = []
var rng := RandomNumberGenerator.new()


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	running = true
	reasoning = false
	stream_speed = 0.0
	turn_index = 0
	bursts.clear()
	clear_grid()
	pipes.clear()
	main_pipe = spawn_pipe("main", main_color(0), MAIN_SPEED)
	queue_redraw()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	running = false
	for pipe: Pipe in pipes:
		end_pipe(pipe, StringUtils.is_not_blank(error_message) and pipe == main_pipe)
	pipes.clear()
	main_pipe = null
	queue_redraw()
	if not is_inside_tree():
		return
	await get_tree().create_timer(END_HOLD_MSEC / 1000.0).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	turn_index += 1
	reasoning = false
	if main_pipe != null:
		end_pipe(main_pipe, false)
		pipes.erase(main_pipe)
	main_pipe = spawn_pipe("main", main_color(turn_index), MAIN_SPEED)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	reasoning = stream_kind == OpenAiClient.STREAM_KIND_REASONING
	if not reasoning:
		stream_speed = minf(stream_speed + SimulationEffect.stream_energy_for_length(chunk.length()) * STREAM_SPEED_GAIN, MAX_STREAM_SPEED)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if find_pipe(tool_call_id) != null:
		return
	spawn_pipe(tool_call_id, tool_color(tool_name), TOOL_SPEED)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	var pipe := find_pipe(tool_call_id)
	if pipe == null:
		return
	end_pipe(pipe, result.is_error)
	pipes.erase(pipe)
	pass


func find_pipe(key: String) -> Pipe:
	for pipe: Pipe in pipes:
		if pipe.key == key:
			return pipe
	return null


func spawn_pipe(key: String, color: Color, speed: float) -> Pipe:
	var pipe := Pipe.new()
	pipe.key = key
	pipe.color = color
	pipe.speed = speed
	pipe.cell = pick_free_cell()
	pipe.dir = DIRECTIONS[rng.randi() % DIRECTIONS.size()]
	pipe.alive = pipe.cell.x >= 0
	if pipe.alive:
		set_occupied(pipe.cell)
		add_item(Item.BALL, cell_position(pipe.cell), cell_position(pipe.cell), JOINT_SCALE, color)
	pipes.append(pipe)
	return pipe


func end_pipe(pipe: Pipe, failed: bool) -> void:
	if not pipe.alive:
		return
	pipe.alive = false
	var cap_color := Colors.error if failed else pipe.color.lerp(Color.WHITE, 0.25)
	add_item(Item.BALL, cell_position(pipe.cell), cell_position(pipe.cell), CAP_SCALE, cap_color)
	var screen := project(cell_position(pipe.cell))
	bursts.append(Vector4(screen.x, screen.y, 0.0, 1.0 if failed else 0.0))
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_pipes(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func step_pipes(delta: float) -> void:
	stream_speed = move_toward(stream_speed, 0.0, STREAM_SPEED_DECAY_PER_SECOND * delta)
	for index in range(bursts.size() - 1, -1, -1):
		var burst := bursts[index]
		burst.z += delta
		if burst.z > BURST_SECONDS:
			bursts.remove_at(index)
		else:
			bursts[index] = burst
	if clear_fade > 0.0:
		clear_fade = move_toward(clear_fade, 0.0, delta / CLEAR_SECONDS)
		if clear_fade <= 0.0:
			restart_grid()
		return
	if main_pipe != null:
		main_pipe.speed = (REASONING_SPEED if reasoning else MAIN_SPEED) + stream_speed
	for pipe: Pipe in pipes.duplicate():
		if not pipe.alive:
			continue
		pipe.step_clock += delta * pipe.speed
		while pipe.step_clock >= 1.0 and pipe.alive:
			pipe.step_clock -= 1.0
			grow_pipe(pipe)
		if not pipe.alive and pipe == main_pipe and running:
			pipes.erase(pipe)
			main_pipe = spawn_pipe("main", main_color(turn_index), MAIN_SPEED)
	if segment_count >= MAX_SEGMENTS:
		clear_fade = 1.0
	pass


func grow_pipe(pipe: Pipe) -> void:
	var next_dir := choose_direction(pipe)
	if next_dir == Vector3i.ZERO:
		end_pipe(pipe, false)
		return
	var from := cell_position(pipe.cell)
	var turned := next_dir != pipe.dir
	if turned:
		add_item(Item.BALL, from, from, JOINT_SCALE, pipe.color)
	pipe.dir = next_dir
	pipe.cell += next_dir
	set_occupied(pipe.cell)
	var to := cell_position(pipe.cell)
	add_item(Item.SEGMENT, from, to, 1.0, pipe.color)
	segment_count += 1
	if next_dir.z != 0:
		add_item(Item.BALL, to, to, JOINT_SCALE, pipe.color)
	pass


## Keeps going straight most of the time, otherwise turns into a random free neighbor.
## Returns zero when the pipe is boxed in.
func choose_direction(pipe: Pipe) -> Vector3i:
	if is_free(pipe.cell + pipe.dir) and rng.randf() < KEEP_DIRECTION_CHANCE:
		return pipe.dir
	var options: Array[Vector3i] = []
	for dir: Vector3i in DIRECTIONS:
		if dir != -pipe.dir and is_free(pipe.cell + dir):
			options.append(dir)
	if options.is_empty():
		return Vector3i.ZERO
	return options[rng.randi() % options.size()]


func pick_free_cell() -> Vector3i:
	for _attempt in range(64):
		var cell := Vector3i(rng.randi() % GRID.x, rng.randi() % GRID.y, rng.randi() % GRID.z)
		if is_free(cell):
			return cell
	return Vector3i(-1, -1, -1)


func is_free(cell: Vector3i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.z < 0 or cell.x >= GRID.x or cell.y >= GRID.y or cell.z >= GRID.z:
		return false
	return occupied[cell_index(cell)] == 0


func set_occupied(cell: Vector3i) -> void:
	occupied[cell_index(cell)] = 1
	pass


static func cell_index(cell: Vector3i) -> int:
	return cell.x + cell.y * GRID.x + cell.z * GRID.x * GRID.y


static func cell_position(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) - float(GRID.x - 1) * 0.5, float(cell.y) - float(GRID.y - 1) * 0.5, float(cell.z))


func add_item(kind: Item, from: Vector3, to: Vector3, scale: float, color: Color) -> void:
	# Farther items sort first; balls draw just in front of the segments that meet them.
	var key := -((from.z + to.z) * 0.5) + (0.01 if kind == Item.BALL else 0.0)
	var index := item_sort_keys.bsearch(key, false)
	item_sort_keys.insert(index, key)
	item_kinds.insert(index, kind)
	item_from.insert(index, from)
	item_to.insert(index, to)
	item_scales.insert(index, scale)
	item_colors.insert(index, color)
	pass


func clear_grid() -> void:
	occupied.resize(GRID.x * GRID.y * GRID.z)
	occupied.fill(0)
	item_sort_keys.clear()
	item_kinds.clear()
	item_from.clear()
	item_to.clear()
	item_scales.clear()
	item_colors.clear()
	segment_count = 0
	clear_fade = 0.0
	pass


## Wipes the full screen and replants every live pipe at a fresh cell.
func restart_grid() -> void:
	clear_grid()
	for pipe: Pipe in pipes:
		if not pipe.alive:
			continue
		pipe.cell = pick_free_cell()
		pipe.alive = pipe.cell.x >= 0
		if pipe.alive:
			set_occupied(pipe.cell)
			add_item(Item.BALL, cell_position(pipe.cell), cell_position(pipe.cell), JOINT_SCALE, pipe.color)
	pass


func focal_length() -> float:
	var mid_depth := NEAR_DEPTH + float(GRID.z - 1) * 0.5
	var fit_x := size.x * 0.5 * mid_depth / (float(GRID.x - 1) * 0.5 + 0.5)
	var fit_y := size.y * 0.5 * mid_depth / (float(GRID.y - 1) * 0.5 + 0.5)
	return minf(fit_x, fit_y)


func project(point: Vector3) -> Vector2:
	return size * 0.5 + Vector2(point.x, point.y) * focal_length() / (NEAR_DEPTH + point.z)


func radius_at(point: Vector3, scale: float) -> float:
	return PIPE_RADIUS * scale * focal_length() / (NEAR_DEPTH + point.z)


func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0:
		return
	var alpha := (clear_fade if clear_fade > 0.0 else 1.0) * PIPES_OPACITY
	for index in range(item_kinds.size()):
		var color := Color(item_colors[index], alpha)
		if item_kinds[index] == Item.BALL:
			draw_ball(project(item_from[index]), radius_at(item_from[index], item_scales[index]), color)
		else:
			draw_tube(item_from[index], item_to[index], color)
	for burst: Vector4 in bursts:
		var t := burst.z / BURST_SECONDS
		var burst_color := Colors.error if burst.w > 0.5 else Color.WHITE
		draw_arc(Vector2(burst.x, burst.y), 8.0 + t * 46.0, 0.0, TAU, 40, VisualColor.stroke(burst_color, 0.55 * (1.0 - t) * PIPES_OPACITY), 2.0 + 3.0 * (1.0 - t), true)
	pass


## A cylinder as three stacked strips: shadowed rim, lit body, and a specular streak.
func draw_tube(from: Vector3, to: Vector3, color: Color) -> void:
	var a := project(from)
	var b := project(to)
	var along := b - a
	if along.length_squared() < 0.25:
		return
	var normal := Vector2(-along.y, along.x).normalized()
	if normal.dot(LIGHT_DIR) < 0.0:
		normal = -normal
	var ra := radius_at(from, 1.0)
	var rb := radius_at(to, 1.0)
	draw_strip(a, b, normal, ra, rb, 0.0, 1.0, shade(color, 0.42))
	draw_strip(a, b, normal, ra, rb, 0.2, 0.62, color)
	draw_strip(a, b, normal, ra, rb, 0.5, 0.16, shade(color, 1.0).lerp(Color(1.0, 1.0, 1.0, color.a), 0.6))
	pass


func draw_strip(a: Vector2, b: Vector2, normal: Vector2, ra: float, rb: float, offset: float, half_width: float, color: Color) -> void:
	var points := PackedVector2Array([
		a + normal * ra * (offset + half_width), b + normal * rb * (offset + half_width),
		b + normal * rb * (offset - half_width), a + normal * ra * (offset - half_width),
	])
	draw_colored_polygon(points, color)
	pass


func draw_ball(center: Vector2, radius: float, color: Color) -> void:
	var light := LIGHT_DIR.normalized()
	draw_circle(center, radius, shade(color, 0.42), true, -1.0, true)
	draw_circle(center + light * radius * 0.2, radius * 0.72, color, true, -1.0, true)
	draw_circle(center + light * radius * 0.45, radius * 0.24, shade(color, 1.0).lerp(Color(1.0, 1.0, 1.0, color.a), 0.6), true, -1.0, true)
	pass


static func shade(color: Color, amount: float) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, color.a)


func main_color(turn: int) -> Color:
	var accent := ThemeColor.accent_theme_color()
	return Color.from_hsv(fposmod(accent.h + float(turn) * 0.13, 1.0), clampf(maxf(accent.s, 0.55), 0.0, 0.9), clampf(maxf(accent.v, 0.75), 0.0, 0.95))


## Stable saturated color per tool, in the spirit of the original screensaver palette.
static func tool_color(tool_name: String) -> Color:
	return Color.from_hsv(float(absi(tool_name.hash()) % 360) / 360.0, 0.72, 0.9)
