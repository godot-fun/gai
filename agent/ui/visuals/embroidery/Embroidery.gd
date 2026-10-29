class_name Embroidery
extends VisualEffect

## Embroidery (刺绣): the interface is stretched over linen and a needle sews along with the run.
## Streamed answers become running stitches line by line behind the needle, while reasoning lays
## loose gray basting. Each tool call embroiders a satin-stitch badge at its own spot; success
## frames it with a gold stitched ring, and failure snaps the thread so the badge unravels and
## its loose ends hang in red. Finished messages tie a French knot at the end of the line.

const FABRIC_SHADER: Shader = preload("res://agent/ui/visuals/embroidery/Embroidery.gdshader")
const MAX_ROWS := 40
const MAX_PATCHES := 8
const LINE_LEFT := 0.06
const LINE_RIGHT := 0.94
const LINE_TOP := 0.12
const LINE_BOTTOM := 0.9
const LINE_HEIGHT := 0.045
const WIDTH_PER_CHAR := 0.0035
const FLUSH_INTERVAL := 0.07
const RUN_DASH_PX := 18.0
const RUN_GAP_PX := 10.0
const BASTE_DASH_PX := 34.0
const BASTE_GAP_PX := 18.0
const THREAD_WIDTH_PX := 4.0
const PATCH_RADIUS := 0.055
const PATCH_MERGE_DISTANCE := 0.02
const SATIN_SPACING_PX := 4.5
const HOLD_PROGRESS := 0.85
const STITCH_PER_SECOND := 0.9
const BORDER_PER_SECOND := 1.6
const UNRAVEL_PER_SECOND := 0.55
const UNPICK_PER_SECOND := 1.4
const PRESENCE_PER_SECOND := 3.0
const END_SETTLE_MSEC := 1200
const DEFAULT_SIZE := Vector2(2560.0, 1440.0)
const KIND_RUNNING := 0
const KIND_BASTING := 1
const PATCH_HUES: Array[Color] = [Color(0.85, 0.2, 0.3), Color(0.2, 0.45, 0.9), Color(0.2, 0.7, 0.45), Color(0.95, 0.65, 0.15), Color(0.6, 0.3, 0.8), Color(0.1, 0.65, 0.7)]
const GOLD := Color(0.93, 0.72, 0.28)


class StitchRow extends RefCounted:
	## Screen UV; x1 grows as the needle sews.
	var y: float
	var x0: float
	var x1: float
	var kind: int = 0
	var knot: bool = false
	var unpick: float = -1.0


class Patch extends RefCounted:
	## Screen UV.
	var center: Vector2
	var primary: Color
	var secondary: Color
	var motif: int = 0
	var progress: float = 0.0
	var holding: bool = true
	var border: float = 0.0
	var success: bool = false
	var unravel: float = -1.0
	var noise_seed: float = 0.0
	var key: String = ""


var fabric_rect: ColorRect
var fabric_material: ShaderMaterial
var stitch_layer: Control
var rows: Array[StitchRow] = []
var patches: Array[Patch] = []
var caret: Vector2 = Vector2(LINE_LEFT, LINE_TOP)
var pending_width: float = 0.0
var pending_kind: int = KIND_RUNNING
var flush_timer: float = 0.0
var presence: float = 0.0
var presence_target: float = 0.0
var stitch_time: float = 0.0
var thread_color: Color = Color(0.3, 0.7, 1.0)
var basting_color: Color = Color(0.6, 0.6, 0.6)
var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.3)
var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.35)
var error_color: Color = Color(1.0, 0.35, 0.35)
var needle_color: Color = Color(0.78, 0.8, 0.84)


func _ready() -> void:
	super._ready()
	fabric_rect = ColorRect.new()
	fabric_rect.name = "Linen"
	fabric_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fabric_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fabric_material = ShaderMaterial.new()
	fabric_material.shader = FABRIC_SHADER
	fabric_rect.material = fabric_material
	add_child(fabric_rect)
	stitch_layer = Control.new()
	stitch_layer.name = "Stitches"
	stitch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stitch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stitch_layer.draw.connect(draw_stitches)
	add_child(stitch_layer)
	gdf.events.theme_changed.connect(update_theme_presentation)
	gdf.events.theme_color_changed.connect(update_theme_presentation)
	update_theme_presentation()
	pass


