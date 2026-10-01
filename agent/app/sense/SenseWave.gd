class_name SenseWave
extends Window

## Recording / transcribing volume sine wave. Uses the same native-window tricks as
## [DesktopToast] so it stays visible while the agent is in the background.
## On show, pinned once via [method SenseCaretLocator.resolve_anchor]. Does not follow.
## Wave drawing and volume history live in the section at the bottom of this file.

enum Phase { RECORDING, TRANSCRIBING }

## Slight offset so the wave sits just below-right of the pointer.
const CURSOR_OFFSET := Vector2i(14, 18)
const FADE_IN_SECONDS := 0.12
const FADE_OUT_SECONDS := 0.18

static var instance: SenseWave = null

var phase: Phase = Phase.RECORDING
var fade: float = 0.0
var closing: bool = false
## Screen point captured when recording starts; the window stays here until dismiss.
var fixed_anchor: Vector2i = Vector2i.ZERO
## Pixel scale vs 2K ([constant DisplayScale.REF_SCREEN_WIDTH]) for the pinned screen.
var screen_scale: float = 1.0
var canvas: FxCanvas


func _init() -> void:
	visible = false
	force_native = true
	borderless = true
	transparent = true
	unresizable = true
	always_on_top = true
	unfocusable = true
	# Clicks pass through so the foreground app keeps receiving input under the wave.
	mouse_passthrough = true
	sharp_corners = true
	pass


## Create the wave once, pinned to caret or screen center. No-op if one is already showing.
static func show_recording() -> void:
	if instance != null and is_instance_valid(instance):
		return
	if gdf.gdf_node == null or not gdf.gdf_node.is_inside_tree():
		return
	instance = SenseWave.new()
	gdf.gdf_node.add_child(instance)
	pass


## Switch the live wave to a slower transcribing scroll; position stays fixed.
static func show_transcribing() -> void:
	if instance != null and is_instance_valid(instance):
		instance.closing = false
		instance.phase = Phase.TRANSCRIBING
		instance.volume = TRANSCRIBE_VOLUME
	pass


## Fade out and free the wave if one is showing.
static func dismiss() -> void:
	if instance != null and is_instance_valid(instance):
		instance.closing = true
	pass


## Screen-space top-left for a window of [param window_size] anchored near [param anchor].
static func window_position_for_cursor(anchor: Vector2i, window_size: Vector2i) -> Vector2i:
	return anchor + CURSOR_OFFSET - Vector2i(window_size.x / 2, window_size.y / 2)


func _ready() -> void:
	phase = Phase.RECORDING
	closing = false
	fixed_anchor = SenseCaretLocator.resolve_anchor()
	screen_scale = DisplayScale.compute_screen_scale(fixed_anchor)
	volume = 0.0
	reset_volume_history()
	var w := maxi(1, roundi(float(WAVE_WIDTH) * screen_scale))
	var h := maxi(1, roundi(float(WAVE_HEIGHT) * screen_scale))
	size = Vector2i(w, h)
	position = window_position_for_cursor(fixed_anchor, size)
	get_viewport().transparent_bg = true
	canvas = FxCanvas.new()
	canvas.owner_fx = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	visible = true
	pass


func _process(delta: float) -> void:
	if closing:
		fade = maxf(0.0, fade - delta / FADE_OUT_SECONDS)
		if fade <= 0.0:
			if instance == self:
				instance = null
			queue_free()
			return
	else:
		fade = minf(1.0, fade + delta / FADE_IN_SECONDS)
	if phase == Phase.RECORDING and not closing:
		volume = AudioRecorder.poll_volume()
	elif phase == Phase.TRANSCRIBING:
		volume = TRANSCRIBE_VOLUME
	var rate := HISTORY_RATE_RECORDING if phase == Phase.RECORDING else HISTORY_RATE_TRANSCRIBING
	push_volume_history(volume, delta, rate)
	if canvas != null:
		canvas.queue_redraw()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Volume sine wave (history scroll + paint)
# ----------------------------------------------------------------------------------------------------------------------

## Rendering pipeline and smoothing notes:
## 1. The microphone meter is sampled into [member volume_history] at a fixed logical rate.
## 2. When a slow frame advances several columns, [method push_volume_history] interpolates
##    the missing values. Filling every skipped column with the newest value would create an
##    abrupt amplitude wall, which appears as a spike when the sine points are connected.
## 3. [method smoothed_history_level] applies a centered bell filter only while painting.
##    Keeping the raw history intact avoids accumulating blur as samples scroll left.
## 4. The filter is intentionally wider than one line segment but much narrower than a full
##    sine period, so it removes isolated jagged edges without flattening speech dynamics.
## If the wave still looks sharp, widen [constant HISTORY_SMOOTH_WEIGHTS] gradually. Increasing
## it too far makes the meter feel delayed even though this filter itself has no temporal state.

