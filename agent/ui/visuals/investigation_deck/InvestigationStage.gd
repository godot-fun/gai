class_name InvestigationStage
extends Control

## Stage of [InvestigationDeck]: three concentric layers around a hub left of the stage, clipped to
## this control so the beams end at the stage edge.
## - Disc: child controls drawn behind this one (`show_behind_parent`). Four static web layers are
##   painted once in unit-disc space and only re-posed each frame (position, spin, scale, pulse
##   alpha), so 2000 curves cost a transform, not a redraw. A runner layer shares the spin; a comet
##   layer stays unspun because comets follow the ring, and also carries the ring shadow.
## - Ring: [InvestigationScreen] tiles mapped around the annulus with `draw_primitive`; radial
##   texture x reads outward, so text sits upright on the visible right-hand side.
## - Beams: fine hairlines, travelling shafts, and emitted pulses beyond the outer rail.
## Ring and beams both turn on `deck.outer_angle`; every radius scales with `deck.zoom`.

const SEGMENTS_PER_TILE := 20
const RIB_COUNT := 720
const CIRCLE_POINTS := 256
const WEB_SEGMENTS := 8
const RUNNER_TAIL := 4
const COMET_STEPS := 12
const COMET_HEAD_STEPS := 5
## Ring shadow starts this far inside the rim (unit-disc radius), darkening the web toward the ring.
const SHADOW_INNER := 0.8
const SHADOW_SEGMENTS := 96
## Thousands of overlapping hairlines add up; this keeps the woven field a backdrop to the runners.
const WEB_ALPHA_SCALE := 0.5

var deck: InvestigationDeck
## Base web layer then three pulse layers; all share the disc pose.
var web_layers: Array[Control] = []
var runner_layer: Control
var comet_layer: Control
## Disc radius (px) when the web layers were last painted; their labels are sized against it.
var web_radius: float = 0.0


func _ready() -> void:
	for index in range(4):
		var layer := add_disc_layer()
		layer.draw.connect(draw_web_layer.bind(layer, index - 1))
		web_layers.append(layer)
	runner_layer = add_disc_layer()
	runner_layer.draw.connect(draw_runners)
	comet_layer = add_disc_layer()
	comet_layer.draw.connect(draw_comets)
	gdf.events.theme_changed.connect(repaint_web)
	gdf.events.theme_color_changed.connect(repaint_web)
	pass


func add_disc_layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	add_child(layer)
	return layer


func repaint_web() -> void:
	web_radius = 0.0
	pass


## Re-poses the disc layers for this frame; repaints the static web only when the stage resizes.
func sync_layers() -> void:
	if deck == null or web_layers.is_empty():
		return
	var radius := disc_radius()
	var base_radius := size.y * InvestigationDeck.DISC_RADIUS_RATIO
	if absf(base_radius - web_radius) > 1.0:
		web_radius = base_radius
		for layer: Control in web_layers:
			layer.queue_redraw()
	for index in range(web_layers.size()):
		var layer := web_layers[index]
		layer.position = hub()
		layer.rotation = deck.inner_angle
		layer.scale = Vector2(radius, radius)
		var pulse := 1.0 if index == 0 else 0.1 + 0.8 * deck.layer_env[index - 1]
		layer.modulate = Color(1.0, 1.0, 1.0, pulse * deck.draw_alpha)
	runner_layer.position = hub()
	runner_layer.rotation = deck.inner_angle
	runner_layer.scale = Vector2(radius, radius)
	runner_layer.queue_redraw()
	comet_layer.position = hub()
	comet_layer.scale = Vector2(radius, radius)
	comet_layer.queue_redraw()
	pass


func disc_radius() -> float:
	return inner_radius() - 1.5


func hub() -> Vector2:
	return Vector2(size.y * InvestigationDeck.HUB_X_RATIO, size.y * 0.5)


func inner_radius() -> float:
	return size.y * InvestigationDeck.DISC_RADIUS_RATIO * deck.zoom


