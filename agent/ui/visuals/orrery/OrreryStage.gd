class_name OrreryStage
extends Control

## Stage of [Orrery]: three concentric layers around a hub left of the stage, clipped to
## this control so the beams end at the stage edge.
## - Disc: child controls drawn behind this one (`show_behind_parent`). Four static web layers are
##   painted once in unit-disc space and only re-posed each frame (position, spin, scale, pulse
##   alpha), so 2000 curves cost a transform, not a redraw. A runner layer shares the spin; a comet
##   layer stays unspun because comets follow the ring, and also carries the ring shadow.
## - Ring: [OrreryScreen] tiles mapped around the annulus with `draw_primitive`; radial
##   texture x reads outward, so text sits upright on the visible right-hand side.
## - Beams: fine hairlines, travelling shafts, and emitted pulses beyond the outer rail.
## Ring and beams both turn on `orrery.outer_angle`; every radius scales with `orrery.zoom`.

## Cached mesh geometry: keep UI bars and table rules visually straight around the annulus.
const SEGMENTS_PER_TILE := 32
const WEB_SEGMENTS := 8
const RUNNER_TAIL := 4
const COMET_STEPS := 12
const COMET_HEAD_STEPS := 5
## Ring shadow starts this far inside the rim (unit-disc radius), darkening the web toward the ring.
const SHADOW_INNER := 0.8
const SHADOW_SEGMENTS := 96
## Thousands of overlapping hairlines add up; this keeps the woven field a backdrop to the runners.
const WEB_ALPHA_SCALE := 0.5
const PROCEDURAL_SHADER: Shader = preload("res://agent/ui/visuals/orrery/OrreryProcedural.gdshader")

var orrery: Orrery
## Base web layer then three pulse layers; all share the disc pose.
var web_layers: Array[Control] = []
var runner_layer: Control
var comet_layer: Control
var ring_mesh: MeshInstance2D
var procedural_layer: ColorRect
var procedural_material: ShaderMaterial
## Disc radius (px) when the web layers were last painted; their labels are sized against it.
var web_radius: float = 0.0
var ring_mesh_tiles: int = 0


func _ready() -> void:
	clip_contents = true
	create_ring_mesh()
	create_procedural_layer()
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


## The screen texture is wrapped by one cached mesh instead of issuing a draw call per ring segment.
func create_ring_mesh() -> void:
	ring_mesh = MeshInstance2D.new()
	ring_mesh.name = "RingMesh"
	ring_mesh.z_index = -2
	add_child(ring_mesh)
	pass


## Rails, dense beam field, and shutdown scan are analytic and update through uniforms only.
func create_procedural_layer() -> void:
	procedural_layer = ColorRect.new()
	procedural_layer.name = "ProceduralLayer"
	procedural_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	procedural_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	procedural_layer.z_index = -1
	procedural_material = ShaderMaterial.new()
	procedural_material.shader = PROCEDURAL_SHADER
	procedural_layer.material = procedural_material
	add_child(procedural_layer)
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
	if orrery == null or web_layers.is_empty():
		return
	sync_ring_mesh()
	sync_procedural_layer()
	var radius := disc_radius()
	var base_radius := size.y * Orrery.DISC_RADIUS_RATIO
	if absf(base_radius - web_radius) > 1.0:
		web_radius = base_radius
		for layer: Control in web_layers:
			layer.queue_redraw()
	for index in range(web_layers.size()):
		var layer := web_layers[index]
		layer.position = hub()
		layer.rotation = orrery.inner_angle
		layer.scale = Vector2(radius, radius)
		var pulse := 1.0 if index == 0 else 0.1 + 0.8 * orrery.layer_env[index - 1]
		layer.modulate = Color(1.0, 1.0, 1.0, pulse * orrery.draw_alpha)
	runner_layer.position = hub()
	runner_layer.rotation = orrery.inner_angle
	runner_layer.scale = Vector2(radius, radius)
	runner_layer.queue_redraw()
	comet_layer.position = hub()
	comet_layer.scale = Vector2(radius, radius)
	comet_layer.queue_redraw()
	pass


func sync_ring_mesh() -> void:
	if ring_mesh == null:
		return
	var tiles := Orrery.ring_tiles()
	if ring_mesh_tiles != tiles:
		build_ring_mesh(tiles)
	var texture: Texture2D = orrery.screen_viewport.get_texture() if orrery.screen_viewport != null else null
	ring_mesh.texture = texture
	ring_mesh.position = hub()
	ring_mesh.rotation = orrery.outer_angle
	ring_mesh.scale = Vector2.ONE * size.y * orrery.zoom
	ring_mesh.modulate = Color(1.0, 1.0, 1.0, orrery.draw_alpha)
	pass