func fade_in_seconds() -> float:
	return 0.2


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	rows.clear()
	patches.clear()
	caret = Vector2(LINE_LEFT, LINE_TOP)
	pending_width = 0.0
	presence_target = 1.0
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	flush_stitches()
	if StringUtils.is_not_blank(error_message):
		for patch: Patch in patches:
			start_unravel(patch)
	else:
		tie_knot()
	if not is_inside_tree():
		presence_target = 0.0
		return
	await get_tree().create_timer(END_SETTLE_MSEC / 1000.0).timeout
	presence_target = 0.0
	pass


func on_turn_start(_session_id: int) -> void:
	flush_stitches()
	new_line()
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var kind := KIND_BASTING if stream_kind == OpenAiClient.STREAM_KIND_REASONING else KIND_RUNNING
	if kind != pending_kind:
		flush_stitches()
		pending_kind = kind
	pending_width += maxf(float(chunk.length()) * WIDTH_PER_CHAR, 0.003)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	flush_stitches()
	tie_knot()
	new_line()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	add_patch(tool_call_id, tool_name, SimulationEffect.tool_anchor(tool_name))
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var patch := find_patch(tool_call_id)
	if patch == null:
		patch = add_patch(tool_call_id, tool_name, SimulationEffect.tool_anchor(tool_name))
	patch.holding = false
	if result.is_error:
		start_unravel(patch)
	else:
		patch.success = true
	pass


func add_patch(key: String, tool_name: String, center: Vector2) -> Patch:
	for patch: Patch in patches:
		if patch.center.distance_to(center) < PATCH_MERGE_DISTANCE:
			patches.erase(patch)
			break
	if patches.size() >= MAX_PATCHES:
		patches.pop_front()
	var hash_value := absi(tool_name.hash())
	var patch := Patch.new()
	patch.center = center
	patch.key = key
	patch.motif = hash_value % 3
	patch.noise_seed = float(absi(key.hash()) % 1000) / 1000.0
	patch.primary = VisualColor.appearance_color(PATCH_HUES[hash_value % PATCH_HUES.size()])
	patch.secondary = VisualColor.appearance_color(PATCH_HUES[(hash_value / 7 + 2) % PATCH_HUES.size()])
	patches.append(patch)
	return patch


func find_patch(key: String) -> Patch:
	for patch: Patch in patches:
		if patch.key == key:
			return patch
	return null


func start_unravel(patch: Patch) -> void:
	if patch.unravel < 0.0:
		patch.unravel = 0.0
		patch.holding = false
	pass


func tie_knot() -> void:
	if not rows.is_empty() and rows[-1].unpick < 0.0:
		rows[-1].knot = true
	pass


func new_line() -> void:
	if caret.x <= LINE_LEFT + 0.001:
		return
	caret = Vector2(LINE_LEFT, caret.y + LINE_HEIGHT)
	if caret.y > LINE_BOTTOM:
		caret.y = LINE_TOP
		for row: StitchRow in rows:
			if row.unpick < 0.0:
				row.unpick = 0.0
	pass


## Sews the width gathered since the last flush onto the caret line, wrapping as lines fill.
func flush_stitches() -> void:
	while pending_width > 0.0:
		var room := LINE_RIGHT - caret.x
		var width := minf(pending_width, room)
		var row := current_row()
		row.x1 = caret.x + width
		caret.x += width
		pending_width = maxf(pending_width - width, 0.0)
		if caret.x >= LINE_RIGHT - 0.005:
			caret.x = LINE_RIGHT
			new_line()
	pass


func current_row() -> StitchRow:
	if not rows.is_empty():
		var last := rows[-1]
		if last.unpick < 0.0 and is_equal_approx(last.y, caret.y) and last.kind == pending_kind and is_equal_approx(last.x1, caret.x) and not last.knot:
			return last
	if rows.size() >= MAX_ROWS:
		rows.pop_front()
	var row := StitchRow.new()
	row.y = caret.y
	row.x0 = caret.x
	row.x1 = caret.x
	row.kind = pending_kind
	rows.append(row)
	return row