func outer_radius() -> float:
	return inner_radius() + size.y * InvestigationDeck.RING_THICKNESS_RATIO * deck.zoom


func rail_width() -> float:
	return size.y * 0.03 * deck.zoom


func _draw() -> void:
	if deck == null or size.x < 16.0 or size.y < 16.0:
		return
	draw_beams()
	draw_ring()
	draw_labels()
	draw_end_scan()
	pass


func web_color(hue: int, alpha: float) -> Color:
	match hue:
		1:
			return VisualColor.stroke(deck.palette_hot, alpha)
		2:
			return VisualColor.stroke(deck.palette_violet, alpha)
	return VisualColor.stroke(deck.palette_ink, alpha)


## One web layer in unit-disc space ([param layer] -1 is the base). Pulse layers are painted at full
## authored alpha and faded by the layer's modulate, so a pulse never repaints geometry.
func draw_web_layer(canvas: Control, layer: int) -> void:
	if deck == null or web_radius <= 1.0:
		return
	if layer < 0:
		canvas.draw_circle(Vector2.ZERO, 1.0, Color(deck.palette_screen, 0.55))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for curve in range(deck.web_layers.size()):
		if deck.web_layers[curve] != layer:
			continue
		var color := web_color(deck.web_hues[curve], deck.web_alphas[curve] * WEB_ALPHA_SCALE)
		var previous := deck.web_point(curve, 0.0)
		for step in range(1, WEB_SEGMENTS + 1):
			var next := deck.web_point(curve, float(step) / float(WEB_SEGMENTS))
			points.append(previous)
			points.append(next)
			colors.append(color)
			previous = next
	if not points.is_empty():
		canvas.draw_multiline_colors(points, colors)
	if layer < 0:
		draw_web_nodes(canvas)
	pass


## Node markers and dotted ring chains, authored in pixels at `web_radius` then mapped to unit space.
func draw_web_nodes(canvas: Control) -> void:
	var px := 1.0 / web_radius
	var font := InvestigationDeck.mono_font()
	var label_color := VisualColor.stroke(deck.palette_ink, 0.5)
	for index in range(deck.web_nodes.size()):
		var node := deck.web_nodes[index]
		var at := Vector2(node.x, node.y)
		var color := VisualColor.stroke(deck.palette_ink, 0.35 + 0.45 * InvestigationDeck.hash01(index, 2.0, 9.0))
		canvas.draw_arc(at, node.z * px, 0.0, TAU, 14, color, -1.0)
		if InvestigationDeck.hash01(index, 4.0, 1.0) < 0.4:
			canvas.draw_arc(at + Vector2(node.z * 2.2 * px, 0.0), node.z * 0.8 * px, 0.0, TAU, 12, color, -1.0)
		var label := deck.web_labels[index]
		if not label.is_empty():
			canvas.draw_set_transform(at + Vector2(7.0 * px, 2.0 * px), 0.0, Vector2(px, px))
			canvas.draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, label_color)
			canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var chain_color := VisualColor.stroke(deck.palette_ink, 0.55)
	for chain: Vector3 in deck.web_chains:
		for index in range(int(chain.z)):
			var angle := chain.y + float(index) * 0.022
			canvas.draw_arc(Vector2.from_angle(angle) * chain.x, 2.2 * px, 0.0, TAU, 8, chain_color, -1.0)
	pass


## Runners: short fading tails along their web curve, sharing the disc spin.
func draw_runners() -> void:
	if deck == null:
		return
	var radius := maxf(disc_radius(), 1.0)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var accent_points := PackedVector2Array()
	var accent_colors := PackedColorArray()
	for runner: InvestigationDeck.Runner in deck.runners:
		var tail := clampf(runner.speed * 0.35, 0.02, 0.18)
		var previous := deck.web_point(runner.curve, maxf(runner.t - tail, 0.0))
		for step in range(1, RUNNER_TAIL + 1):
			var k := float(step) / float(RUNNER_TAIL)
			var next := deck.web_point(runner.curve, maxf(runner.t - tail * (1.0 - k), 0.0))
			if runner.accent:
				accent_points.append_array(PackedVector2Array([previous, next]))
				accent_colors.append(deck.tint(deck.palette_hot, 0.9 * k))
			else:
				points.append_array(PackedVector2Array([previous, next]))
				colors.append(deck.ink(0.5 * k))
			previous = next
	if not points.is_empty():
		runner_layer.draw_multiline_colors(points, colors, 0.9 / radius)
	if not accent_points.is_empty():
		runner_layer.draw_multiline_colors(accent_points, accent_colors, 1.3 / radius)
	pass


