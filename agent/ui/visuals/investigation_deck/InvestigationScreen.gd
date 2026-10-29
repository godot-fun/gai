class_name InvestigationScreen
extends Control

## One ring tile of the [InvestigationDeck] monitor, painted flat inside the deck's [SubViewport].
## [InvestigationStage] wraps copies of this texture around the ring with x pointing outward, so the
## layout is a tall column (`TILE_ASPECT`) read top to bottom: title, log field + dial, feed, signal,
## diff heat strip, dot matrix, trace, per-tool project bars, tool list, and dot rain.

const MATRIX_COLUMNS := 30
const MATRIX_ROWS := 18
const DIFF_COLUMNS := 12
const DIFF_ROWS := 6
const RAIN_COLUMNS := 24
const RAIN_ROWS := 26

var deck: InvestigationDeck


func _draw() -> void:
	if deck == null or size.x < 16.0 or size.y < 16.0:
		return
	var area := Rect2(Vector2.ZERO, size)
	var ts := clampi(int(size.x * 0.036), 9, 18)
	draw_rect(area, Color(deck.palette_screen, 0.96))
	var inner := area.grow_individual(-size.x * 0.07, -ts * 0.8, -size.x * 0.07, -ts * 0.8)
	draw_title(section(inner, 0.0, 0.025), ts)
	draw_log_field(section(inner, 0.03, 0.11), ts)
	draw_feed(section(inner, 0.115, 0.23), ts)
	draw_signal(section(inner, 0.235, 0.29), ts)
	draw_diff_field(section(inner, 0.295, 0.37), ts)
	draw_dot_matrix(section(inner, 0.375, 0.47))
	draw_trace(section(inner, 0.475, 0.52), ts)
	draw_project(section(inner, 0.525, 0.6), ts)
	draw_tools(section(inner, 0.605, 0.7), ts)
	draw_index(section(inner, 0.705, 0.85), ts)
	draw_rain(section(inner, 0.86, 1.0))
	pass


func section(inner: Rect2, from: float, to: float) -> Rect2:
	return Rect2(Vector2(inner.position.x, inner.position.y + inner.size.y * from), Vector2(inner.size.x, inner.size.y * (to - from)))


func label(at: Vector2, text: String, ts: int, alpha: float = 0.55) -> void:
	InvestigationDeck.mono(self, at, text, ts, deck.ink(alpha))
	pass


func heading(rect: Rect2, text: String, ts: int) -> void:
	label(rect.position + Vector2(0.0, ts), text, ts, 0.85)
	draw_line(rect.position + Vector2(0.0, ts * 1.35), Vector2(rect.end.x, rect.position.y + ts * 1.35), deck.ink(0.15), 1.0)
	pass


func body(rect: Rect2, ts: int) -> Rect2:
	return rect.grow_individual(0.0, -ts * 1.7, 0.0, 0.0)


func draw_title(rect: Rect2, ts: int) -> void:
	label(rect.position + Vector2(0.0, ts), "deck://run/%d" % deck.session_id, ts, 0.8)
	InvestigationDeck.mono_right(self, rect.position + Vector2(rect.size.x, ts), InvestigationDeck.format_clock(deck.clock), ts, deck.ink(0.6))
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), deck.ink(0.3), 1.0)
	pass


