class_name Orrery
extends VisualEffect

enum Tag { RUN, TURN, THINK, WRITE, TOOL, OK, FAIL }

## Section titles of the ring tile's eight run panels, in tile order.
const PANEL_TITLES: Array[String] = [
	"agent.visuals.orrery_feed", "agent.visuals.orrery_solver", "agent.visuals.orrery_workspace", "agent.visuals.orrery_field",
	"agent.visuals.orrery_matrix", "agent.visuals.orrery_buffer", "agent.visuals.orrery_dispatch_panel", "agent.visuals.orrery_index",
]
const TAG_TEXTS: Array[String] = ["RUN", "TURN", "THINK", "WRITE", "TOOL", "OK", "FAIL"]
const MONO_FONT_NAMES: Array[String] = ["JetBrains Mono", "Cascadia Mono", "Consolas", "SF Mono", "Menlo", "DejaVu Sans Mono", "monospace"]
## Hub x, disc radius, and ring thickness as fractions of stage height at zoom 1.
const HUB_X_RATIO := 0.3
const DISC_RADIUS_RATIO := 0.42
const RING_THICKNESS_RATIO := 0.28
## Arc length of one screen tile over ring thickness; the ring repeats `ring_tiles()` tiles.
const TILE_ASPECT := 3.2
## Zoom the screen tile is rasterized for; the ring scales that texture between ZOOM_MIN and ZOOM_MAX.
const TILE_ZOOM := 1.85
const TILE_MAX_HEIGHT := 2048
const ZOOM_MIN := 1.0
const ZOOM_MAX := 1.85
const ZOOM_END := 0.8
const ZOOM_RATE := 1.1
const PULSE_SECONDS := 1.6
const PULSE_LIMIT := 48
const FINE_BEAMS := 900
const BEAM_COUNT := 90
const WEB_CURVES := 2000
## Share of web curves that live in the pulse layers rather than the static base layer.
const WEB_PULSE_SHARE := 0.3
const WEB_NODES := 70
const WEB_CHAINS := 3
const RUNNER_COUNT := 320
const COMET_LIMIT := 40
const COMET_FADE_SECONDS := 0.25
const FLASH_DECAY := 2.2
const LAYER_DECAY := 2.2
const BEAT_DECAY := 4.5
const HISTORY_SIZE := 96
const SAMPLE_SECONDS := 0.06
const HEAT_COLUMNS := 24
const HEAT_ROWS := 8
const HISTOGRAM_BINS := 20
const FEED_LIMIT := 14
const TRACK_LIMIT := 10
const SNIPPET_LENGTH := 34
const DOT_LIMIT := 150
const ENERGY_DECAY := 1.3
const STREAM_GAIN := 9.0
const HEAT_DECAY := 0.05
const END_SECONDS := 1.1
## Master opacity for strokes, panels, and the ring tile (fade-out still scales this down).
const OVERLAY_STRENGTH := 0.42
const BACKDROP_ALPHA := 0.03

class FeedLine extends RefCounted:
	var serial: int = 0
	var tag: int = Tag.RUN
	var text: String = ""


class ToolTrack extends RefCounted:
	var id: String = ""
	var name: String = ""
	var detail: String = ""
	var started: float = 0.0
	var finished: float = -1.0
	var failed: bool = false

	func is_running() -> bool:
		return finished < 0.0

	func seconds(now: float) -> float:
		return (now if finished < 0.0 else finished) - started


## A light point gliding along one web curve. Modes: 0 steady, 1 surges with `beat_env`, 2 accelerates.
class Runner extends RefCounted:
	var curve: int = 0
	var t: float = 0.0
	var speed: float = 0.2
	var mode: int = 0
	var accent: bool = false


