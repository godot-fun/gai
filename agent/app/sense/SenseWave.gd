class_name SenseWave
extends Window

## A compact voice singularity shown at the active screen center. Microphone input drives a
## living aurora membrane rather than a literal waveform. The native window stays click-through
## and unfocusable so recording never interrupts the foreground input control.

enum Phase { RECORDING, TRANSCRIBING }

const FADE_IN_SECONDS := 0.16
const FADE_OUT_SECONDS := 0.20
const EFFECT_SIZE := 280
const WAVE_WIDTH := EFFECT_SIZE
const WAVE_HEIGHT := EFFECT_SIZE
const TRANSCRIBE_VOLUME := 0.18
const ENERGY_ATTACK_SPEED := 14.0
const ENERGY_RELEASE_SPEED := 3.2
const FAST_ENERGY_SPEED := 28.0
const SLOW_ENERGY_SPEED := 2.1
const SYLLABLE_DECAY_SPEED := 4.8
const ACTIVITY_SPEED := 7.0
const RIPPLE_HISTORY_SIZE := 32
const RIPPLE_SAMPLE_RATE := 45.0
## Microphone meters usually occupy only the quiet end of 0..1; expand that useful range visually.
const VISUAL_ENERGY_POWER := 0.42
const ATTACK_DECAY_SPEED := 5.5
const PEAK_DECAY_SPEED := 1.35
## The opening pulse should feel spacious rather than explode across the whole window.
const IMPACT_SECONDS := 0.62
const SINGULARITY_SHADER: Shader = preload("res://agent/app/sense/SenseWave.gdshader")

static var instance: SenseWave = null

var phase: Phase = Phase.RECORDING
var fade: float = 0.0
var closing: bool = false
var elapsed: float = 0.0
var phase_time: float = 0.0
var screen_scale: float = 1.0
var volume: float = 0.0
var energy: float = 0.0
var fast_energy: float = 0.0
var slow_energy: float = 0.0
var syllable: float = 0.0
var activity: float = 0.0
var attack: float = 0.0
var peak: float = 0.0
var ripple_history: PackedFloat32Array = PackedFloat32Array()
var ripple_accumulator: float = 0.0
var canvas: FxCanvas
var singularity_material: ShaderMaterial
var ripple_image: Image
var ripple_texture: ImageTexture


func _init() -> void:
	visible = false
	force_native = true
	borderless = true
	transparent = true
	unresizable = true
	always_on_top = true
	unfocusable = true
	mouse_passthrough = true
	sharp_corners = true
	pass


static func show_recording() -> void:
	if instance != null and is_instance_valid(instance):
		return
	if not gdf.is_ready():
		return
	instance = SenseWave.new()
	gdf.gdf_node.add_child(instance)
	pass


static func show_transcribing() -> void:
	if instance != null and is_instance_valid(instance):
		instance.closing = false
		instance.phase = Phase.TRANSCRIBING
		instance.phase_time = 0.0
		instance.attack = 1.0
		instance.peak = 1.0
	pass


static func dismiss() -> void:
	if instance != null and is_instance_valid(instance):
		instance.closing = true
	pass


static func active_screen_center() -> Vector2i:
	var rect := ScreenUtils.usable_rect()
	return rect.position + rect.size / 2 if rect.size.x > 0 and rect.size.y > 0 else DisplayServer.mouse_get_position()


static func window_position_for_anchor(anchor: Vector2i, window_size: Vector2i) -> Vector2i:
	return anchor - Vector2i(window_size.x / 2, window_size.y / 2)


func _ready() -> void:
	phase = Phase.RECORDING
	closing = false
	var anchor := active_screen_center()
	screen_scale = DisplayScale.compute_screen_scale(anchor)
	var effect_size := maxi(1, roundi(float(EFFECT_SIZE) * screen_scale))
	size = Vector2i(effect_size, effect_size)
	position = window_position_for_anchor(anchor, size)
	get_viewport().transparent_bg = true
	canvas = FxCanvas.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	setup_shader()
	visible = true
	pass


func _process(delta: float) -> void:
	elapsed += delta
	phase_time += delta
	if closing:
		fade = maxf(0.0, fade - delta / FADE_OUT_SECONDS)
		if fade <= 0.0:
			if instance == self:
				instance = null
			queue_free()
			return
	else:
		fade = minf(1.0, fade + delta / FADE_IN_SECONDS)
	volume = AudioRecorder.poll_volume() if phase == Phase.RECORDING and not closing else TRANSCRIBE_VOLUME
	update_energy(volume, delta)
	update_shader()
	pass


