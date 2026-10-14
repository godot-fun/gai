class_name SessionRowRunFx
extends Control

## Small flowing sine wave shown in place of the close button while a session runs or compacts.
## Drawn in code so it always reflects the live theme color.
## It shares the close button's slot size, so the swap costs no extra row width.

## Horizontal distance between samples, and the padding that keeps the stroked
## line inside the control rect.
const SAMPLE_STEP := 1.0
const PAD := 1.6
## Wave shape: radians per pixel and the base amplitude in pixels.
const WAVE_SCALE := 0.72
const AMPLITUDE := 5.5
## Scroll speed in radians per second (about one wavelength per second).
const FLOW_SPEED := 6.0
## Amplitude breathing, so the stream does not look like a static graph.
const BREATH_SPEED := 2.1
const BREATH_DEPTH := 0.08
## Beading along the wave reads as packets travelling downstream.
const PACKET_STEP := 3
const PACKET_RADIUS := 0.6

var phase := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visible = false
	pass


## The engine auto-enables `_process` for any script that defines it (after `_init`),
## so the real state has to be re-applied once the node is in the tree.
func _ready() -> void:
	set_process(visible)
	pass


## `visible` doubles as the state — repeated calls (refresh, title change, select) must
## not restart the wave, only an actual start does.
func set_running(value: bool) -> void:
	if visible == value:
		return
	visible = value
	set_process(value)
	if value:
		phase = 0.0
	queue_redraw()
	pass


func _process(delta: float) -> void:
	phase = fposmod(phase + delta * FLOW_SPEED, TAU * 512.0)
	queue_redraw()
	pass


func _draw() -> void:
	if size.x - PAD * 2.0 <= 2.0 or size.y <= PAD * 2.0:
		return
	var theme_color := ThemeColor.accent_theme_color()
	var points := wave_points()
	# Glow pass keeps the thin stroke readable on either theme.
	draw_polyline(points, Color(theme_color, 0.30 if ThemeColor.is_dark_theme() else 0.22), 1.6, true)
	draw_polyline(points, theme_color, 0.8, true)
	# Bright beads on the samples, giving the wave a sense of flow.
	for index in range(0, points.size(), PACKET_STEP):
		draw_circle(points[index], PACKET_RADIUS, Color(theme_color.lightened(0.35), 0.55))
	pass


## Traveling sine sampled across the whole control width.
func wave_points() -> PackedVector2Array:
	var amplitude := AMPLITUDE * (1.0 + BREATH_DEPTH * sin(phase * BREATH_SPEED))
	var center_y := size.y * 0.5
	var points := PackedVector2Array()
	var x := PAD
	while x <= size.x - PAD:
		points.append(Vector2(x, center_y + sin(x * WAVE_SCALE - phase) * amplitude))
		x += SAMPLE_STEP
	return points