func draw_log_field(rect: Rect2, ts: int) -> void:
	heading(rect, "LOG FIELD", ts)
	var area := body(rect, ts)
	var radius := minf(area.size.y * 0.4, area.size.x * 0.14)
	var center := area.position + Vector2(radius * 1.15, area.size.y * 0.5)
	var activity := clampf(maxf(deck.reasoning_energy, deck.content_energy) + deck.tool_energy * 0.4, 0.0, 1.0)
	draw_arc(center, radius, 0.0, TAU, 40, deck.ink(0.2), 1.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * (0.08 + 0.92 * activity), 40, deck.ink(0.9), 2.5, true)
	draw_arc(center, radius * 1.18, deck.clock, deck.clock + 0.9, 16, deck.tint(deck.palette_hot, 0.5 + 0.5 * deck.turn_pulse), 1.5, true)
	var turn_text := "%02d" % deck.turn_count
	var turn_width := InvestigationDeck.mono_font().get_string_size(turn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	label(center + Vector2(-turn_width * 0.5, ts * 0.35), turn_text, ts, 0.95)
	var values: Array[float] = [deck.reasoning_energy, deck.content_energy, deck.tool_energy, clampf(deck.token_count() / 5000.0, 0.0, 1.0)]
	var names: Array[String] = ["THK", "WRT", "TOL", "TOK"]
	var left := center.x + radius * 1.5
	var row := area.size.y / float(values.size())
	for index in range(values.size()):
		var y := area.position.y + row * (index + 0.5)
		label(Vector2(left, y + ts * 0.35), names[index], ts - 2, 0.5)
		var bar := Rect2(Vector2(left + ts * 2.2, y - ts * 0.2), Vector2(area.end.x - left - ts * 5.2, ts * 0.4))
		draw_rect(bar, deck.ink(0.1))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * values[index], bar.size.y)), deck.ink(0.85))
		InvestigationDeck.mono_right(self, Vector2(area.end.x, y + ts * 0.35), "%.2f" % values[index], ts - 2, deck.ink(0.6))
	pass


func draw_feed(rect: Rect2, ts: int) -> void:
	heading(rect, "FEED %02d" % deck.feed.size(), ts)
	var area := body(rect, ts)
	var line := ts * 1.3
	var rows := maxi(int(area.size.y / line), 1)
	var start := maxi(deck.feed.size() - rows, 0)
	var max_chars := int((area.size.x - ts * 3.4) / (ts * 0.6))
	for index in range(start, deck.feed.size()):
		var entry := deck.feed[index]
		var y := area.position.y + ts + line * (index - start)
		InvestigationDeck.mono(self, Vector2(area.position.x, y), InvestigationDeck.TAG_TEXTS[entry.tag].left(2), ts - 2, deck.tint(deck.tag_color(entry.tag), 0.9))
		label(Vector2(area.position.x + ts * 1.8, y), InvestigationDeck.clip_text(entry.text, max_chars), ts - 2, 0.6)
	pass


## Interference of the reasoning and answer envelopes, drawn as one dense oscillating trace.
func draw_signal(rect: Rect2, ts: int) -> void:
	heading(rect, "SIGNAL", ts)
	var area := body(rect, ts)
	var middle := area.get_center().y
	var points := PackedVector2Array()
	var count := 90
	for index in range(count):
		var t := float(index) / float(count - 1)
		var sample := deck.reasoning_history[int(t * (deck.reasoning_history.size() - 1))] + deck.content_history[int(t * (deck.content_history.size() - 1))]
		var envelope := (0.15 + 0.85 * minf(sample * 1.8, 1.0)) * area.size.y * 0.45
		points.append(Vector2(area.position.x + t * area.size.x, middle - envelope * sin(t * 60.0 + deck.clock * 6.0) * cos(t * 7.0 - deck.clock)))
	draw_polyline(points, deck.ink(0.8), 1.0, true)
	pass