## Three envelope speeds separate overall loudness from syllabic motion. The medium envelope drives
## size, fast-vs-slow divergence drives membrane ripples, and upward motion drives local impacts.
func update_energy(level: float, delta: float) -> void:
	var target := pow(clampf(level, 0.0, 1.0), VISUAL_ENERGY_POWER)
	var previous := energy
	var speed := ENERGY_ATTACK_SPEED if target > energy else ENERGY_RELEASE_SPEED
	var blend := 1.0 - exp(-speed * maxf(delta, 0.0))
	energy = lerpf(energy, target, blend)
	fast_energy = lerpf(fast_energy, target, 1.0 - exp(-FAST_ENERGY_SPEED * maxf(delta, 0.0)))
	slow_energy = lerpf(slow_energy, target, 1.0 - exp(-SLOW_ENERGY_SPEED * maxf(delta, 0.0)))
	var modulation := clampf(absf(fast_energy - slow_energy) * 3.8, 0.0, 1.0)
	syllable = maxf(modulation, move_toward(syllable, 0.0, SYLLABLE_DECAY_SPEED * delta))
	var activity_target := smoothstep(0.08, 0.34, target)
	activity = lerpf(activity, activity_target, 1.0 - exp(-ACTIVITY_SPEED * maxf(delta, 0.0)))
	var onset := clampf((energy - previous) * 9.0, 0.0, 1.0)
	attack = maxf(onset, move_toward(attack, 0.0, ATTACK_DECAY_SPEED * delta))
	peak = maxf(attack, move_toward(peak, 0.0, PEAK_DECAY_SPEED * delta))
	push_ripple_history(clampf(syllable + attack * 0.55, 0.0, 1.0), delta)
	pass


func push_ripple_history(value: float, delta: float) -> void:
	if ripple_history.size() != RIPPLE_HISTORY_SIZE:
		ripple_history.resize(RIPPLE_HISTORY_SIZE)
		ripple_history.fill(0.0)
	ripple_accumulator += RIPPLE_SAMPLE_RATE * delta
	var steps := mini(int(ripple_accumulator), RIPPLE_HISTORY_SIZE)
	if steps <= 0:
		return
	ripple_accumulator -= float(steps)
	for i in range(RIPPLE_HISTORY_SIZE - steps):
		ripple_history[i] = ripple_history[i + steps]
	for i in range(RIPPLE_HISTORY_SIZE - steps, RIPPLE_HISTORY_SIZE):
		ripple_history[i] = value
	pass


func setup_shader() -> void:
	ripple_history.resize(RIPPLE_HISTORY_SIZE)
	ripple_history.fill(0.0)
	ripple_image = Image.create(RIPPLE_HISTORY_SIZE, 1, false, Image.FORMAT_RF)
	ripple_texture = ImageTexture.create_from_image(ripple_image)
	singularity_material = ShaderMaterial.new()
	singularity_material.shader = SINGULARITY_SHADER
	singularity_material.set_shader_parameter("ripple_texture", ripple_texture)
	canvas.material = singularity_material
	update_shader()
	pass


func update_shader() -> void:
	if singularity_material == null:
		return
	for i in range(RIPPLE_HISTORY_SIZE):
		ripple_image.set_pixel(i, 0, Color(ripple_history[i], 0.0, 0.0, 1.0))
	ripple_texture.update(ripple_image)
	var accent := ThemeColor.accent_theme_color() if phase == Phase.RECORDING else Colors.info
	singularity_material.set_shader_parameter("accent_color", accent)
	singularity_material.set_shader_parameter("elapsed", elapsed)
	singularity_material.set_shader_parameter("fade_alpha", fade)
	singularity_material.set_shader_parameter("energy", energy)
	singularity_material.set_shader_parameter("syllable", syllable)
	singularity_material.set_shader_parameter("activity", activity)
	singularity_material.set_shader_parameter("attack", attack)
	singularity_material.set_shader_parameter("peak", peak)
	singularity_material.set_shader_parameter("phase_mode", float(phase))
	singularity_material.set_shader_parameter("impact_progress", clampf(phase_time / IMPACT_SECONDS, 0.0, 1.0))
	pass


class FxCanvas extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		pass
