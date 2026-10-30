class_name TeslaLightning
extends VisualEffect

## Lichtenberg lightning (利希滕贝格电弧): every running tool draws a crackling arc from the nearest
## window edge to its spot, re-forking many times a second like a Tesla coil. A finished tool
## lands one bright strike with a spray of sparks; a failed one explodes into red branches.
## Streamed answers crawl as static along a typing caret, reasoning flickers faint tendrils at the
## edges, every turn opens with a strike from above, and the run ends in a final discharge.

const MAX_BOLTS := 48
const MAX_SPARKS := 220
const ARC_REFORK_SECONDS := 0.065
const ARC_LIFE := 0.09
const STRIKE_LIFE := 0.38
const STATIC_LIFE := 0.14
const TENDRIL_LIFE := 0.18
const MAIN_DEPTH := 7
const BRANCH_DEPTH := 5
const BRANCH_CHANCE := 0.12
const DISPLACEMENT := 0.22
const STATIC_COST := 0.05
const TENDRIL_COST := 0.09
const CARET_STEP := 0.045
const SPARK_GRAVITY := 620.0
const SPARK_DRAG_PER_SECOND := 1.6
const EDGE_JITTER_PX := 90.0
const END_DISCHARGE_MSEC := 650


class Bolt extends RefCounted:
	var paths: Array[PackedVector2Array] = []
	var widths: PackedFloat32Array = PackedFloat32Array()
	var life: float = 0.0
	var max_life: float = 0.1
	var intensity: float = 1.0
	var color: Color = Color.WHITE
	var impact: Vector2 = Vector2.ZERO
	var impact_radius: float = 0.0


class Spark extends RefCounted:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var max_life: float
	var color: Color


var bolts: Array[Bolt] = []
var sparks: Array[Spark] = []
## tool_call_id -> Vector4(source.x, source.y, target.x, target.y) in pixels.
var arcs: Dictionary[String, Vector4] = {}
var arc_clock: float = 0.0
var static_charge: float = 0.0
var tendril_charge: float = 0.0
var caret: Vector2 = Vector2(0.24, 0.6)
var accent_color: Color = Color(0.55, 0.75, 1.0)
var core_color: Color = Color.WHITE
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	pass


func fade_out_seconds() -> float:
	return 0.4