## A bundle of parallel strokes sweeping to the ring. Arc lines are (radius, start angle, span) and
## spiral out to the rim; quad lines are (p0, control, p1) ending on the rim. Unit-disc coordinates
## in the frame of `rot0`, so the bundle follows the ring after launch.
class Comet extends RefCounted:
	var arc: bool = false
	var lines: Array[PackedFloat32Array] = []
	var life: float = 0.0
	var duration: float = 0.6
	var window: float = 0.3
	var rot0: float = 0.0
	var hit: bool = false
	var tint: bool = false

	func point(line: PackedFloat32Array, t: float) -> Vector2:
		if arc:
			var radius := line[0] + (0.995 - line[0]) * t * t
			return Vector2.from_angle(line[1] + line[2] * t) * radius
		var u := 1.0 - t
		return Vector2(line[0], line[1]) * u * u + Vector2(line[2], line[3]) * 2.0 * u * t + Vector2(line[4], line[5]) * t * t

	## Eased head / tail positions along every line, plus the fade-out after the sweep lands.
	func progress() -> Vector3:
		var p := Orrery.ease_in_out(minf(life / duration, 1.0))
		var head := minf(p * (1.0 + window), 1.0)
		var tail := maxf(p * (1.0 + window) - window, 0.0)
		var fade := 1.0 if life <= duration else maxf(1.0 - (life - duration) / Orrery.COMET_FADE_SECONDS, 0.0)
		return Vector3(tail, head, fade)


static var mono_cache: SystemFont

var session_id: int = 0
var clock: float = 0.0
var sample_timer: float = 0.0
var turn_count: int = 0
var reasoning_chars: int = 0
var content_chars: int = 0
var completion_tokens: int = 0
var tool_total: int = 0
var tool_failed: int = 0
var reasoning_energy: float = 0.0
var content_energy: float = 0.0
var tool_energy: float = 0.0
var error_flash: float = 0.0
var turn_pulse: float = 0.0
var beam_travel: float = 0.0
var zoom: float = ZOOM_MIN
var inner_angle: float = 0.0
var outer_angle: float = 0.0
var ending: bool = false
var end_progress: float = 0.0
var last_stream_kind: String = ""
var snippet: String = ""
var snippet_tag: int = -1
var feed_serial: int = 0
var feed: Array[FeedLine] = []
var tracks: Array[ToolTrack] = []
var track_by_id: Dictionary[String, ToolTrack] = {}
## tool name -> (calls, failures).
var tool_stats: Dictionary[String, Vector2i] = {}
var reasoning_history := PackedFloat32Array()
var content_history := PackedFloat32Array()
var tool_history := PackedFloat32Array()
var heat := PackedFloat32Array()
var histogram := PackedFloat32Array()
## Solver particles: (x, y, life, 1 = reasoning / 0 = content).
var dots: Array[Vector4] = []
## Web curves in unit-disc space, three points each (rim start, control, rim end).
var web_curves := PackedVector2Array()
## Per curve: -1 base layer or 0..2 pulse layer; authored alpha; hue 0 ink / 1 hot / 2 violet.
var web_layers := PackedInt32Array()
var web_alphas := PackedFloat32Array()
var web_hues := PackedInt32Array()
## Node markers: (x, y, radius in px) plus a label (empty for most); dotted chains: (radius, start angle, count).
var web_nodes := PackedVector3Array()
var web_labels := PackedStringArray()
var web_chains := PackedVector3Array()
var runners: Array[Runner] = []
var comets: Array[Comet] = []
## Ring slot flashes from comet impacts: (angle relative to `outer_angle`, strength).
var ring_flashes: Array[Vector2] = []
var layer_env := PackedFloat32Array([0.0, 0.0, 0.0])
## Short envelope kicked by every stream chunk or tool event; runners surge on it.
var beat_env: float = 0.0
## Fine radial hairlines: local angle and alpha bucket (0 faint / 1 bright).
var fine_beams := PackedVector2Array()
## Travelling beams: (local angle, half angular width, speed, phase).
var beams: Array[Vector4] = []
## Emitted pulses: (local angle, age, half angular width, kind 0 stream / 1 tool / 2 failure).
var pulses: Array[Vector4] = []
var rng := RandomNumberGenerator.new()
var screen_viewport: SubViewport
var screen: OrreryScreen
var stage: OrreryStage
var draw_alpha: float = 1.0
var palette_ink: Color = Color(0.92, 0.93, 0.95)
var palette_back: Color = Color(0.02, 0.022, 0.028)
var palette_panel: Color = Color(0.045, 0.047, 0.056)
var palette_screen: Color = Color(0.03, 0.032, 0.04)
var palette_hot: Color = Color(0.93, 0.52, 0.72)
var palette_violet: Color = Color(0.66, 0.58, 0.92)
var palette_lime: Color = Color(0.86, 0.92, 0.52)
var palette_error: Color = Color(1.0, 0.35, 0.35)


func _init() -> void:
	rng.seed = 20261029
	build_field()
	reset_buffers()
	pass


func _ready() -> void:
	super._ready()
	sync_palette()
	ensure_children()
	pass


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.4