## Ring shadow, then comets. Unspun: comets follow the ring by rotating with `outer_angle - rot0`.
func draw_comets() -> void:
	if deck == null:
		return
	draw_ring_shadow()
	var radius := maxf(disc_radius(), 1.0)
	for comet: InvestigationDeck.Comet in deck.comets:
		var span := comet.progress()
		if span.y <= span.x or span.z <= 0.0:
			continue
		var turn := deck.outer_angle - comet.rot0
		var color := deck.palette_violet if comet.tint else deck.palette_ink
		var neck := span.y - (span.y - span.x) * 0.35
		comet_layer.draw_multiline(comet_strokes(comet, span.x, span.y, COMET_STEPS, turn), deck.tint(color, 0.5 * span.z), 1.0 / radius)
		comet_layer.draw_multiline(comet_strokes(comet, neck, span.y, COMET_HEAD_STEPS, turn), deck.tint(color, span.z), 1.7 / radius)
	pass


func comet_strokes(comet: InvestigationDeck.Comet, from: float, to: float, steps: int, turn: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for line: PackedFloat32Array in comet.lines:
		var previous := comet.point(line, from).rotated(turn)
		for step in range(1, steps + 1):
			var next := comet.point(line, lerpf(from, to, float(step) / float(steps))).rotated(turn)
			points.append(previous)
			points.append(next)
			previous = next
	return points


## Darkens the web toward the ring so the disc and the ring read as separate planes.
func draw_ring_shadow() -> void:
	var clear := Color(deck.palette_back, 0.0)
	var dark := Color(deck.palette_back, 0.8 * deck.draw_alpha)
	for index in range(SHADOW_SEGMENTS):
		var a0 := Vector2.from_angle(TAU * float(index) / float(SHADOW_SEGMENTS))
		var a1 := Vector2.from_angle(TAU * float(index + 1) / float(SHADOW_SEGMENTS))
		comet_layer.draw_primitive(PackedVector2Array([a0 * SHADOW_INNER, a0, a1, a1 * SHADOW_INNER]),
			PackedColorArray([clear, dark, dark, clear]), PackedVector2Array())
	pass


## Outer layer, turning with the ring: dense hairlines (a moiré at distance), travelling shafts,
## and pulses emitted by tools and answer tokens.
func draw_beams() -> void:
	var center := hub()
	var start := outer_radius() + rail_width() * 1.6
	var far := start + size.x + size.y
	var fade := 1.0 - deck.end_progress
	var faint := PackedVector2Array()
	var bright := PackedVector2Array()
	for beam: Vector2 in deck.fine_beams:
		var direction := Vector2.from_angle(beam.x + deck.outer_angle)
		if direction.x < -0.2:
			continue
		if beam.y > 0.5:
			bright.append_array(PackedVector2Array([center + direction * start, center + direction * far]))
		else:
			faint.append_array(PackedVector2Array([center + direction * start, center + direction * far]))
	if not faint.is_empty():
		draw_multiline(faint, deck.ink(0.1 * fade))
	if not bright.is_empty():
		draw_multiline(bright, deck.ink(0.22 * fade))
	var span := far - start
	var energy := 0.5 + 0.5 * clampf(deck.content_energy + deck.reasoning_energy * 0.5 + deck.tool_energy * 0.5, 0.0, 1.0)
	for beam: Vector4 in deck.beams:
		var angle := beam.x + deck.outer_angle
		if cos(angle) < -0.2:
			continue
		var head := start + fposmod(beam.w + deck.beam_travel * beam.z, 1.0) * span
		var tail := maxf(start, head - span * (0.12 + 0.3 * InvestigationDeck.hash01(beam.x, beam.y, 2.0)))
		var brightness := (0.25 + 0.6 * InvestigationDeck.hash01(beam.x, 1.0, 5.0)) * energy * fade
		draw_shaft(center, angle, beam.y, tail, head, deck.palette_ink, brightness)
	for pulse: Vector4 in deck.pulses:
		var t := pulse.y / InvestigationDeck.PULSE_SECONDS
		var head := start + span * (1.0 - pow(1.0 - t, 2.2))
		var tail := maxf(start, head - span * (0.18 + 0.2 * pulse.w))
		var color := deck.palette_ink
		if pulse.w > 1.5:
			color = deck.palette_error
		elif pulse.w > 0.5:
			color = deck.palette_hot
		draw_shaft(center, pulse.x + deck.outer_angle, pulse.z, tail, head, color, (1.0 - t) * fade)
	pass


## A radial wedge from [param tail] to [param head]: transparent at the tail, brightest at the head.
func draw_shaft(center: Vector2, angle: float, half_width: float, tail: float, head: float, color: Color, alpha: float) -> void:
	if head - tail < 1.0 or alpha <= 0.01:
		return
	var left := Vector2.from_angle(angle - half_width)
	var right := Vector2.from_angle(angle + half_width)
	var dim := deck.tint(color, 0.0)
	var lit := deck.tint(color, alpha)
	draw_primitive(PackedVector2Array([center + left * tail, center + right * tail, center + right * head, center + left * head]),
		PackedColorArray([dim, dim, lit, lit]), PackedVector2Array())
	pass


## Middle layer: screen tiles wrapped around the annulus, then ribbed rails on both edges.
func draw_ring() -> void:
	var center := hub()
	var r1 := inner_radius()
	var r2 := outer_radius()
	var bounds := Rect2(Vector2.ZERO, size).grow(r2 - r1)
	var tiles := InvestigationDeck.ring_tiles()
	var segments := tiles * SEGMENTS_PER_TILE
	var step := TAU / float(segments)
	var texture: Texture2D = deck.screen_viewport.get_texture() if deck.screen_viewport != null else null
	var white := Color(1.0, 1.0, 1.0, deck.draw_alpha)
	var colors := PackedColorArray([white, white, white, white])
	for segment in range(segments):
		var a0 := deck.outer_angle + float(segment) * step
		var a1 := a0 + step
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		if not bounds.has_point(center + Vector2.from_angle(a0 + step * 0.5) * (r1 + r2) * 0.5):
			continue
		var v0 := float(segment % SEGMENTS_PER_TILE) / float(SEGMENTS_PER_TILE)
		var v1 := v0 + 1.0 / float(SEGMENTS_PER_TILE)
		var quad := PackedVector2Array([center + d0 * r1, center + d0 * r2, center + d1 * r2, center + d1 * r1])
		if texture == null:
			draw_colored_polygon(quad, Color(deck.palette_screen, 0.96))
		else:
			draw_primitive(quad, colors, PackedVector2Array([Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)]), texture)
		if segment % SEGMENTS_PER_TILE == 0:
			draw_line(center + d0 * r1, center + d0 * r2, deck.ink(0.55), 1.0)
	draw_ring_flashes(center, r1, r2, step)
	draw_rails(center, r1, r2)
	pass