## Pixel size at 2K ([constant DisplayScale.REF_SCREEN_WIDTH]); scaled by [member screen_scale] on other screens.
## [constant WAVE_WIDTH] is also the sense picker card width so both overlays share one band.
const WAVE_WIDTH := 512
const WAVE_HEIGHT := 64
## Full sine periods across [constant WAVE_WIDTH].
const WAVE_CYCLES := 16
## History columns pushed per second (right = newest → left = oldest).
const HISTORY_RATE_RECORDING := 96.0
const HISTORY_RATE_TRANSCRIBING := 48.0
## Fixed meter during transcription (mic is off).
const TRANSCRIBE_VOLUME := 0.22
## Nine-point bell filter used while painting. The center remains dominant while the
## wider shoulders remove the last small high-frequency changes between history columns.
const HISTORY_SMOOTH_WEIGHTS := [1.0, 4.0, 10.0, 16.0, 19.0, 16.0, 10.0, 4.0, 1.0]
const HISTORY_SMOOTH_RADIUS := 4

## Latest 0..1 meter (from [method AudioRecorder.poll_volume] while recording).
var volume: float = 0.0
## Per-column amplitude history: index 0 = oldest (left), last = newest (right).
var volume_history: PackedFloat32Array = PackedFloat32Array()
## Fractional accumulator for [method push_volume_history].
var history_accum: float = 0.0


func reset_volume_history() -> void:
	volume_history.resize(WAVE_WIDTH)
	# Start flat; amplitude appears only as live volume is pushed from the right.
	volume_history.fill(0.0)
	history_accum = 0.0
	pass


## Inserts the newest volume on the right and shifts older samples toward the left.
## [member history_accum] converts frame time into an integer number of history columns,
## while retaining the fractional remainder for the next frame. If more than one column
## is due, the new gap is filled by linear interpolation from the previous newest sample
## to [param level], rather than repeating [param level] across the whole gap.
func push_volume_history(level: float, delta: float, rate: float) -> void:
	if volume_history.size() != WAVE_WIDTH:
		reset_volume_history()
	var sample := clampf(level, 0.0, 1.0)
	history_accum += rate * delta
	var steps := int(history_accum)
	if steps <= 0:
		return
	history_accum -= float(steps)
	steps = mini(steps, WAVE_WIDTH)
	# Capture the interpolation start before shifting; after the shift this slot belongs
	# to the new gap and can no longer represent the last value from the previous frame.
	var previous_sample := volume_history[WAVE_WIDTH - 1]
	# Shift left in one pass. Interpolate skipped columns so a slow frame cannot create
	# a block of identical samples followed by one abrupt amplitude edge.
	for j in range(WAVE_WIDTH - steps):
		volume_history[j] = volume_history[j + steps]
	for j in range(WAVE_WIDTH - steps, WAVE_WIDTH):
		# The first inserted column uses 1 / steps and the last uses 1.0. This places
		# evenly spaced values strictly after previous_sample and guarantees that the
		# rightmost (newest) column exactly matches the current microphone sample.
		var blend := float(j - (WAVE_WIDTH - steps) + 1) / float(steps)
		volume_history[j] = lerpf(previous_sample, sample, blend)
	pass


## Returns a locally smoothed history sample for rendering. Edge weights are
## renormalized so the start and end of the wave do not get artificially quieter.
func smoothed_history_level(index: int) -> float:
	var weighted_sum := 0.0
	var weight_sum := 0.0
	for offset in range(-HISTORY_SMOOTH_RADIUS, HISTORY_SMOOTH_RADIUS + 1):
		var sample_index := index + offset
		if sample_index < 0 or sample_index >= volume_history.size():
			continue
		var weight: float = HISTORY_SMOOTH_WEIGHTS[offset + HISTORY_SMOOTH_RADIUS]
		weighted_sum += volume_history[sample_index] * weight
		weight_sum += weight
	return weighted_sum / weight_sum if weight_sum > 0.0 else 0.0


## Volume-history sine: [constant WAVE_CYCLES] periods; each x uses its own past amplitude
## (left = older, right = newest), so loud spikes appear on the right and drift left.
func paint_canvas(node: Control) -> void:
	if volume_history.size() != WAVE_WIDTH:
		reset_volume_history()
	var s := screen_scale
	var w := float(WAVE_WIDTH) * s
	var h := float(WAVE_HEIGHT) * s
	var mid_y := h * 0.5
	var max_amp := h * 0.5 - 2.0 * s
	var accent := ThemeColor.accent_theme_color() if phase == Phase.RECORDING else ColorBase.info
	var a := fade
	var k := TAU * float(WAVE_CYCLES) / w
	var points := PackedVector2Array()
	points.resize(WAVE_WIDTH)
	for i in range(WAVE_WIDTH):
		var x := float(i) * s
		var amp := max_amp * smoothed_history_level(i)
		var y := mid_y + amp * sin(k * x)
		points[i] = Vector2(x, y)
	# Soft under-glow, then a crisp stroke. Minimum widths keep both passes antialiased
	# on displays whose screen scale would otherwise make the lines thinner than one pixel.
	node.draw_polyline(points, Color(accent, 0.22 * a), maxf(2.0, 4.0 * s), true)
	node.draw_polyline(points, Color(accent, 0.85 * a), maxf(1.0, 1.75 * s), true)
	pass


class FxCanvas extends Control:
	var owner_fx: SenseWave

	func _draw() -> void:
		if owner_fx != null:
			owner_fx.paint_canvas(self)
		pass