func draw_diff_field(rect: Rect2, ts: int) -> void:
	heading(rect, "DIFF FIELD", ts)
	var area := body(rect, ts)
	var grid := Rect2(area.position, Vector2(area.size.x * 0.68, area.size.y))
	var cell := Vector2(grid.size.x / float(DIFF_COLUMNS), grid.size.y / float(DIFF_ROWS))
	var heat := deck.heat
	for row in range(DIFF_ROWS):
		for column in range(DIFF_COLUMNS):
			var value := heat[(row * DIFF_COLUMNS + column * 3 + 5) % heat.size()]
			var color := deck.palette_violet if (row + column) % 3 != 0 else deck.palette_hot
			draw_rect(Rect2(grid.position + Vector2(column * cell.x, row * cell.y), cell - Vector2(1.0, 1.0)), deck.tint(color, 0.08 + 0.85 * value))
	var trace := Rect2(Vector2(grid.end.x + ts * 0.6, grid.position.y), Vector2(area.end.x - grid.end.x - ts * 0.6, grid.size.y))
	var history := deck.tool_history
	var bars := 6
	var bar_width := trace.size.x / float(bars)
	for bar in range(bars):
		var value := history[history.size() - bars + bar] if history.size() >= bars else 0.0
		var height := trace.size.y * (0.08 + 0.92 * value)
		draw_rect(Rect2(Vector2(trace.position.x + bar * bar_width, trace.end.y - height), Vector2(bar_width - 2.0, height)), deck.ink(0.7))
	pass


## Dot matrix flickers faster and denser while tokens stream, like a readout scanning the answer.
func draw_dot_matrix(rect: Rect2) -> void:
	var energy := maxf(deck.reasoning_energy, deck.content_energy)
	var tick := floorf(deck.clock * (3.0 + 18.0 * energy))
	var density := 0.16 + 0.6 * energy
	var cell := Vector2(rect.size.x / float(MATRIX_COLUMNS), rect.size.y / float(MATRIX_ROWS))
	var plain := PackedVector2Array()
	var tinted := PackedVector2Array()
	for row in range(MATRIX_ROWS):
		for column in range(MATRIX_COLUMNS):
			var roll := InvestigationDeck.hash01(column, row, tick + floorf(column / 7.0))
			if roll >= density:
				continue
			var at := rect.position + Vector2(column * cell.x, row * cell.y + cell.y * 0.5)
			var dash := at + Vector2(maxf(cell.x * 0.6, 2.0), 0.0)
			if roll < density * 0.22:
				tinted.append_array(PackedVector2Array([at, dash]))
			else:
				plain.append_array(PackedVector2Array([at, dash]))
	var thickness := maxf(cell.y * 0.45, 1.5)
	if not plain.is_empty():
		draw_multiline(plain, deck.ink(0.6), thickness)
	if not tinted.is_empty():
		draw_multiline(tinted, deck.tint(deck.palette_violet, 0.85), thickness)
	draw_rect(rect, deck.ink(0.15), false, 1.0)
	pass


func draw_trace(rect: Rect2, ts: int) -> void:
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, deck.ink(0.25), 1.0)
	for tick in range(9):
		var x := rect.position.x + rect.size.x * tick / 8.0
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y - ts * 0.4), deck.ink(0.3), 1.0)
	draw_history(rect, deck.reasoning_history, deck.palette_violet)
	draw_history(rect, deck.content_history, deck.palette_ink)
	pass


func draw_history(rect: Rect2, history: PackedFloat32Array, color: Color) -> void:
	if history.size() < 2:
		return
	var points := PackedVector2Array()
	for index in range(history.size()):
		var x := rect.position.x + rect.size.x * index / float(history.size() - 1)
		points.append(Vector2(x, rect.end.y - rect.size.y * 0.9 * minf(history[index] * 1.6, 1.0)))
	draw_polyline(points, deck.tint(color, 0.85), 1.2, true)
	pass


func draw_project(rect: Rect2, ts: int) -> void:
	heading(rect, "PROJECT", ts)
	var area := body(rect, ts)
	var names := deck.ranked_tools()
	var rows := 5
	var row := area.size.y / float(rows)
	var busiest := 1.0
	if not names.is_empty():
		busiest = float(deck.tool_stats[names[0]].x)
	var bar_left := area.position.x + area.size.x * 0.36
	var bar_width := area.size.x * 0.5
	for index in range(rows):
		var y := area.position.y + row * (index + 0.5)
		var bar := Rect2(Vector2(bar_left, y - row * 0.22), Vector2(bar_width, row * 0.44))
		draw_rect(bar, deck.ink(0.07))
		if index >= names.size():
			continue
		var stat := deck.tool_stats[names[index]]
		label(Vector2(area.position.x, y + ts * 0.3), InvestigationDeck.clip_text(names[index], 9), ts - 2, 0.7)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * stat.x / busiest, bar.size.y)), deck.tint(deck.palette_lime, 0.8))
		InvestigationDeck.mono_right(self, Vector2(area.end.x, y + ts * 0.3), "%d" % stat.x, ts - 2, deck.tint(deck.palette_lime, 0.85))
	pass