## Ring slots lit by landing comets: a bright inner edge fading outward across the slot.
func draw_ring_flashes(center: Vector2, r1: float, r2: float, step: float) -> void:
	for flash: Vector2 in deck.ring_flashes:
		var slot := (floorf(flash.x / step) + 0.5) * step + deck.outer_angle
		var d0 := Vector2.from_angle(slot - step * 0.5)
		var d1 := Vector2.from_angle(slot + step * 0.5)
		var lit := deck.ink(0.45 * flash.y)
		var dim := deck.ink(0.0)
		draw_primitive(PackedVector2Array([center + d0 * r1, center + d0 * r2, center + d1 * r2, center + d1 * r1]),
			PackedColorArray([lit, dim, dim, lit]), PackedVector2Array())
		draw_line(center + d0 * r1, center + d1 * r1, deck.ink(minf(flash.y * 1.2, 1.0)), 2.0)
	pass


func draw_rails(center: Vector2, r1: float, r2: float) -> void:
	var rail := rail_width()
	var edge := deck.tint(deck.palette_error, deck.error_flash) if deck.error_flash > 0.05 else deck.ink(0.55 + 0.4 * deck.turn_pulse)
	draw_arc(center, r1, 0.0, TAU, CIRCLE_POINTS, edge, 1.0, true)
	draw_arc(center, r2, 0.0, TAU, CIRCLE_POINTS, edge, 1.0, true)
	draw_arc(center, r1 - rail, 0.0, TAU, CIRCLE_POINTS, deck.ink(0.2), 1.0, true)
	draw_arc(center, r2 + rail * 1.4, 0.0, TAU, CIRCLE_POINTS, deck.ink(0.25), 1.0, true)
	var ribs := PackedVector2Array()
	for index in range(RIB_COUNT):
		var direction := Vector2.from_angle(deck.outer_angle + TAU * float(index) / float(RIB_COUNT))
		if direction.x < -0.3:
			continue
		var major := index % 5 == 0
		ribs.append(center + direction * r1)
		ribs.append(center + direction * (r1 - rail * (1.0 if major else 0.55)))
		ribs.append(center + direction * r2)
		ribs.append(center + direction * (r2 + rail * (1.3 if major else 0.7)))
	if not ribs.is_empty():
		draw_multiline(ribs, deck.ink(0.4))
	pass