func on_agent_start(p_session_id: int) -> void:
	session_id = p_session_id
	clock = 0.0
	sample_timer = 0.0
	turn_count = 0
	reasoning_chars = 0
	content_chars = 0
	completion_tokens = 0
	tool_total = 0
	tool_failed = 0
	reasoning_energy = 0.0
	content_energy = 0.0
	tool_energy = 0.0
	error_flash = 0.0
	turn_pulse = 0.0
	ending = false
	end_progress = 0.0
	last_stream_kind = ""
	snippet = ""
	snippet_tag = -1
	feed.clear()
	tracks.clear()
	track_by_id.clear()
	tool_stats.clear()
	dots.clear()
	pulses.clear()
	comets.clear()
	ring_flashes.clear()
	layer_env = PackedFloat32Array([0.0, 0.0, 0.0])
	beat_env = 0.0
	zoom = ZOOM_MIN
	reset_buffers()
	sync_palette()
	push_feed(Tag.RUN, StringUtils.format(I18n.t("agent.visuals.orrery_session"), session_id))
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	flush_snippet()
	var failed := StringUtils.is_not_blank(error_message)
	for track: ToolTrack in tracks:
		if track.is_running():
			finish_track(track, failed)
	if failed:
		error_flash = 1.0
		push_feed(Tag.FAIL, clean_text(error_message))
	else:
		push_feed(Tag.RUN, "CLOSED " + format_clock(clock))
	ending = true
	end_progress = 0.0
	if not is_inside_tree():
		return
	await get_tree().create_timer(END_SECONDS).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	turn_count += 1
	turn_pulse = 1.0
	beat_env = 1.0
	for index in range(layer_env.size()):
		layer_env[index] = rng.randf_range(0.6, 1.0)
	for _index in range(6):
		spawn_comet(rng.randf_range(-1.0, 1.0) * visible_half_angle() * 0.85, rng.randf() < 0.6)
	flush_snippet()
	push_feed(Tag.TURN, "TURN %02d" % turn_count)
	pass


func on_turn_end(_session_id: int) -> void:
	flush_snippet()
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or ending:
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length()) * STREAM_GAIN
	var reasoning := stream_kind == OpenAiClient.STREAM_KIND_REASONING
	last_stream_kind = stream_kind
	if reasoning:
		reasoning_chars += chunk.length()
		reasoning_energy = minf(reasoning_energy + energy, 1.0)
	else:
		content_chars += chunk.length()
		content_energy = minf(content_energy + energy, 1.0)
	# Salting with the running length spreads repeated deltas across the index instead of one hot cell.
	var cell := heat_cell(chunk + str(reasoning_chars + content_chars), heat.size())
	heat[cell] = minf(heat[cell] + 0.3 + energy, 1.0)
	var neighbor := (cell + 1 + rng.randi() % HEAT_COLUMNS) % heat.size()
	heat[neighbor] = minf(heat[neighbor] + 0.15 + energy * 0.5, 1.0)
	histogram[histogram_bin(chunk.length())] += 1.0
	spawn_dots(mini(1 + int(chunk.length() / 40.0), 6), reasoning)
	beat_env = 1.0
	var reach := visible_half_angle()
	if reasoning:
		# Thought shimmers the woven web and sends the odd arc bundle skimming along the rim.
		if rng.randf() < 0.35:
			var layer := rng.randi() % layer_env.size()
			layer_env[layer] = maxf(layer_env[layer], 0.8)
		if rng.randf() < 0.06 + energy * 0.3:
			spawn_comet(rng.randf_range(-reach, reach) * 0.85, true)
	else:
		# Answer tokens leave the ring as small beams and trickle comets out to it.
		if rng.randf() < 0.3 + energy:
			spawn_pulse(rng.randf_range(-reach, reach), 0)
		if rng.randf() < 0.12 + energy * 0.5:
			spawn_comet(rng.randf_range(-reach, reach) * 0.85, rng.randf() < 0.4)
	append_snippet(chunk, Tag.THINK if reasoning else Tag.WRITE)
	pass