func on_agent_start(_session_id: int) -> void:
	bolts.clear()
	sparks.clear()
	arcs.clear()
	arc_clock = 0.0
	static_charge = 0.0
	tendril_charge = 0.0
	caret = Vector2(0.24, 0.6)
	sync_palette()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	arcs.clear()
	var failed := StringUtils.is_not_blank(error_message)
	var color := Colors.error if failed else accent_color
	var center := view_size() * Vector2(0.5, 0.55)
	for index in range(3):
		var source := edge_point_toward(center + Vector2.from_angle(float(index) * TAU / 3.0 - PI * 0.5) * view_size().length())
		add_bolt(source, center, STRIKE_LIFE * 1.4, 1.2, color)
	burst_sparks(center, 26, color)
	if not is_inside_tree():
		return
	await get_tree().create_timer(END_DISCHARGE_MSEC / 1000.0).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	var viewport := view_size()
	var target := Vector2(viewport.x * rng.randf_range(0.3, 0.7), viewport.y * rng.randf_range(0.35, 0.55))
	var source := Vector2(target.x + rng.randf_range(-120.0, 120.0), body_top())
	add_bolt(source, target, STRIKE_LIFE, 1.0, accent_color)
	burst_sparks(target, 10, accent_color)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		tendril_charge += energy
	else:
		static_charge += energy * 1.5
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var target := SimulationEffect.tool_anchor(tool_name) * view_size()
	var source := edge_point_toward(target)
	arcs[tool_call_id] = Vector4(source.x, source.y, target.x, target.y)
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var arc: Vector4 = arcs.get(tool_call_id, Vector4.ZERO)
	arcs.erase(tool_call_id)
	var target := SimulationEffect.tool_anchor(tool_name) * view_size()
	var source := Vector2(arc.x, arc.y) if arc != Vector4.ZERO else edge_point_toward(target)
	if result.is_error:
		add_bolt(source, target, STRIKE_LIFE, 1.1, Colors.error)
		for index in range(5):
			var reach := rng.randf_range(120.0, 240.0)
			add_bolt(target, target + Vector2.from_angle(float(index) * TAU / 5.0 + rng.randf_range(-0.3, 0.3)) * reach, STRIKE_LIFE, 0.7, Colors.error)
		burst_sparks(target, 22, Colors.error)
	else:
		add_bolt(source, target, STRIKE_LIFE, 1.25, accent_color)
		burst_sparks(target, 16, accent_color)
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_lightning(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func step_lightning(delta: float) -> void:
	arc_clock += delta
	if arc_clock >= ARC_REFORK_SECONDS:
		arc_clock = fmod(arc_clock, ARC_REFORK_SECONDS)
		for arc: Vector4 in arcs.values():
			add_bolt(Vector2(arc.x, arc.y), Vector2(arc.z, arc.w), ARC_LIFE, rng.randf_range(0.55, 0.9), accent_color)
	while static_charge >= STATIC_COST:
		static_charge -= STATIC_COST
		var from := caret * view_size()
		advance_caret()
		add_bolt(from, caret * view_size(), STATIC_LIFE, 0.45, accent_color, 4, 0.0)
	while tendril_charge >= TENDRIL_COST:
		tendril_charge -= TENDRIL_COST
		var root := random_edge_point()
		var inward := (view_size() * 0.5 - root).normalized().rotated(rng.randf_range(-0.6, 0.6))
		add_bolt(root, root + inward * rng.randf_range(70.0, 160.0), TENDRIL_LIFE, 0.35, accent_color, 5, 0.25)
	for index in range(bolts.size() - 1, -1, -1):
		bolts[index].life += delta
		if bolts[index].life >= bolts[index].max_life:
			bolts.remove_at(index)
	var drag := exp(-SPARK_DRAG_PER_SECOND * delta)
	for index in range(sparks.size() - 1, -1, -1):
		var spark := sparks[index]
		spark.life += delta
		if spark.life >= spark.max_life:
			sparks.remove_at(index)
			continue
		spark.velocity = spark.velocity * drag + Vector2(0.0, SPARK_GRAVITY * delta)
		spark.position += spark.velocity * delta
	pass


## Moves the static caret like text being typed: left to right, then down a line.
func advance_caret() -> void:
	caret.x += CARET_STEP
	if caret.x > 0.78:
		caret.x = 0.24
		caret.y = 0.56 if caret.y > 0.84 else caret.y + 0.055
	pass


func add_bolt(from: Vector2, to: Vector2, life: float, intensity: float, color: Color, depth: int = MAIN_DEPTH, branch_chance: float = BRANCH_CHANCE) -> Bolt:
	if bolts.size() >= MAX_BOLTS:
		bolts.remove_at(0)
	var bolt := Bolt.new()
	bolt.max_life = life
	bolt.intensity = intensity
	bolt.color = color
	var main := fork_path(from, to, depth)
	bolt.paths.append(main)
	bolt.widths.append(1.0)
	if branch_chance > 0.0:
		for index in range(1, main.size() - 1):
			if rng.randf() >= branch_chance:
				continue
			var remaining := main[index].distance_to(to)
			var heading := (to - main[index]).normalized().rotated(rng.randf_range(0.35, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0))
			var branch_end := main[index] + heading * remaining * rng.randf_range(0.2, 0.45)
			bolt.paths.append(fork_path(main[index], branch_end, BRANCH_DEPTH))
			bolt.widths.append(0.5)
	if intensity >= 1.0:
		bolt.impact = to
		bolt.impact_radius = 34.0 * intensity
	bolts.append(bolt)
	return bolt


## Midpoint displacement: each level splits every segment and nudges its middle sideways by a
## shrinking fraction of the segment length.
func fork_path(from: Vector2, to: Vector2, depth: int) -> PackedVector2Array:
	var points := PackedVector2Array([from, to])
	var offset := from.distance_to(to) * DISPLACEMENT
	for _level in range(depth):
		var next := PackedVector2Array()
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var normal := (b - a).orthogonal().normalized()
			next.append(a)
			next.append((a + b) * 0.5 + normal * rng.randf_range(-offset, offset))
		next.append(points[points.size() - 1])
		points = next
		offset *= 0.52
	return points


func burst_sparks(center: Vector2, count: int, color: Color) -> void:
	for _index in range(count):
		if sparks.size() >= MAX_SPARKS:
			sparks.remove_at(0)
		var spark := Spark.new()
		spark.position = center
		spark.velocity = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(120.0, 420.0) + Vector2(0.0, -120.0)
		spark.max_life = rng.randf_range(0.35, 0.8)
		spark.life = 0.0
		spark.color = color
		sparks.append(spark)
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func body_top() -> float:
	return 0.0


## The window edge point closest to [param target], jittered along the edge.
func edge_point_toward(target: Vector2) -> Vector2:
	var viewport := view_size()
	var top := body_top()
	var distances := [target.x, viewport.x - target.x, target.y - top, viewport.y - target.y]
	var nearest := distances.find(distances.min())
	var jitter := rng.randf_range(-EDGE_JITTER_PX, EDGE_JITTER_PX)
	match nearest:
		0:
			return Vector2(0.0, clampf(target.y + jitter, top, viewport.y))
		1:
			return Vector2(viewport.x, clampf(target.y + jitter, top, viewport.y))
		2:
			return Vector2(clampf(target.x + jitter, 0.0, viewport.x), top)
	return Vector2(clampf(target.x + jitter, 0.0, viewport.x), viewport.y)


func random_edge_point() -> Vector2:
	var viewport := view_size()
	var top := body_top()
	match rng.randi() % 4:
		0:
			return Vector2(0.0, rng.randf_range(top, viewport.y))
		1:
			return Vector2(viewport.x, rng.randf_range(top, viewport.y))
		2:
			return Vector2(rng.randf_range(0.0, viewport.x), top)
	return Vector2(rng.randf_range(0.0, viewport.x), viewport.y)


func _draw() -> void:
	for bolt: Bolt in bolts:
		draw_bolt(bolt)
	for spark: Spark in sparks:
		var fade := 1.0 - spark.life / spark.max_life
		draw_line(spark.position, spark.position - spark.velocity * 0.025, VisualColor.stroke(spark.color.lerp(core_color, 0.4), fade), 1.6, true)
	pass


## Four glow layers per path, widest and faintest first, with a hot core on top.
func draw_bolt(bolt: Bolt) -> void:
	var fade := 1.0 - bolt.life / bolt.max_life
	var flicker := 0.75 + 0.25 * rng.randf()
	var strength := clampf(bolt.intensity * fade * flicker, 0.0, 1.4)
	if bolt.impact_radius > 0.0:
		for ring in range(3):
			var radius := bolt.impact_radius * (1.0 - float(ring) * 0.3) * (1.4 - fade * 0.4)
			draw_circle(bolt.impact, radius, VisualColor.stroke(bolt.color, 0.06 * strength * float(ring + 1)))
	for index in range(bolt.paths.size()):
		var path := bolt.paths[index]
		var width := bolt.widths[index]
		draw_polyline(path, VisualColor.stroke(bolt.color, 0.07 * strength), 11.0 * width, true)
		draw_polyline(path, VisualColor.stroke(bolt.color, 0.18 * strength), 5.0 * width, true)
		draw_polyline(path, VisualColor.stroke(bolt.color.lerp(core_color, 0.35), 0.55 * strength), 2.4 * width, true)
		draw_polyline(path, VisualColor.stroke(core_color, 0.9 * strength), maxf(1.0 * width, 0.8), true)
	pass


func sync_palette() -> void:
	accent_color = VisualColor.appearance_color(ThemeColor.accent_theme_color(), 0.0, 0.7)
	core_color = Color(0.96, 0.98, 1.0) if ThemeColor.is_dark_theme() else VisualColor.ink_color(ThemeColor.accent_theme_color(), 0.0, 1.0, 0.45)
	pass
