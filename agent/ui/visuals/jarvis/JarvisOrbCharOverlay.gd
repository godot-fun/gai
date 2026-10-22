class_name JarvisOrbCharOverlay
extends Node3D

## Short sentences: keyword-style float; long sentences: 3D curve flight.

const MAX_DISPLAY := 16
const SHARED_CURVE_COUNT := 20
const MIN_PHRASE_LEN := 2
## At or below this length (chars), use orb float; above, use path flight.
const SHORT_SENTENCE_LEN := 28

var neuron_net: JarvisOrbNeuronNet
var char_queue: Array[String] = []
var active_sentences: Array[FlyingSentence] = []
var shared_curves: Array[Curve3D] = []

var current_path_style: OrbPhase.PathStyle = OrbPhase.PathStyle.TRANSVERSE
var display_color: Color = ThemeColor.accent_theme_color()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var drift_speed_scale: float = 1.0
var life_scale: float = 1.0


class FlyingSentence:
	extends RefCounted

	enum Mode { FLOAT, PATH }

	var label: Label3D
	var color: Color = Color.WHITE
	var mode: Mode = Mode.FLOAT

	var age: float = 0.0
	var life: float = 7.0
	var drift_speed: float = OrbVisualScale.SENTENCE_DRIFT_SPEED

	var curve: Curve3D
	var progress: float = 0.0
	var path_speed: float = 0.22

	func begin_float(p_label: Label3D, text: String, p_color: Color, p_life: float, p_drift: float) -> void:
		mode = Mode.FLOAT
		label = p_label
		color = p_color
		age = 0.0
		life = p_life
		drift_speed = p_drift
		label.text = text
		label.modulate = Color(color.r, color.g, color.b, 0.0)
		label.visible = true
		pass

	func begin_path(p_label: Label3D, p_curve: Curve3D, text: String, p_color: Color, p_speed: float) -> void:
		mode = Mode.PATH
		label = p_label
		curve = p_curve
		color = p_color
		progress = 0.0
		path_speed = p_speed
		label.text = text
		label.modulate = Color(color.r, color.g, color.b, 0.0)
		label.visible = true
		pass

	func advance(delta: float) -> bool:
		if mode == Mode.FLOAT:
			age += delta
			var t: float = age / life
			var alpha: float = sin(clampf(t, 0.0, 1.0) * PI) * 0.75
			label.modulate = Color(color.r, color.g, color.b, alpha)
			label.position += Vector3(0.0, delta * drift_speed, 0.0)
			return age < life
		progress += delta * path_speed
		var path_t := clampf(progress, 0.0, 1.0)
		var pos := curve.sample_baked(path_t * curve.get_baked_length())
		label.position = pos
		var fade := sin(path_t * PI)
		label.modulate = Color(color.r, color.g, color.b, fade * 0.95)
		return progress < 1.0
		pass


func setup(net: JarvisOrbNeuronNet) -> void:
	neuron_net = net
	rng.randomize()
	refresh_shared_curves()
	pass


func _process(delta: float) -> void:
	spawn_from_queue()
	update_flying_sentences(delta)
	pass


func enqueue_sentence(text: String) -> void:
	var display := text.strip_edges()
	if display.is_empty() or display.length() < MIN_PHRASE_LEN:
		return
	char_queue.append(display)
	pass


func can_accept_display_load() -> bool:
	return active_sentences.size() + char_queue.size() < MAX_DISPLAY


func reset_growth() -> void:
	char_queue.clear()
	refresh_shared_curves()
	pass


func set_phase(phase: OrbPhase.Phase) -> void:
	current_path_style = OrbPhase.path_style_for(phase)
	match phase:
		OrbPhase.Phase.REASONING:
			drift_speed_scale = 0.65
			life_scale = 1.35
		OrbPhase.Phase.ERROR, OrbPhase.Phase.TOOL_EXEC:
			drift_speed_scale = 1.15
			life_scale = 0.9
		_:
			drift_speed_scale = 1.0
			life_scale = 1.0
	refresh_shared_curves()
	pass


