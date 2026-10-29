class_name InvestigationScreen
extends Control

## One ring tile of the [InvestigationDeck] monitor, painted flat inside the deck's [SubViewport].
## [InvestigationStage] wraps copies of this texture around the ring with x pointing outward, so the
## layout is a tall column (`TILE_ASPECT`) read top to bottom: session title, run stats, then the
## eight run panels (feed, solver, workspace, field, matrix, buffer, dispatch, heat index).
## Every mark is driven by run state; empty panels stay empty rather than showing filler.

var deck: InvestigationDeck


func _draw() -> void:
	if deck == null or size.x < 16.0 or size.y < 16.0:
		return
	var area := Rect2(Vector2.ZERO, size)
	var ts := clampi(int(size.x * 0.038), 9, 22)
	draw_rect(area, Color(deck.palette_screen, 0.96))
	var inner := area.grow_individual(-size.x * 0.07, -ts * 0.8, -size.x * 0.07, -ts * 0.8)
	draw_title(section(inner, 0.0, 0.03), ts)
	draw_stats(section(inner, 0.035, 0.1), ts)
	var spans: Array[Vector2] = [
		Vector2(0.105, 0.25), Vector2(0.255, 0.345), Vector2(0.35, 0.45), Vector2(0.455, 0.545),
		Vector2(0.55, 0.65), Vector2(0.655, 0.75), Vector2(0.755, 0.865), Vector2(0.87, 1.0),
	]
	for index in range(spans.size()):
		var rect := section(inner, spans[index].x, spans[index].y)
		heading(rect, I18n.t(InvestigationDeck.PANEL_TITLES[index]), ts)
		var content := body(rect, ts)
		match index:
			0:
				draw_feed(content, ts)
			1:
				draw_solver(content, ts)
			2:
				draw_workspace(content, ts)
			3:
				draw_field(content, ts)
			4:
				draw_matrix(content, ts)
			5:
				draw_buffer(content, ts)
			6:
				draw_dispatch(content, ts)
			7:
				draw_heat_index(content)
	pass


func section(inner: Rect2, from: float, to: float) -> Rect2:
	return Rect2(Vector2(inner.position.x, inner.position.y + inner.size.y * from), Vector2(inner.size.x, inner.size.y * (to - from)))


func label(at: Vector2, text: String, ts: int, alpha: float = 0.55) -> void:
	InvestigationDeck.mono(self, at, text, ts, deck.ink(alpha))
	pass


func heading(rect: Rect2, text: String, ts: int) -> void:
	label(rect.position + Vector2(0.0, ts), text, ts - 1, 0.85)
	draw_line(rect.position + Vector2(0.0, ts * 1.35), Vector2(rect.end.x, rect.position.y + ts * 1.35), deck.ink(0.15), 1.0)
	pass


func body(rect: Rect2, ts: int) -> Rect2:
	return rect.grow_individual(0.0, -ts * 1.8, 0.0, 0.0)


func row_height(ts: int) -> float:
	return ts * 1.35


func max_chars(width: float, ts: int) -> int:
	return maxi(int(width / (ts * 0.6)), 1)


func draw_title(rect: Rect2, ts: int) -> void:
	var title := I18n.t("agent.visuals.deck_title") + " / " + StringUtils.format(I18n.t("agent.visuals.deck_session"), deck.session_id)
	label(rect.position + Vector2(0.0, ts), InvestigationDeck.clip_text(title, max_chars(rect.size.x * 0.7, ts)), ts, 0.9)
	var meta := I18n.t(deck.phase_key()) + " · " + InvestigationDeck.format_clock(deck.clock)
	InvestigationDeck.mono_right(self, rect.position + Vector2(rect.size.x, ts), meta, ts - 2, deck.ink(0.5))
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), deck.ink(0.3), 1.0)
	pass


func draw_stats(rect: Rect2, ts: int) -> void:
	var running := deck.running_tools()
	var labels: Array[String] = ["deck_tokens", "deck_turns", "deck_tools", "deck_active", "deck_errors"]
	var values: Array[String] = [InvestigationDeck.compact_count(deck.token_count()), str(deck.turn_count), str(deck.tool_total), str(running), str(deck.tool_failed)]
	var column := rect.size.x / float(labels.size())
	for index in range(labels.size()):
		var x := rect.position.x + column * index
		if index > 0:
			draw_line(Vector2(x - ts * 0.3, rect.position.y + ts * 0.3), Vector2(x - ts * 0.3, rect.end.y - ts * 0.3), deck.ink(0.12), 1.0)
		var color := deck.palette_ink
		if index == 3 and running > 0:
			color = deck.palette_hot
		elif index == 4 and deck.tool_failed > 0:
			color = deck.palette_error
		label(Vector2(x, rect.position.y + ts * 1.2), InvestigationDeck.clip_text(I18n.t("agent.visuals." + labels[index]), max_chars(column - ts * 0.6, ts - 3)), ts - 3, 0.45)
		InvestigationDeck.mono(self, Vector2(x, rect.position.y + ts * 2.9), values[index], ts + 4, deck.tint(color, 0.95))
	pass