func draw_tools(rect: Rect2, ts: int) -> void:
	heading(rect, "TOOLS %d/%d" % [deck.finished_tools(), deck.tool_total], ts)
	var area := body(rect, ts)
	var line := ts * 1.3
	var rows := maxi(int(area.size.y / line), 1)
	var max_chars := int((area.size.x - ts * 1.4) / (ts * 0.6))
	var row := 0
	for index in range(deck.tracks.size() - 1, -1, -1):
		if row >= rows:
			break
		var track := deck.tracks[index]
		var y := area.position.y + ts + line * row
		var color := deck.palette_hot
		var marker := ">"
		if not track.is_running():
			marker = "x" if track.failed else "+"
			color = deck.palette_error if track.failed else deck.palette_lime
		InvestigationDeck.mono(self, Vector2(area.position.x, y), marker, ts - 2, deck.tint(color, 0.9))
		label(Vector2(area.position.x + ts, y), InvestigationDeck.clip_text(track.name + " " + track.detail, max_chars), ts - 2, 0.65)
		row += 1
	pass


## Numeric readout of the heat index: hot cells print bright, the rest stay as faint telemetry.
func draw_index(rect: Rect2, ts: int) -> void:
	heading(rect, "INDEX", ts)
	var area := body(rect, ts)
	var columns := 4
	var line := ts * 1.2
	var rows := maxi(int(area.size.y / line), 1)
	var column_width := area.size.x / float(columns)
	var heat := deck.heat
	for row in range(rows):
		for column in range(columns):
			var value := heat[(row * columns + column) % heat.size()]
			var at := Vector2(area.position.x + column * column_width, area.position.y + ts + line * row)
			var color := deck.palette_hot if value > 0.6 else deck.palette_ink
			InvestigationDeck.mono(self, at, "%02X.%02d" % [row * columns + column, int(value * 99.0)], ts - 2, deck.tint(color, 0.25 + 0.7 * value))
	pass


## Falling dot columns; each column keeps its own phase so the rain never syncs into rows. Speed
## rides `scratch_travel`, which already accumulates faster while tokens stream.
func draw_rain(rect: Rect2) -> void:
	var cell := Vector2(rect.size.x / float(RAIN_COLUMNS), rect.size.y / float(RAIN_ROWS))
	var dim := PackedVector2Array()
	var lit := PackedVector2Array()
	for column in range(RAIN_COLUMNS):
		var phase := InvestigationDeck.hash01(column, 3.0, 7.0)
		var head := fposmod(deck.scratch_travel * 3.0 * (0.6 + phase) + phase, 1.0) * float(RAIN_ROWS)
		for row in range(RAIN_ROWS):
			var at := rect.position + Vector2(column * cell.x + cell.x * 0.3, row * cell.y + cell.y * 0.5)
			var dot := PackedVector2Array([at, at + Vector2(2.0, 0.0)])
			var behind := fposmod(head - float(row), float(RAIN_ROWS))
			if behind < 1.0:
				lit.append_array(dot)
			elif behind < 7.0 or InvestigationDeck.hash01(column, row, 1.0) < 0.25:
				dim.append_array(dot)
	if not dim.is_empty():
		draw_multiline(dim, deck.ink(0.3), 2.0)
	if not lit.is_empty():
		draw_multiline(lit, deck.ink(0.95), 2.0)
	pass
