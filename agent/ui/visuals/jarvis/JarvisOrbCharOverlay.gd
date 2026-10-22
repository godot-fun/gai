class_name JarvisOrbCharOverlay
extends Node3D

## Short sentences: keyword-style float; long sentences: 3D curve flight.

const MAX_DISPLAY := 16
const MIN_PHRASE_LEN := 2
## At or below this length (chars), use orb float; above, use path flight.
const SHORT_SENTENCE_LEN := 28

var neuron_net: JarvisOrbNeuronNet
var char_queue: Array[String] = []
var active_sentences: Array[FlyingSentence] = []

var current_path_style: OrbPhase.PathStyle = OrbPhase.PathStyle.TRANSVERSE
var display_color: Color = ThemeColor.accent_theme_color()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var drift_speed_scale: float = 1.0
var life_scale: float = 1.0


class FlyingSentence:
	extends RefCounted

	var label: Label3D
	var color: Color = Color.WHITE
	var uses_path: bool = false

	var age: float = 0.0
	var life: float = 7.0
	var drift_speed: float = OrbVisualScale.SENTENCE_DRIFT_SPEED
	var curve: Curve3D
	var progress: float = 0.0
	var path_speed: float = 0.22

	func prime_label(p_label: Label3D, text: String, p_color: Color) -> void:
		label = p_label
		color = p_color
		label.text = text
		label.modulate = Color(color.r, color.g, color.b, 0.0)
		label.visible = true
		pass

	func begin_float(p_label: Label3D, text: String, p_color: Color, p_life: float, p_drift: float) -> void:
		uses_path = false
		prime_label(p_label, text, p_color)
		age = 0.0
		life = p_life
		drift_speed = p_drift
		pass

	func begin_path(p_label: Label3D, p_curve: Curve3D, text: String, p_color: Color, p_speed: float) -> void:
		uses_path = true
		prime_label(p_label, text, p_color)
		curve = p_curve
		progress = 0.0
		path_speed = p_speed
		pass

	func advance(delta: float) -> bool:
		if not uses_path:
			age += delta
			var t: float = age / life
			var alpha: float = sin(clampf(t, 0.0, 1.0) * PI) * 0.75
			label.modulate = Color(color.r, color.g, color.b, alpha)
			label.position += Vector3(0.0, delta * drift_speed, 0.0)
			return age < life
		progress += delta * path_speed
		var path_t := clampf(progress, 0.0, 1.0)
		label.position = curve.sample_baked(path_t * curve.get_baked_length())
		var fade := sin(path_t * PI)
		label.modulate = Color(color.r, color.g, color.b, fade * 0.95)
		return progress < 1.0
		pass


func setup(net: JarvisOrbNeuronNet) -> void:
	neuron_net = net
	rng.randomize()
	pass


func _process(delta: float) -> void:
	while not char_queue.is_empty() and active_sentences.size() < MAX_DISPLAY:
		spawn_sentence(char_queue.pop_front())
	var i: int = 0
	while i < active_sentences.size():
		if active_sentences[i].advance(delta):
			i += 1
			continue
		active_sentences[i].label.queue_free()
		active_sentences.remove_at(i)
	pass


func enqueue_sentence(text: String) -> void:
	var display := text.strip_edges()
	if display.is_empty() or display.length() < MIN_PHRASE_LEN:
		return
	char_queue.append(display)
	pass


func can_accept_display_load() -> bool:
	return active_sentences.size() + char_queue.size() < MAX_DISPLAY


func clear_pending_sentences() -> void:
	char_queue.clear()
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


func label_metrics(len: int, short_style: bool) -> Vector2:
	if short_style:
		return Vector2(34 if len <= 14 else 22, 0.0022 if len <= 14 else 0.0016)
	return Vector2(16 if len > 48 else 18, 0.00135 if len > 48 else 0.00155)


func spawn_sentence(text: String) -> void:
	var len := text.length()
	var metrics := label_metrics(len, len <= SHORT_SENTENCE_LEN)
	var label: Label3D = make_billboard_label(int(metrics.x), metrics.y)
	var flying := FlyingSentence.new()
	if len <= SHORT_SENTENCE_LEN:
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(1.15, 1.72)
		label.position = Vector3(
			cos(angle) * radius,
			rng.randf_range(-0.45, 0.55),
			sin(angle) * radius * 0.55
		)
		label.rotation.y = angle
		var life: float = rng.randf_range(OrbVisualScale.SENTENCE_LIFE_MIN, OrbVisualScale.SENTENCE_LIFE_MAX) * life_scale
		flying.begin_float(
			label,
			text,
			display_color,
			life,
			OrbVisualScale.SENTENCE_DRIFT_SPEED * drift_speed_scale
		)
	else:
		var speed: float = rng.randf_range(OrbVisualScale.PARTICLE_SPEED_MIN, OrbVisualScale.PARTICLE_SPEED_MAX)
		if current_path_style == OrbPhase.PathStyle.CHAOTIC:
			speed *= 1.25
		var curve := CharStreamCurves.build(current_path_style, neuron_net.get_positions(), rng)
		flying.begin_path(label, curve, text, display_color, speed)
	active_sentences.append(flying)
	pass