func build_ring_mesh(tiles: int) -> void:
	var segments := tiles * SEGMENTS_PER_TILE
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(segments * 4)
	uvs.resize(segments * 4)
	indices.resize(segments * 6)
	var inner := Orrery.DISC_RADIUS_RATIO
	var outer := Orrery.DISC_RADIUS_RATIO + Orrery.RING_THICKNESS_RATIO
	for segment in range(segments):
		var a0 := TAU * float(segment) / float(segments)
		var a1 := TAU * float(segment + 1) / float(segments)
		var vertex := segment * 4
		vertices[vertex] = Vector2.from_angle(a0) * inner
		vertices[vertex + 1] = Vector2.from_angle(a0) * outer
		vertices[vertex + 2] = Vector2.from_angle(a1) * outer
		vertices[vertex + 3] = Vector2.from_angle(a1) * inner
		var v0 := float(segment % SEGMENTS_PER_TILE) / float(SEGMENTS_PER_TILE)
		var v1 := v0 + 1.0 / float(SEGMENTS_PER_TILE)
		uvs[vertex] = Vector2(0.0, v0)
		uvs[vertex + 1] = Vector2(1.0, v0)
		uvs[vertex + 2] = Vector2(1.0, v1)
		uvs[vertex + 3] = Vector2(0.0, v1)
		var index := segment * 6
		indices[index] = vertex
		indices[index + 1] = vertex + 1
		indices[index + 2] = vertex + 2
		indices[index + 3] = vertex
		indices[index + 4] = vertex + 2
		indices[index + 5] = vertex + 3
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ring_mesh.mesh = mesh
	ring_mesh_tiles = tiles
	pass


func sync_procedural_layer() -> void:
	if procedural_material == null:
		return
	procedural_material.set_shader_parameter("stage_size", size)
	procedural_material.set_shader_parameter("hub", hub())
	procedural_material.set_shader_parameter("inner_radius", inner_radius())
	procedural_material.set_shader_parameter("outer_radius", outer_radius())
	procedural_material.set_shader_parameter("rail_width", rail_width())
	procedural_material.set_shader_parameter("outer_angle", orrery.outer_angle)
	procedural_material.set_shader_parameter("draw_alpha", orrery.draw_alpha)
	procedural_material.set_shader_parameter("error_flash", orrery.error_flash)
	procedural_material.set_shader_parameter("turn_pulse", orrery.turn_pulse)
	procedural_material.set_shader_parameter("end_progress", orrery.end_progress if orrery.ending else 0.0)
	procedural_material.set_shader_parameter("ink_color", orrery.palette_ink)
	procedural_material.set_shader_parameter("error_color", orrery.palette_error)
	procedural_material.set_shader_parameter("back_color", orrery.palette_back)
	pass


func disc_radius() -> float:
	return inner_radius() - 1.5


func hub() -> Vector2:
	return Vector2(size.y * Orrery.HUB_X_RATIO, size.y * 0.5)


func inner_radius() -> float:
	return size.y * Orrery.DISC_RADIUS_RATIO * orrery.zoom


func outer_radius() -> float:
	return inner_radius() + size.y * Orrery.RING_THICKNESS_RATIO * orrery.zoom


func rail_width() -> float:
	return size.y * 0.03 * orrery.zoom


func _draw() -> void:
	if orrery == null or size.x < 16.0 or size.y < 16.0:
		return
	draw_beams()
	draw_ring()
	draw_labels()
	pass


func web_color(hue: int, alpha: float) -> Color:
	match hue:
		1:
			return VisualColor.stroke(orrery.palette_hot, alpha)
		2:
			return VisualColor.stroke(orrery.palette_violet, alpha)
	return VisualColor.stroke(orrery.palette_ink, alpha)