func refresh_shared_curves() -> void:
	shared_curves.clear()
	var neurons := neuron_net.get_positions()
	var styles: Array[OrbPhase.PathStyle] = [
		OrbPhase.PathStyle.TRANSVERSE,
		OrbPhase.PathStyle.SPIRAL_IN,
		OrbPhase.PathStyle.ORBIT,
		OrbPhase.PathStyle.CHAOTIC,
	]
	for _i in SHARED_CURVE_COUNT:
		var style: OrbPhase.PathStyle = styles[rng.randi_range(0, styles.size() - 1)]
		shared_curves.append(CharStreamCurves.build(style, neurons, rng))
	pass


func make_billboard_label(font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.font = Fonts.regular()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 0
	label.pixel_size = pixel_size
	label.modulate = Color(1, 1, 1, 0)
	label.visible = false
	add_child(label)
	return label
	pass


func spawn_from_queue() -> void:
	while not char_queue.is_empty() and active_sentences.size() < MAX_DISPLAY:
		spawn_sentence(char_queue.pop_front())
	pass


func acquire_curve() -> Curve3D:
	if shared_curves.is_empty():
		refresh_shared_curves()
	if shared_curves.is_empty():
		return CharStreamCurves.build(current_path_style, neuron_net.get_positions(), rng)
	return shared_curves[rng.randi_range(0, shared_curves.size() - 1)]


func spawn_sentence(text: String) -> void:
	var len := text.length()
	var flying := FlyingSentence.new()
	if len <= SHORT_SENTENCE_LEN:
		spawn_short_sentence(text, len, flying)
	else:
		spawn_long_sentence(text, len, flying)
	active_sentences.append(flying)
	pass


func spawn_short_sentence(text: String, len: int, flying: FlyingSentence) -> void:
	var label: Label3D = make_billboard_label(short_font_size(len), short_pixel_size(len))
	var angle: float = rng.randf() * TAU
	var radius: float = rng.randf_range(1.15, 1.72)
	label.position = Vector3(
		cos(angle) * radius,
		rng.randf_range(-0.45, 0.55),
		sin(angle) * radius * 0.55
	)
	label.rotation.y = angle
	var life: float = rng.randf_range(OrbVisualScale.SENTENCE_LIFE_MIN, OrbVisualScale.SENTENCE_LIFE_MAX) * life_scale
	var drift: float = OrbVisualScale.SENTENCE_DRIFT_SPEED * drift_speed_scale
	flying.begin_float(label, text, display_color, life, drift)
	pass


func spawn_long_sentence(text: String, len: int, flying: FlyingSentence) -> void:
	var label: Label3D = make_billboard_label(long_font_size(len), long_pixel_size(len))
	var speed: float = rng.randf_range(OrbVisualScale.PARTICLE_SPEED_MIN, OrbVisualScale.PARTICLE_SPEED_MAX)
	if current_path_style == OrbPhase.PathStyle.CHAOTIC:
		speed *= 1.25
	flying.begin_path(label, acquire_curve(), text, display_color, speed)
	pass


func short_font_size(len: int) -> int:
	return 22 if len > 14 else 34


func short_pixel_size(len: int) -> float:
	return 0.0016 if len > 14 else 0.0022


func long_font_size(len: int) -> int:
	if len > 48:
		return 16
	if len > 28:
		return 18
	return 20


func long_pixel_size(len: int) -> float:
	if len > 48:
		return 0.00135
	if len > 28:
		return 0.00155
	return 0.0018


func update_flying_sentences(delta: float) -> void:
	var i: int = 0
	while i < active_sentences.size():
		var flying := active_sentences[i]
		if flying.advance(delta):
			i += 1
			continue
		flying.label.queue_free()
		active_sentences.remove_at(i)
	pass