func on_message_complete(_session_id: int, usage: OpenAiUsage) -> void:
	if usage != null and usage.has_data():
		completion_tokens += usage.completion_tokens
	flush_snippet()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	if ending:
		return
	if track_by_id.has(tool_call_id):
		tracks.erase(track_by_id[tool_call_id])
	var track := ToolTrack.new()
	track.id = tool_call_id
	track.name = display_name(tool_name)
	track.detail = compact_args(args)
	track.started = clock
	tracks.append(track)
	track_by_id[tool_call_id] = track
	trim_tracks()
	tool_total += 1
	tool_energy = 1.0
	var stat: Vector2i = tool_stats.get(track.name, Vector2i.ZERO)
	tool_stats[track.name] = stat + Vector2i(1, 0)
	spawn_pulse(tool_angle(track.name), 1)
	# A tool call gathers converging bundles that land on the ring at that tool's bearing.
	beat_env = 1.0
	for _index in range(4):
		spawn_comet(tool_angle(track.name) + rng.randf_range(-0.04, 0.04), false)
	flush_snippet()
	push_feed(Tag.TOOL, (track.name + " " + track.detail).strip_edges())
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not track_by_id.has(tool_call_id):
		return
	var track: ToolTrack = track_by_id[tool_call_id]
	if track.is_running():
		finish_track(track, result.is_error)
	pass


func finish_track(track: ToolTrack, failed: bool) -> void:
	track.finished = clock
	track.failed = failed
	tool_energy = 1.0
	if failed:
		tool_failed += 1
		error_flash = 1.0
		var stat: Vector2i = tool_stats.get(track.name, Vector2i.ZERO)
		tool_stats[track.name] = stat + Vector2i(0, 1)
		spawn_pulse(tool_angle(track.name), 2)
	push_feed(Tag.FAIL if failed else Tag.OK, "%s %.1fs" % [track.name, track.seconds(clock)])
	pass


## Drops the oldest finished track first so a long-running tool keeps its row.
func trim_tracks() -> void:
	while tracks.size() > TRACK_LIMIT:
		var victim := 0
		for index in range(tracks.size()):
			if not tracks[index].is_running():
				victim = index
				break
		var track := tracks[victim]
		tracks.remove_at(victim)
		if track_by_id.get(track.id) == track:
			track_by_id.erase(track.id)
	pass


func push_feed(tag: int, text: String) -> void:
	if text.is_empty():
		return
	var line := FeedLine.new()
	feed_serial += 1
	line.serial = feed_serial
	line.tag = tag
	line.text = text
	feed.append(line)
	while feed.size() > FEED_LIMIT:
		feed.remove_at(0)
	pass


## Streams land in the feed as fixed-width slices, so the log scrolls like a terminal.
func append_snippet(chunk: String, tag: int) -> void:
	if tag != snippet_tag:
		flush_snippet()
		snippet_tag = tag
	snippet += clean_text(chunk)
	if snippet.length() > SNIPPET_LENGTH * FEED_LIMIT:
		snippet = snippet.right(SNIPPET_LENGTH * 2)
	while snippet.length() >= SNIPPET_LENGTH:
		push_feed(tag, snippet.left(SNIPPET_LENGTH).strip_edges())
		snippet = snippet.substr(SNIPPET_LENGTH)
	pass


func flush_snippet() -> void:
	if snippet_tag >= 0 and StringUtils.is_not_blank(snippet):
		push_feed(snippet_tag, snippet.strip_edges())
	snippet = ""
	pass


func spawn_dots(count: int, reasoning: bool) -> void:
	for _index in range(count):
		dots.append(Vector4(rng.randf(), rng.randf() * 0.78, 1.0, 1.0 if reasoning else 0.0))
	while dots.size() > DOT_LIMIT:
		dots.remove_at(0)
	pass


## Emits a beam from the ring at [param world_angle] (radians from the hub's +x, i.e. the visible side).
## Stored relative to `outer_angle` so the beam keeps turning with the ring after it leaves.
func spawn_pulse(world_angle: float, kind: int) -> void:
	var half_width := 0.004 if kind == 0 else 0.009
	pulses.append(Vector4(world_angle - outer_angle, 0.0, half_width, float(kind)))
	while pulses.size() > PULSE_LIMIT:
		pulses.remove_at(0)
	pass