## One web layer in unit-disc space ([param layer] -1 is the base). Pulse layers are painted at full
## authored alpha and faded by the layer's modulate, so a pulse never repaints geometry.
func draw_web_layer(canvas: Control, layer: int) -> void:
	if orrery == null or web_radius <= 1.0:
		return
	if layer < 0:
		canvas.draw_circle(Vector2.ZERO, 1.0, Color(orrery.palette_screen, 0.55))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for curve in range(orrery.web_layers.size()):
		if orrery.web_layers[curve] != layer:
			continue
		var color := web_color(orrery.web_hues[curve], orrery.web_alphas[curve] * WEB_ALPHA_SCALE)
		var previous := orrery.web_point(curve, 0.0)
		for step in range(1, WEB_SEGMENTS + 1):
			var next := orrery.web_point(curve, float(step) / float(WEB_SEGMENTS))
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
	var font := Orrery.mono_font()
	var label_color := VisualColor.stroke(orrery.palette_ink, 0.5)
	for index in range(orrery.web_nodes.size()):
		var node := orrery.web_nodes[index]
		var at := Vector2(node.x, node.y)
		var color := VisualColor.stroke(orrery.palette_ink, 0.35 + 0.45 * Orrery.hash01(index, 2.0, 9.0))
		canvas.draw_arc(at, node.z * px, 0.0, TAU, 14, color, -1.0)
		if Orrery.hash01(index, 4.0, 1.0) < 0.4:
			canvas.draw_arc(at + Vector2(node.z * 2.2 * px, 0.0), node.z * 0.8 * px, 0.0, TAU, 12, color, -1.0)
		var label := orrery.web_labels[index]
		if not label.is_empty():
			canvas.draw_set_transform(at + Vector2(7.0 * px, 2.0 * px), 0.0, Vector2(px, px))
			canvas.draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, label_color)
			canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var chain_color := VisualColor.stroke(orrery.palette_ink, 0.55)
	for chain: Vector3 in orrery.web_chains:
		for index in range(int(chain.z)):
			var angle := chain.y + float(index) * 0.022
			canvas.draw_arc(Vector2.from_angle(angle) * chain.x, 2.2 * px, 0.0, TAU, 8, chain_color, -1.0)
	pass


## Runners: short fading tails along their web curve, sharing the disc spin.
func draw_runners() -> void:
	if orrery == null:
		return
	var radius := maxf(disc_radius(), 1.0)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var accent_points := PackedVector2Array()
	var accent_colors := PackedColorArray()
	for runner: Orrery.Runner in orrery.runners:
		var tail := clampf(runner.speed * 0.35, 0.02, 0.18)
		var previous := orrery.web_point(runner.curve, maxf(runner.t - tail, 0.0))
		for step in range(1, RUNNER_TAIL + 1):
			var k := float(step) / float(RUNNER_TAIL)
			var next := orrery.web_point(runner.curve, maxf(runner.t - tail * (1.0 - k), 0.0))
			if runner.accent:
				accent_points.append_array(PackedVector2Array([previous, next]))
				accent_colors.append(orrery.tint(orrery.palette_hot, 0.9 * k))
			else:
				points.append_array(PackedVector2Array([previous, next]))
				colors.append(orrery.ink(0.5 * k))
			previous = next
	if not points.is_empty():
		runner_layer.draw_multiline_colors(points, colors, 0.9 / radius)
	if not accent_points.is_empty():
		runner_layer.draw_multiline_colors(accent_points, accent_colors, 1.3 / radius)
	pass


## Ring shadow, then comets. Unspun: comets follow the ring by rotating with `outer_angle - rot0`.
func draw_comets() -> void:
	if orrery == null:
		return
	draw_ring_shadow()
	var radius := maxf(disc_radius(), 1.0)
	for comet: Orrery.Comet in orrery.comets:
		var span := comet.progress()
		if span.y <= span.x or span.z <= 0.0:
			continue
		var turn := orrery.outer_angle - comet.rot0
		var color := orrery.palette_violet if comet.tint else orrery.palette_ink
		var neck := span.y - (span.y - span.x) * 0.35
		comet_layer.draw_multiline(comet_strokes(comet, span.x, span.y, COMET_STEPS, turn), orrery.tint(color, 0.5 * span.z), 1.0 / radius)
		comet_layer.draw_multiline(comet_strokes(comet, neck, span.y, COMET_HEAD_STEPS, turn), orrery.tint(color, span.z), 1.7 / radius)
	pass