func _process(delta: float) -> void:
	if not visible:
		return
	step_stitches(minf(delta, 1.0 / 20.0))
	fabric_material.set_shader_parameter("presence", presence)
	stitch_layer.queue_redraw()
	pass


func step_stitches(delta: float) -> void:
	stitch_time += delta
	presence = move_toward(presence, presence_target, PRESENCE_PER_SECOND * delta)
	flush_timer += delta
	if flush_timer >= FLUSH_INTERVAL:
		flush_timer = 0.0
		flush_stitches()
	for index in range(rows.size() - 1, -1, -1):
		var row := rows[index]
		if row.unpick >= 0.0:
			row.unpick += UNPICK_PER_SECOND * delta
			if row.unpick >= 1.0:
				rows.remove_at(index)
	for index in range(patches.size() - 1, -1, -1):
		var patch := patches[index]
		if patch.unravel >= 0.0:
			patch.unravel += UNRAVEL_PER_SECOND * delta
			if patch.unravel >= 1.0:
				patches.remove_at(index)
			continue
		var goal := HOLD_PROGRESS if patch.holding else 1.0
		patch.progress = move_toward(patch.progress, goal, STITCH_PER_SECOND * delta)
		if patch.success and patch.progress >= 1.0:
			patch.border = minf(patch.border + BORDER_PER_SECOND * delta, 1.0)
	pass


func surface_size() -> Vector2:
	return size if size.x > 0.0 and size.y > 0.0 else DEFAULT_SIZE