## Launches a comet that lands on the ring at [param world_angle]. Arc bundles hug the rim and
## spiral onto it; converging bundles start from one inner point and fan out to the rim.
func spawn_comet(world_angle: float, arc: bool) -> void:
	var comet := Comet.new()
	comet.arc = arc
	comet.rot0 = outer_angle
	comet.duration = rng.randf_range(0.4, 0.85) / 0.8
	comet.window = rng.randf_range(0.22, 0.4)
	comet.tint = rng.randf() < 0.15
	var count := 8 + rng.randi() % 12
	if arc:
		var radius := rng.randf_range(0.55, 0.9)
		var span := rng.randf_range(0.35, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
		var gap := rng.randf_range(0.007, 0.012)
		for index in range(count):
			comet.lines.append(PackedFloat32Array([radius - index * gap + gauss() * 0.002, world_angle - span + gauss() * 0.01, span]))
	else:
		var origin := Vector2.from_angle(world_angle + rng.randf_range(-1.3, 1.3)) * rng.randf_range(0.25, 0.75)
		var spread := rng.randf_range(0.08, 0.25)
		var bend := rng.randf_range(0.2, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		for index in range(count):
			var finish := Vector2.from_angle(world_angle + (float(index) / count - 0.5) * spread) * 0.995
			var start := origin + Vector2(gauss(), gauss()) * 0.025
			var middle := (start + finish) * 0.5
			var across := finish - start
			var control := middle + Vector2(-across.y, across.x) * bend + Vector2(gauss(), gauss()) * 0.02
			comet.lines.append(PackedFloat32Array([start.x, start.y, control.x, control.y, finish.x, finish.y]))
	comets.append(comet)
	while comets.size() > COMET_LIMIT:
		comets.remove_at(0)
	pass


## A comet landing lights the nearest ring slot and throws a beam outward from the same bearing.
func flash_ring(world_angle: float) -> void:
	ring_flashes.append(Vector2(world_angle - outer_angle, 0.8))
	while ring_flashes.size() > COMET_LIMIT:
		ring_flashes.remove_at(0)
	spawn_pulse(world_angle, 0)
	pass


## Half-angle of the ring that faces the view: past it the disc leaves the stage at this zoom.
func visible_half_angle() -> float:
	return asin(clampf(0.5 / (DISC_RADIUS_RATIO * zoom), 0.0, 1.0))


func gauss() -> float:
	return (rng.randf() + rng.randf() + rng.randf() - 1.5) / 1.5


static func ease_in_out(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


static func quad_point(start: Vector2, control: Vector2, finish: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return start * u * u + control * 2.0 * u * t + finish * t * t


func web_point(curve: int, t: float) -> Vector2:
	return quad_point(web_curves[curve * 3], web_curves[curve * 3 + 1], web_curves[curve * 3 + 2], t)


func new_runner(initial: bool) -> Runner:
	var runner := Runner.new()
	runner.curve = rng.randi() % maxi(int(web_curves.size() / 3.0), 1)
	runner.t = rng.randf() if initial else 0.0
	runner.accent = rng.randf() < 0.1
	# Mixed speed personalities so lone lines never move in lockstep.
	var roll := rng.randf()
	if rng.randf() > 0.4:
		runner.mode = 1
		runner.speed = rng.randf_range(0.12, 0.38)
	elif roll < 0.3:
		runner.speed = rng.randf_range(0.15, 0.28)
	elif roll < 0.65:
		runner.mode = 1
		runner.speed = rng.randf_range(0.1, 0.3)
	elif roll < 0.8:
		runner.speed = rng.randf_range(0.04, 0.08)
	elif roll < 0.92:
		runner.speed = rng.randf_range(0.5, 0.85)
	else:
		runner.mode = 2
		runner.speed = rng.randf_range(0.06, 0.12)
	return runner


## Stable visible-side angle per tool name, so repeated calls of one tool fire along the same bearing.
static func tool_angle(tool_name: String) -> float:
	return -0.95 + float(absi(tool_name.hash()) % 1000) / 1000.0 * 1.9


## Reasoning looks into the disc; answers sit halfway; tool dispatch pulls back to show the beams.
func zoom_target() -> float:
	if ending:
		return ZOOM_END
	if running_tools() > 0:
		return ZOOM_MIN
	if reasoning_energy > 0.04 and reasoning_energy >= content_energy:
		return ZOOM_MAX
	if content_energy > 0.04:
		return lerpf(ZOOM_MIN, ZOOM_MAX, 0.45)
	return ZOOM_MIN


static func ring_tiles() -> int:
	var middle := DISC_RADIUS_RATIO + RING_THICKNESS_RATIO * 0.5
	return maxi(3, roundi(TAU * middle / (RING_THICKNESS_RATIO * TILE_ASPECT)))


func running_tools() -> int:
	var count := 0
	for track: ToolTrack in tracks:
		if track.is_running():
			count += 1
	return count


func finished_tools() -> int:
	return tool_total - running_tools()


func token_count() -> int:
	return maxi(completion_tokens, int((reasoning_chars + content_chars) / 4.0))


## Tool names ordered by call count, busiest first.
func ranked_tools() -> Array[String]:
	var names: Array[String] = []
	for tool_name: String in tool_stats:
		names.append(tool_name)
	names.sort_custom(func(a: String, b: String) -> bool:
		return tool_stats[a].x > tool_stats[b].x if tool_stats[a].x != tool_stats[b].x else a < b)
	return names


func phase_key() -> String:
	if ending:
		return "agent.visuals.orrery_closing"
	if running_tools() > 0:
		return "agent.visuals.orrery_dispatch"
	if reasoning_energy + content_energy < 0.02:
		return "agent.visuals.orrery_idle"
	if last_stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		return "agent.visuals.orrery_reasoning"
	return "agent.visuals.orrery_writing"


func reset_buffers() -> void:
	reasoning_history = PackedFloat32Array()
	reasoning_history.resize(HISTORY_SIZE)
	content_history = PackedFloat32Array()
	content_history.resize(HISTORY_SIZE)
	tool_history = PackedFloat32Array()
	tool_history.resize(HISTORY_SIZE)
	histogram = PackedFloat32Array()
	histogram.resize(HISTOGRAM_BINS)
	heat = PackedFloat32Array()
	heat.resize(HEAT_COLUMNS * HEAT_ROWS)
	pass


func build_field() -> void:
	build_web()
	runners.clear()
	for _index in range(RUNNER_COUNT):
		runners.append(new_runner(true))
	fine_beams.clear()
	for index in range(FINE_BEAMS):
		fine_beams.append(Vector2(TAU * (float(index) + rng.randf_range(-0.35, 0.35)) / float(FINE_BEAMS), 1.0 if rng.randf() < 0.3 else 0.0))
	beams.clear()
	for _index in range(BEAM_COUNT):
		beams.append(Vector4(rng.randf() * TAU, rng.randf_range(0.0015, 0.012), rng.randf_range(0.05, 0.22), rng.randf()))
	pass


## Woven light field: each curve leaves the rim, bends through an inner control point, and returns
## to the rim 0.6–1.4π later. Most curves are faint base threads; the pulse layers are brighter.
func build_web() -> void:
	web_curves.clear()
	web_layers.clear()
	web_alphas.clear()
	web_hues.clear()
	for _index in range(WEB_CURVES):
		var a1 := rng.randf() * TAU
		var a2 := a1 + rng.randf_range(0.6, PI * 1.4)
		web_curves.append(Vector2.from_angle(a1))
		web_curves.append(Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 0.9)
		web_curves.append(Vector2.from_angle(a2))
		var layer := -1 if rng.randf() >= WEB_PULSE_SHARE else rng.randi() % 3
		web_layers.append(layer)
		web_alphas.append(0.03 + pow(rng.randf(), 3.0) * 0.28 if layer < 0 else 0.08 + pow(rng.randf(), 2.0) * 0.35)
		var hue := rng.randf()
		web_hues.append(1 if hue < 0.05 else (2 if hue < 0.1 else 0))
	web_nodes.clear()
	web_labels.clear()
	for _index in range(WEB_NODES):
		var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 0.92
		web_nodes.append(Vector3(at.x, at.y, rng.randf_range(2.0, 4.5)))
		web_labels.append("n%d" % (rng.randi() % 99) if rng.randf() < 0.35 else "")
	web_chains.clear()
	for _index in range(WEB_CHAINS):
		web_chains.append(Vector3(rng.randf_range(0.45, 0.85), rng.randf() * TAU, float(22 + rng.randi() % 14)))
	pass


func step_web(delta: float) -> void:
	beat_env *= exp(-BEAT_DECAY * delta)
	for index in range(layer_env.size()):
		layer_env[index] *= exp(-LAYER_DECAY * delta)
	var surge := 0.5 + 2.5 * beat_env
	for index in range(runners.size()):
		var runner := runners[index]
		var rate := runner.speed
		if runner.mode == 1:
			rate *= surge
		elif runner.mode == 2:
			rate += 1.3 * runner.t * runner.t
		runner.t += delta * 0.6 * rate
		if runner.t >= 1.0:
			runners[index] = new_runner(false)
	for index in range(comets.size() - 1, -1, -1):
		var comet := comets[index]
		comet.life += delta
		var span := comet.progress()
		if span.y >= 1.0 and not comet.hit:
			comet.hit = true
			var landing := comet.point(comet.lines[comet.lines.size() >> 1], 1.0)
			flash_ring(landing.angle() + outer_angle - comet.rot0)
		if span.z <= 0.0:
			comets.remove_at(index)
	for index in range(ring_flashes.size() - 1, -1, -1):
		var flash := ring_flashes[index]
		flash.y -= delta * FLASH_DECAY
		if flash.y <= 0.0:
			ring_flashes.remove_at(index)
		else:
			ring_flashes[index] = flash
	pass


func step_orrery(delta: float) -> void:
	clock += delta
	var decay := exp(-ENERGY_DECAY * delta)
	reasoning_energy *= decay
	content_energy *= decay
	tool_energy = maxf(tool_energy * decay, 0.3 if running_tools() > 0 else 0.0)
	error_flash = maxf(error_flash - delta * 1.5, 0.0)
	turn_pulse = maxf(turn_pulse - delta * 1.2, 0.0)
	beam_travel += delta * (0.5 + content_energy * 2.0 + tool_energy)
	# The disc spins on its own, faster while thinking; ring and beams counter-rotate together.
	inner_angle = fposmod(inner_angle + delta * (0.06 + 0.5 * reasoning_energy), TAU)
	outer_angle = fposmod(outer_angle - delta * (0.035 + 0.3 * content_energy + 0.15 * tool_energy), TAU)
	zoom = lerpf(zoom, zoom_target(), 1.0 - exp(-ZOOM_RATE * delta))
	step_web(delta)
	for index in range(pulses.size() - 1, -1, -1):
		var pulse := pulses[index]
		pulse.y += delta
		if pulse.y >= PULSE_SECONDS:
			pulses.remove_at(index)
		else:
			pulses[index] = pulse
	for index in range(heat.size()):
		heat[index] = maxf(heat[index] - HEAT_DECAY * delta, 0.0)
	for index in range(dots.size() - 1, -1, -1):
		var dot := dots[index]
		dot.z -= delta * 0.45
		dot.y += delta * (0.03 if dot.w > 0.5 else -0.02)
		if dot.z <= 0.0:
			dots.remove_at(index)
		else:
			dots[index] = dot
	sample_timer += delta
	while sample_timer >= SAMPLE_SECONDS:
		sample_timer -= SAMPLE_SECONDS
		reasoning_history = pushed_sample(reasoning_history, reasoning_energy)
		content_history = pushed_sample(content_history, content_energy)
		tool_history = pushed_sample(tool_history, tool_energy)
	if ending:
		end_progress = minf(end_progress + delta / END_SECONDS, 1.0)
	pass


static func pushed_sample(buffer: PackedFloat32Array, value: float) -> PackedFloat32Array:
	var next := buffer.slice(1) if buffer.size() >= HISTORY_SIZE else buffer.duplicate()
	next.append(value)
	return next


static func heat_cell(text: String, cells: int) -> int:
	return absi(text.hash()) % maxi(cells, 1)


## Log-scaled chunk length bucket, so one-token deltas and pasted file bodies both register.
static func histogram_bin(length: int) -> int:
	return clampi(int(log(float(maxi(length, 0)) + 1.0) / log(2.0) * 1.6), 0, HISTOGRAM_BINS - 1)


static func clean_text(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").replace("\t", " ")


static func clip_text(text: String, max_chars: int) -> String:
	if max_chars <= 0:
		return ""
	if text.length() <= max_chars:
		return text
	return text.left(maxi(max_chars - 1, 0)) + "…"


static func display_name(tool_name: String) -> String:
	return tool_name if StringUtils.is_not_blank(tool_name) else "tool"


## First two arguments as `key=value`, single-line and clipped for a terminal row.
static func compact_args(args: Dictionary, max_length: int = 28) -> String:
	var parts := PackedStringArray()
	for key: Variant in args:
		parts.append("%s=%s" % [str(key), clean_text(str(args[key])).strip_edges()])
		if parts.size() >= 2:
			break
	return clip_text(" ".join(parts), max_length)


static func compact_count(count: int) -> String:
	if count < 1000:
		return str(count)
	if count < 1000000:
		return "%.1fK" % (count / 1000.0)
	return "%.1fM" % (count / 1000000.0)


static func format_clock(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	return "%02d:%02d" % [int(total / 60.0), total % 60]


static func hash01(x: float, y: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453, 1.0)


static func mono_font() -> Font:
	if mono_cache == null:
		mono_cache = SystemFont.new()
		mono_cache.font_names = PackedStringArray(MONO_FONT_NAMES)
		var fallbacks: Array[Font] = [Fonts.regular()]
		mono_cache.fallbacks = fallbacks
	return mono_cache


static func mono(canvas: CanvasItem, at: Vector2, value: String, font_size: int, color: Color) -> void:
	canvas.draw_string(mono_font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


static func mono_right(canvas: CanvasItem, right: Vector2, value: String, font_size: int, color: Color) -> void:
	var width := mono_font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(mono_font(), right - Vector2(width, 0.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


func sync_palette() -> void:
	var dark := ThemeColor.is_dark_theme()
	var accent := ThemeColor.accent_theme_color()
	palette_ink = Color(0.92, 0.93, 0.95) if dark else Color(0.1, 0.11, 0.13)
	palette_back = Color(0.02, 0.022, 0.028) if dark else Color(0.955, 0.958, 0.965)
	palette_panel = Color(0.045, 0.047, 0.056) if dark else Color(0.985, 0.985, 0.99)
	palette_screen = Color(0.03, 0.032, 0.04) if dark else Color(0.93, 0.935, 0.945)
	palette_hot = VisualColor.appearance_color(accent, 0.0, 0.75)
	palette_violet = VisualColor.appearance_color(accent, 0.08, 0.45)
	palette_lime = VisualColor.appearance_color(Color(0.84, 0.9, 0.5), 0.0, 1.0, 1.0)
	palette_error = Colors.error
	pass


func tag_color(tag: int) -> Color:
	match tag:
		Tag.THINK:
			return palette_violet
		Tag.TOOL:
			return palette_hot
		Tag.OK:
			return palette_lime
		Tag.FAIL:
			return palette_error
	return palette_ink


func ink(alpha: float) -> Color:
	return VisualColor.stroke(palette_ink, alpha * draw_alpha)


func tint(color: Color, alpha: float) -> Color:
	return VisualColor.stroke(color, alpha * draw_alpha)


## Screen tiles render in a [SubViewport]; the stage is a clipped child so beams stop at its edges.
func ensure_children() -> void:
	if screen_viewport != null:
		return
	screen_viewport = SubViewport.new()
	screen_viewport.transparent_bg = true
	screen_viewport.disable_3d = true
	screen_viewport.gui_disable_input = true
	screen = OrreryScreen.new()
	screen.orrery = self
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_viewport.add_child(screen)
	add_child(screen_viewport)
	stage = OrreryStage.new()
	stage.orrery = self
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	visibility_changed.connect(on_visibility_changed)
	on_visibility_changed()
	pass


func on_visibility_changed() -> void:
	if screen_viewport != null:
		screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	pass


## One ring tile in viewport pixels: ring thickness wide, `TILE_ASPECT` times that tall.
func tile_pixel_size() -> Vector2i:
	var thickness := stage_rect().size.y * RING_THICKNESS_RATIO * TILE_ZOOM
	var height := minf(thickness * TILE_ASPECT, float(TILE_MAX_HEIGHT))
	return Vector2i(Vector2(height / TILE_ASPECT, height).round()).maxi(16)


func sync_children() -> void:
	if stage != null:
		var rect := stage_rect()
		stage.position = rect.position
		stage.size = rect.size
	if screen_viewport != null:
		var target := tile_pixel_size()
		if screen_viewport.size != target:
			screen_viewport.size = target
			screen.size = Vector2(target)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_orrery(minf(delta, 0.05))
	sync_children()
	if screen != null:
		screen.queue_redraw()
	if stage != null:
		stage.sync_layers()
		stage.queue_redraw()
	queue_redraw()
	pass


func _draw() -> void:
	var view := view_size()
	draw_alpha = OVERLAY_STRENGTH * (1.0 - 0.45 * end_progress)
	draw_rect(Rect2(Vector2.ZERO, view), Color(palette_back, BACKDROP_ALPHA))
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func text_size() -> int:
	return clampi(int(view_size().y * 0.0125), 9, 15)


## The stage fills the whole effect: the ring carries every readout, so no header or panel grid.
func stage_rect() -> Rect2:
	return Rect2(Vector2.ZERO, view_size())