func draw_labels() -> void:
	var ts := deck.text_size()
	var summary := StringUtils.format(I18n.t("agent.visuals.deck_summary"), deck.finished_tools(), deck.tool_total, deck.running_tools())
	InvestigationDeck.mono_right(self, Vector2(size.x - ts, size.y - ts * 0.6), summary, ts, deck.ink(0.75))
	# Live indicator with a level slider tracking stream energy.
	var level := clampf(maxf(deck.reasoning_energy, deck.content_energy) + deck.tool_energy * 0.3, 0.0, 1.0)
	var slider_end := Vector2(size.x - ts * 4.5, ts * 1.2)
	var slider_start := slider_end - Vector2(ts * 6.0, 0.0)
	draw_line(slider_start, slider_end, deck.ink(0.3), 1.0)
	draw_line(slider_start, slider_start.lerp(slider_end, level), deck.ink(0.8), 2.0)
	draw_circle(slider_start.lerp(slider_end, level), ts * 0.3, deck.ink(0.95))
	draw_circle(slider_start - Vector2(ts * 1.2, 0.0), ts * 0.28, deck.tint(deck.palette_hot, 0.5 + 0.5 * (0.5 + 0.5 * sin(deck.clock * 5.0))))
	InvestigationDeck.mono(self, slider_end + Vector2(ts * 0.8, ts * 0.35), I18n.t("agent.visuals.live"), ts - 1, deck.ink(0.7))
	var zoom_text := "x%.2f" % deck.zoom
	InvestigationDeck.mono(self, Vector2(ts, size.y - ts * 0.6), zoom_text, ts - 1, deck.ink(0.5))
	pass


## The deck's power-off scan continues across the stage, which draws above the deck itself.
func draw_end_scan() -> void:
	if not deck.ending:
		return
	var y := deck.view_size().y * deck.end_progress - position.y
	if y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, minf(y, size.y))), Color(deck.palette_back, 0.55 * deck.end_progress))
	if y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), VisualColor.stroke(deck.palette_ink, 0.8 * (1.0 - deck.end_progress)), 2.0)
	pass