func draw_feed(area: Rect2, ts: int) -> void:
	var rows := maxi(int(area.size.y / row_height(ts)), 1)
	var start := maxi(deck.feed.size() - rows, 0)
	var chars := max_chars(area.size.x - ts * 5.4, ts - 2)
	for index in range(start, deck.feed.size()):
		var entry := deck.feed[index]
		var y := area.position.y + ts + row_height(ts) * (index - start)
		var newest := index == deck.feed.size() - 1
		label(Vector2(area.position.x, y), "%02d" % (entry.serial % 100), ts - 2, 0.3)
		InvestigationDeck.mono(self, Vector2(area.position.x + ts * 1.5, y), InvestigationDeck.TAG_TEXTS[entry.tag], ts - 2, deck.tint(deck.tag_color(entry.tag), 0.92))
		label(Vector2(area.position.x + ts * 4.6, y), InvestigationDeck.clip_text(entry.text, chars), ts - 2, 0.85 if newest else 0.5)
	pass


## Stream dots (x = arrival order, y = chunk length) over the think / write share of characters.
func draw_solver(area: Rect2, ts: int) -> void:
	var field := Rect2(area.position, Vector2(area.size.x, area.size.y - ts * 1.8))
	for dot: Vector4 in deck.dots:
		var at := field.position + Vector2(dot.x, clampf(dot.y, 0.0, 1.0)) * field.size
		var color := deck.palette_violet if dot.w > 0.5 else deck.palette_ink
		draw_rect(Rect2(at, Vector2(3.0, 3.0)), deck.tint(color, 0.2 + 0.7 * dot.z))
	var bar := Rect2(Vector2(area.position.x, area.end.y - ts * 1.2), Vector2(area.size.x * 0.6, ts * 1.1))
	var total := maxf(float(deck.reasoning_chars + deck.content_chars), 1.0)
	draw_rect(bar, deck.ink(0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * deck.reasoning_chars / total, bar.size.y)), deck.tint(deck.palette_violet, 0.55))
	label(bar.position + Vector2(ts * 0.4, ts * 0.85), "THINK / WRITE", ts - 3, 0.85)
	InvestigationDeck.mono_right(self, Vector2(area.end.x, area.end.y - ts * 0.3), "N=%d" % deck.dots.size(), ts - 2, deck.ink(0.55))
	pass


func draw_workspace(area: Rect2, ts: int) -> void:
	var rows := maxi(int(area.size.y / row_height(ts)), 1)
	var chars := max_chars(area.size.x - ts * 1.4, ts - 2)
	var row := 0
	for index in range(deck.tracks.size() - 1, -1, -1):
		if row >= rows:
			break
		var track := deck.tracks[index]
		var y := area.position.y + ts + row_height(ts) * row
		var marker := ">"
		var color := deck.palette_hot
		if not track.is_running():
			marker = "x" if track.failed else "+"
			color = deck.palette_error if track.failed else deck.palette_lime
		InvestigationDeck.mono(self, Vector2(area.position.x, y), marker, ts - 2, deck.tint(color, 0.9))
		label(Vector2(area.position.x + ts * 1.2, y), InvestigationDeck.clip_text(track.name + "  " + track.detail, chars), ts - 2, 0.85 if track.is_running() else 0.5)
		row += 1
	pass


## Think / write energy levels, then the chunk-length histogram.
func draw_field(area: Rect2, ts: int) -> void:
	var energies: Array[float] = [deck.reasoning_energy, deck.content_energy]
	var names: Array[String] = ["THINK", "WRITE"]
	for index in range(2):
		var y := area.position.y + row_height(ts) * (index + 0.5)
		label(Vector2(area.position.x, y + ts * 0.35), names[index], ts - 3, 0.5)
		var bar := Rect2(Vector2(area.position.x + ts * 3.2, y - ts * 0.25), Vector2(area.size.x - ts * 6.4, ts * 0.5))
		draw_rect(bar, deck.ink(0.1))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(energies[index], 0.0, 1.0), bar.size.y)), deck.ink(0.85))
		InvestigationDeck.mono_right(self, Vector2(area.end.x, y + ts * 0.35), "%.2f" % energies[index], ts - 3, deck.ink(0.6))
	var top := area.position.y + row_height(ts) * 2.2
	var chart := Rect2(Vector2(area.position.x, top), Vector2(area.size.x, area.end.y - top))
	var peak := 1.0
	for value: float in deck.histogram:
		peak = maxf(peak, value)
	var bin_width := chart.size.x / float(InvestigationDeck.HISTOGRAM_BINS)
	for bin in range(InvestigationDeck.HISTOGRAM_BINS):
		var height := chart.size.y * deck.histogram[bin] / peak
		draw_rect(Rect2(Vector2(chart.position.x + bin * bin_width, chart.end.y - height), Vector2(bin_width - 1.0, height)), deck.ink(0.55))
	draw_line(Vector2(chart.position.x, chart.end.y), chart.end, deck.ink(0.25), 1.0)
	pass