## One thread segment: a soft drop shadow, the thread body, and a twist highlight.
func draw_thread(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var lift := Vector2(width * 0.3, width * 0.4)
	stitch_layer.draw_line(from + lift, to + lift, Color(shadow_color, shadow_color.a * color.a), width + 1.0, true)
	stitch_layer.draw_line(from, to, color, width, true)
	var along := (to - from).normalized()
	var normal := Vector2(-along.y, along.x) * width * 0.22
	stitch_layer.draw_line(from - normal + along * width * 0.3, to - normal - along * width * 0.3, Color(highlight_color, highlight_color.a * color.a), maxf(width * 0.3, 1.0), true)
	pass


func draw_stitches() -> void:
	if presence <= 0.001:
		return
	var surface := surface_size()
	var scale := surface.y / DEFAULT_SIZE.y
	var alpha := presence
	for row: StitchRow in rows:
		draw_row(row, surface, scale, alpha)
	for patch: Patch in patches:
		draw_patch(patch, surface, scale, alpha)
	draw_needle(surface, scale, alpha)
	pass


func draw_row(row: StitchRow, surface: Vector2, scale: float, alpha: float) -> void:
	var fade := alpha * (1.0 - maxf(row.unpick, 0.0))
	var basting := row.kind == KIND_BASTING
	var dash := (BASTE_DASH_PX if basting else RUN_DASH_PX) * scale
	var gap := (BASTE_GAP_PX if basting else RUN_GAP_PX) * scale
	var color := Color(basting_color if basting else thread_color, fade)
	var y := (row.y + LINE_HEIGHT * 0.82) * surface.y
	var x := row.x0 * surface.x
	var end_x := row.x1 * surface.x
	var width := THREAD_WIDTH_PX * scale * (0.75 if basting else 1.0)
	var index := 0
	while x < end_x:
		var to_x := minf(x + dash, end_x)
		var wobble := sin(float(index) * 1.7 + row.y * 40.0) * (2.5 if basting else 0.8) * scale
		draw_thread(Vector2(x, y + wobble), Vector2(to_x, y - wobble), color, width)
		x = to_x + gap
		index += 1
	if row.knot:
		var knot := Vector2(end_x + gap * 0.6, y)
		stitch_layer.draw_circle(knot + Vector2(1.5, 2.0) * scale, 6.0 * scale, Color(shadow_color, shadow_color.a * fade))
		stitch_layer.draw_circle(knot, 6.0 * scale, color)
		for turn in range(3):
			var angle := float(turn) * TAU / 3.0 + 0.4
			stitch_layer.draw_arc(knot, 3.5 * scale, angle, angle + 1.6, 6, Color(highlight_color, highlight_color.a * fade), 1.4 * scale, true)
	pass


func draw_patch(patch: Patch, surface: Vector2, scale: float, alpha: float) -> void:
	var center := patch.center * surface
	var radius := PATCH_RADIUS * surface.y
	var unravel := maxf(patch.unravel, 0.0)
	var fade := alpha * (1.0 - unravel * unravel)
	var spacing := SATIN_SPACING_PX * scale
	var count := int(radius * 2.0 / spacing)
	var sewn := int(float(count) * minf(patch.progress / 0.7, 1.0))
	var diagonal := Vector2(1.0, -1.0).normalized()
	var across := Vector2(1.0, 1.0).normalized()
	var width := spacing * 0.95
	for index in range(sewn):
		var offset := (float(index) + 0.5) * spacing - radius
		var half := sqrt(maxf(radius * radius - offset * offset, 0.0))
		var mid := center + across * offset
		var drop := Vector2.ZERO
		var color := Color(patch.primary, fade)
		if unravel > 0.0:
			var line_seed := fposmod(sin(float(index) * 12.9898 + patch.noise_seed * 78.233) * 43758.5453, 1.0)
			drop = Vector2((line_seed - 0.5) * 30.0, unravel * unravel * (80.0 + line_seed * 140.0)) * scale
			color = Color(patch.primary.lerp(error_color, minf(unravel * 2.0, 1.0)), fade)
		draw_thread(mid - diagonal * half + drop, mid + diagonal * half + drop * 1.15, color, width)
	if patch.progress > 0.7:
		var ring := clampf((patch.progress - 0.7) / 0.3, 0.0, 1.0)
		var strokes := int(radius * TAU / (spacing * 1.2))
		for index in range(int(float(strokes) * ring)):
			var angle := float(index) / float(strokes) * TAU - PI * 0.5
			var direction := Vector2.from_angle(angle)
			var drop := Vector2(0.0, unravel * unravel * 120.0 * scale)
			draw_thread(center + direction * radius * 0.86 + drop, center + direction * radius * 1.02 + drop, Color(patch.secondary.lerp(error_color, minf(unravel * 2.0, 1.0)), fade), spacing * 0.9)
		if unravel <= 0.0:
			draw_motif(patch, center, radius, scale, Color(patch.secondary, fade * ring))
	if patch.border > 0.0:
		draw_gold_ring(center, radius * 1.18, patch.border, scale, alpha)
	if unravel > 0.0:
		draw_loose_ends(patch, center, radius, scale, alpha * (1.0 - unravel))
	pass


func draw_motif(patch: Patch, center: Vector2, radius: float, scale: float, color: Color) -> void:
	var width := 3.0 * scale
	match patch.motif:
		0:
			for petal in range(6):
				var angle := float(petal) * TAU / 6.0 + patch.noise_seed
				var points := PackedVector2Array()
				for step in range(13):
					var t := float(step) / 12.0 * TAU
					var local := Vector2(cos(t) * radius * 0.22 + radius * 0.3, sin(t) * radius * 0.1)
					points.append(center + local.rotated(angle))
				stitch_layer.draw_polyline(points, color, width, true)
			stitch_layer.draw_circle(center, radius * 0.1, color)
		1:
			var points := PackedVector2Array()
			for corner in range(11):
				var angle := float(corner) * TAU / 10.0 - PI * 0.5
				points.append(center + Vector2.from_angle(angle) * radius * (0.55 if corner % 2 == 0 else 0.24))
			for index in range(points.size() - 1):
				if index % 2 == 0:
					draw_thread(points[index], points[index + 1], color, width)
				else:
					stitch_layer.draw_line(points[index], points[index + 1], color, width * 0.8, true)
		_:
			for band in range(3):
				var points := PackedVector2Array()
				var y := (float(band) - 1.0) * radius * 0.28
				for step in range(17):
					var x := (float(step) / 16.0 - 0.5) * radius * 1.2
					points.append(center + Vector2(x, y + sin(float(step) * 0.8 + patch.noise_seed * 6.0) * radius * 0.08))
				stitch_layer.draw_polyline(points, color, width, true)
	pass


func draw_gold_ring(center: Vector2, radius: float, progress: float, scale: float, alpha: float) -> void:
	var dash := RUN_DASH_PX * 0.7 * scale
	var gap := RUN_GAP_PX * 0.7 * scale
	var circumference := radius * TAU
	var sewn := circumference * progress
	var along := 0.0
	var color := Color(GOLD, alpha)
	while along < sewn:
		var a0 := along / radius - PI * 0.5
		var a1 := minf(along + dash, sewn) / radius - PI * 0.5
		draw_thread(center + Vector2.from_angle(a0) * radius, center + Vector2.from_angle(a1) * radius, color, THREAD_WIDTH_PX * scale)
		along += dash + gap
	pass


func draw_loose_ends(patch: Patch, center: Vector2, radius: float, scale: float, alpha: float) -> void:
	for strand in range(5):
		var start_x := (float(strand) / 4.0 - 0.5) * radius * 1.2
		var points := PackedVector2Array()
		var length := radius * (0.9 + fposmod(patch.noise_seed * 7.0 + float(strand) * 0.37, 1.0) * 0.8)
		for step in range(11):
			var t := float(step) / 10.0
			var sway := sin(t * 5.0 + stitch_time * 2.0 + float(strand)) * 8.0 * scale * t
			points.append(center + Vector2(start_x + sway, radius * 0.6 + t * length))
		stitch_layer.draw_polyline(points, Color(error_color, alpha), 2.2 * scale, true)
	pass


func draw_needle(surface: Vector2, scale: float, alpha: float) -> void:
	if presence_target <= 0.0:
		return
	var bob := sin(stitch_time * 14.0) * 5.0 * scale
	var tip := Vector2(caret.x * surface.x + 6.0 * scale, (caret.y + LINE_HEIGHT * 0.82) * surface.y + bob)
	var direction := Vector2.from_angle(deg_to_rad(-28.0))
	var eye := tip - direction * 70.0 * scale
	var last_end := tip
	if not rows.is_empty():
		var last := rows[-1]
		last_end = Vector2(last.x1 * surface.x, (last.y + LINE_HEIGHT * 0.82) * surface.y)
	var sag := (eye + last_end) * 0.5 + Vector2(0.0, 30.0 * scale)
	var thread := PackedVector2Array()
	for step in range(9):
		var t := float(step) / 8.0
		thread.append(eye.lerp(sag, t).lerp(sag.lerp(last_end, t), t))
	stitch_layer.draw_polyline(thread, Color(thread_color, alpha * 0.9), 2.0 * scale, true)
	stitch_layer.draw_line(eye + Vector2(2.0, 3.0) * scale, tip + Vector2(2.0, 3.0) * scale, Color(shadow_color, shadow_color.a * alpha), 4.5 * scale, true)
	stitch_layer.draw_line(eye, tip, Color(needle_color, alpha), 3.5 * scale, true)
	stitch_layer.draw_line(eye + direction * 8.0 * scale, tip - direction * 10.0 * scale, Color(1.0, 1.0, 1.0, 0.6 * alpha), 1.2 * scale, true)
	var normal := Vector2(-direction.y, direction.x)
	var eye_center := eye + direction * 7.0 * scale
	var eye_points := PackedVector2Array()
	for step in range(13):
		var t := float(step) / 12.0 * TAU
		eye_points.append(eye_center + direction * cos(t) * 4.5 * scale + normal * sin(t) * 1.4 * scale)
	stitch_layer.draw_polyline(eye_points, Color(shadow_color, 0.6 * alpha), 1.0 * scale, true)
	pass


func update_theme_presentation() -> void:
	var dark := ThemeColor.is_dark_theme()
	thread_color = VisualColor.appearance_color(ThemeColor.accent_theme_color())
	basting_color = Color(0.62, 0.63, 0.66) if dark else Color(0.5, 0.51, 0.55)
	shadow_color = Color(0.0, 0.0, 0.0, 0.45 if dark else 0.28)
	highlight_color = Color(1.0, 1.0, 1.0, 0.4 if dark else 0.45)
	error_color = Colors.error
	needle_color = Color(0.8, 0.82, 0.86) if dark else Color(0.55, 0.57, 0.62)
	if fabric_material != null:
		fabric_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	pass