func comet_strokes(comet: Orrery.Comet, from: float, to: float, steps: int, turn: float) -> PackedVector2Array:
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
	var clear := Color(orrery.palette_back, 0.0)
	var dark := Color(orrery.palette_back, 0.8 * orrery.draw_alpha)
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
	var fade := 1.0 - orrery.end_progress
	var span := far - start
	var energy := 0.5 + 0.5 * clampf(orrery.content_energy + orrery.reasoning_energy * 0.5 + orrery.tool_energy * 0.5, 0.0, 1.0)
	for beam: Vector4 in orrery.beams:
		var angle := beam.x + orrery.outer_angle
		if cos(angle) < -0.2:
			continue
		var head := start + fposmod(beam.w + orrery.beam_travel * beam.z, 1.0) * span
		var tail := maxf(start, head - span * (0.12 + 0.3 * Orrery.hash01(beam.x, beam.y, 2.0)))
		var brightness := (0.25 + 0.6 * Orrery.hash01(beam.x, 1.0, 5.0)) * energy * fade
		draw_shaft(center, angle, beam.y, tail, head, orrery.palette_ink, brightness)
	for pulse: Vector4 in orrery.pulses:
		var t := pulse.y / Orrery.PULSE_SECONDS
		var head := start + span * (1.0 - pow(1.0 - t, 2.2))
		var tail := maxf(start, head - span * (0.18 + 0.2 * pulse.w))
		var color := orrery.palette_ink
		if pulse.w > 1.5:
			color = orrery.palette_error
		elif pulse.w > 0.5:
			color = orrery.palette_hot
		draw_shaft(center, pulse.x + orrery.outer_angle, pulse.z, tail, head, color, (1.0 - t) * fade)
	pass


## A radial wedge from [param tail] to [param head]: transparent at the tail, brightest at the head.
func draw_shaft(center: Vector2, angle: float, half_width: float, tail: float, head: float, color: Color, alpha: float) -> void:
	if head - tail < 1.0 or alpha <= 0.01:
		return
	var left := Vector2.from_angle(angle - half_width)
	var right := Vector2.from_angle(angle + half_width)
	var dim := orrery.tint(color, 0.0)
	var lit := orrery.tint(color, alpha)
	draw_primitive(PackedVector2Array([center + left * tail, center + right * tail, center + right * head, center + left * head]),
		PackedColorArray([dim, dim, lit, lit]), PackedVector2Array())
	pass


## Dynamic ring overlays stay on the canvas. The tiled screen and static rails live in child GPU layers.
func draw_ring() -> void:
	var center := hub()
	var r1 := inner_radius()
	var r2 := outer_radius()
	var tiles := Orrery.ring_tiles()
	var segments := tiles * SEGMENTS_PER_TILE
	var step := TAU / float(segments)
	draw_ring_flashes(center, r1, r2, step)
	pass


## Ring slots lit by landing comets: a bright inner edge fading outward across the slot.
func draw_ring_flashes(center: Vector2, r1: float, r2: float, step: float) -> void:
	for flash: Vector2 in orrery.ring_flashes:
		var slot := (floorf(flash.x / step) + 0.5) * step + orrery.outer_angle
		var d0 := Vector2.from_angle(slot - step * 0.5)
		var d1 := Vector2.from_angle(slot + step * 0.5)
		var lit := orrery.ink(0.45 * flash.y)
		var dim := orrery.ink(0.0)
		draw_primitive(PackedVector2Array([center + d0 * r1, center + d0 * r2, center + d1 * r2, center + d1 * r1]),
			PackedColorArray([lit, dim, dim, lit]), PackedVector2Array())
		draw_line(center + d0 * r1, center + d1 * r1, orrery.ink(minf(flash.y * 1.2, 1.0)), 2.0)
	pass


func draw_labels() -> void:
	var ts := orrery.text_size()
	var summary := StringUtils.format(I18n.t("agent.visuals.orrery_summary"), orrery.finished_tools(), orrery.tool_total, orrery.running_tools())
	Orrery.mono_right(self, Vector2(size.x - ts, size.y - ts * 0.6), summary, ts, orrery.ink(0.75))
	# Live indicator with a level slider tracking stream energy.
	var level := clampf(maxf(orrery.reasoning_energy, orrery.content_energy) + orrery.tool_energy * 0.3, 0.0, 1.0)
	var slider_end := Vector2(size.x - ts * 4.5, ts * 1.2)
	var slider_start := slider_end - Vector2(ts * 6.0, 0.0)
	draw_line(slider_start, slider_end, orrery.ink(0.3), 1.0)
	draw_line(slider_start, slider_start.lerp(slider_end, level), orrery.ink(0.8), 2.0)
	draw_circle(slider_start.lerp(slider_end, level), ts * 0.3, orrery.ink(0.95))
	draw_circle(slider_start - Vector2(ts * 1.2, 0.0), ts * 0.28, orrery.tint(orrery.palette_hot, 0.5 + 0.5 * (0.5 + 0.5 * sin(orrery.clock * 5.0))))
	Orrery.mono(self, slider_end + Vector2(ts * 0.8, ts * 0.35), I18n.t("agent.visuals.live"), ts - 1, orrery.ink(0.7))
	var zoom_text := "x%.2f" % orrery.zoom
	Orrery.mono(self, Vector2(ts, size.y - ts * 0.6), zoom_text, ts - 1, orrery.ink(0.5))
	pass