func draw_matrix(area: Rect2, ts: int) -> void:
	var columns: Array[float] = [0.0, 0.46, 0.62, 0.78]
	var headers: Array[String] = ["SOURCE", "CALLS", "FAILS", "LOAD"]
	for index in range(headers.size()):
		label(Vector2(area.position.x + area.size.x * columns[index], area.position.y + ts), headers[index], ts - 3, 0.4)
	var names := deck.ranked_tools()
	if names.is_empty():
		return
	var rows := maxi(int(area.size.y / row_height(ts)) - 1, 1)
	var busiest := float(deck.tool_stats[names[0]].x)
	var chars := max_chars(area.size.x * 0.44, ts - 2)
	for row in range(mini(rows, names.size())):
		var stat := deck.tool_stats[names[row]]
		var y := area.position.y + ts + row_height(ts) * (row + 1)
		label(Vector2(area.position.x, y), InvestigationDeck.clip_text(names[row], chars), ts - 2, 0.8)
		label(Vector2(area.position.x + area.size.x * columns[1], y), "%02d" % stat.x, ts - 2, 0.7)
		InvestigationDeck.mono(self, Vector2(area.position.x + area.size.x * columns[2], y), "%02d" % stat.y, ts - 2, deck.tint(deck.palette_error if stat.y > 0 else deck.palette_ink, 0.7))
		var chip := Rect2(Vector2(area.position.x + area.size.x * columns[3], y - ts * 0.75), Vector2(area.size.x * 0.2 * stat.x / busiest, ts * 0.9))
		draw_rect(chip, deck.tint(deck.palette_hot if stat.y > 0 else deck.palette_ink, 0.6))
	pass


## Sampled think / write / tool energy histories, one lane each.
func draw_buffer(area: Rect2, ts: int) -> void:
	var buffers: Array[PackedFloat32Array] = [deck.reasoning_history, deck.content_history, deck.tool_history]
	var names: Array[String] = ["THINK", "WRITE", "TOOL"]
	var colors: Array[Color] = [deck.palette_violet, deck.palette_ink, deck.palette_hot]
	var lane := area.size.y / 3.0
	var left := area.position.x + ts * 3.2
	var width := area.end.x - left
	for lane_index in range(3):
		var floor_y := area.position.y + lane * (lane_index + 1) - lane * 0.12
		label(Vector2(area.position.x, floor_y), names[lane_index], ts - 3, 0.45)
		draw_line(Vector2(left, floor_y), Vector2(area.end.x, floor_y), deck.ink(0.1), 1.0)
		var buffer := buffers[lane_index]
		if buffer.size() < 2:
			continue
		var points := PackedVector2Array()
		for index in range(buffer.size()):
			points.append(Vector2(left + width * index / float(buffer.size() - 1), floor_y - minf(buffer[index] * 1.6, 1.0) * lane * 0.75))
		draw_polyline(points, deck.tint(colors[lane_index], 0.8), 1.2, true)
	pass


## Recent tool calls with elapsed time; bar length is relative to the longest call shown.
func draw_dispatch(area: Rect2, ts: int) -> void:
	var rows := mini(maxi(int(area.size.y / row_height(ts)), 1), deck.tracks.size())
	var longest := 0.001
	for row in range(rows):
		longest = maxf(longest, deck.tracks[deck.tracks.size() - 1 - row].seconds(deck.clock))
	var bar_left := area.position.x + area.size.x * 0.34
	var bar_width := area.size.x * 0.42
	for row in range(rows):
		var track := deck.tracks[deck.tracks.size() - 1 - row]
		var y := area.position.y + ts + row_height(ts) * row
		label(Vector2(area.position.x, y), InvestigationDeck.clip_text(track.name, max_chars(area.size.x * 0.32, ts - 2)), ts - 2, 0.8)
		var bar := Rect2(Vector2(bar_left, y - ts * 0.65), Vector2(bar_width, ts * 0.65))
		draw_rect(bar, deck.ink(0.08))
		var color := deck.palette_lime
		var status := "%.1fs" % track.seconds(deck.clock)
		if track.is_running():
			color = deck.palette_hot
			status = "run " + status
		elif track.failed:
			color = deck.palette_error
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * track.seconds(deck.clock) / longest, bar.size.y)), deck.tint(color, 0.7))
		InvestigationDeck.mono_right(self, Vector2(area.end.x, y), status, ts - 3, deck.ink(0.6))
	pass


func draw_heat_index(area: Rect2) -> void:
	var columns := InvestigationDeck.HEAT_COLUMNS
	var rows := InvestigationDeck.HEAT_ROWS
	var cell := Vector2(area.size.x / float(columns), area.size.y / float(rows))
	for row in range(rows):
		for column in range(columns):
			var value := deck.heat[row * columns + column]
			var color := deck.palette_ink if value > 0.85 else deck.palette_hot
			draw_rect(Rect2(area.position + Vector2(column * cell.x, row * cell.y), cell - Vector2(1.0, 1.0)), deck.tint(color, 0.05 + 0.8 * value))
	pass
