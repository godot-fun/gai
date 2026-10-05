class_name JarvisOrbCharOverlay
extends Node3D

## Sentence-level particle stream rendered as Label3D billboards.

const POOL_SIZE := 320
const KEYWORD_POOL := 48
const SHARED_CURVE_COUNT := 20
const CHAR_QUEUE_CAP := 900

var neuron_net: JarvisOrbNeuronNet
var char_queue: Array[String] = []
var active_particles: Array[CharParticle] = []
var free_labels: Array[Label3D] = []
var keyword_labels: Array[Label3D] = []
var shared_curves: Array[Curve3D] = []

var current_phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var current_path_style: OrbPhase.PathStyle = OrbPhase.PathStyle.TRANSVERSE
var display_color: Color = ThemeColor.accent_theme_color()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var stream_char_total: int = 0
var max_active: int = OrbGrowth.PARTICLE_CAP_MIN
var spawn_per_frame: int = OrbGrowth.SPAWN_FRAME_MIN
var recent_phrases: Array[String] = []
var staged_segments: Array[String] = []


func setup(net: JarvisOrbNeuronNet) -> void:
	neuron_net = net
	rng.randomize()
	build_label_pools()
	refresh_shared_curves()
	pass


func _process(delta: float) -> void:
	spawn_from_queue()
	update_particles(delta)
	update_keywords(delta)
	pass


func stage_segments(segments: Array[String]) -> void:
	staged_segments.append_array(segments)
	pass


func commit_staged_segments() -> void:
	if staged_segments.is_empty():
		return
	var keyword_cap := maxi(OrbGrowth.stream_keyword_cap(stream_char_total), OrbGrowth.keyword_burst(stream_char_total))
	var keywords: Array[String] = []
	var seen: Dictionary = {}
	for segment in staged_segments:
		var display := CharStreamUtils.display_phrase(segment)
		if display.is_empty() or display.length() < CharStreamUtils.MIN_PHRASE_LEN:
			continue
		if char_queue.size() >= CHAR_QUEUE_CAP:
			char_queue.pop_front()
		char_queue.append(display)
		if keywords.size() < keyword_cap and not seen.has(display) and not recent_phrases.has(display):
			seen[display] = true
			keywords.append(display)
	staged_segments.clear()
	if not keywords.is_empty():
		spawn_keywords(keywords)
	pass


func apply_growth(char_total: int) -> void:
	stream_char_total = char_total
	max_active = OrbGrowth.particle_cap(char_total)
	spawn_per_frame = OrbGrowth.spawn_per_frame(char_total)
	pass


func reset_growth() -> void:
	stream_char_total = 0
	max_active = OrbGrowth.PARTICLE_CAP_MIN
	spawn_per_frame = OrbGrowth.SPAWN_FRAME_MIN
	recent_phrases.clear()
	clear_queue()
	refresh_shared_curves()
	pass


func set_phase(phase: OrbPhase.Phase) -> void:
	current_phase = phase
	current_path_style = OrbPhase.path_style_for(phase)
	refresh_shared_curves()
	pass


func sync_display_color(color: Color) -> void:
	display_color = color
	pass


func clear_queue() -> void:
	char_queue.clear()
	staged_segments.clear()
	pass


func apply_orb_font(label: Label3D) -> void:
	label.font = Fonts.regular()
	pass


func refresh_shared_curves() -> void:
	shared_curves.clear()
	if neuron_net == null:
		return
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


func build_label_pools() -> void:
	for _i in POOL_SIZE:
		free_labels.append(make_pool_label(20, 0.0018))
	for _i in KEYWORD_POOL:
		keyword_labels.append(make_pool_label(36, 0.0022))
	pass


func make_pool_label(font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	apply_orb_font(label)
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
	var spawned: int = 0
	while not char_queue.is_empty() and spawned < spawn_per_frame and active_particles.size() < max_active:
		if free_labels.is_empty():
			break
		spawn_segment(char_queue.pop_front())
		spawned += 1
	pass


func acquire_curve() -> Curve3D:
	if shared_curves.is_empty():
		refresh_shared_curves()
	if shared_curves.is_empty():
		return CharStreamCurves.build(current_path_style, neuron_net.get_positions(), rng)
	return shared_curves[rng.randi_range(0, shared_curves.size() - 1)]


func spawn_segment(segment: String) -> void:
	if neuron_net == null or free_labels.is_empty():
		return
	var label: Label3D = free_labels.pop_back()
	var token_len := segment.length()
	if token_len > 1:
		label.font_size = 16 if token_len > 10 else 18
		label.pixel_size = 0.00135 if token_len > 10 else 0.00155
	else:
		label.font_size = 20
		label.pixel_size = 0.0018
	var near_index := rng.randi_range(0, maxi(neuron_net.get_positions().size() - 1, 0))
	var speed: float = rng.randf_range(OrbVisualScale.PARTICLE_SPEED_MIN, OrbVisualScale.PARTICLE_SPEED_MAX)
	if current_path_style == OrbPhase.PathStyle.CHAOTIC:
		speed *= 1.25
	var particle := CharParticle.new()
	particle.reset(label, acquire_curve(), segment, display_color, speed, near_index)
	active_particles.append(particle)
	pass


func update_particles(delta: float) -> void:
	var i: int = 0
	while i < active_particles.size():
		var particle := active_particles[i]
		if particle.update(delta):
			i += 1
			continue
		free_labels.append(particle.label)
		active_particles.remove_at(i)
	pass


func spawn_keywords(words: Array[String]) -> void:
	var available: Array[Label3D] = []
	for label in keyword_labels:
		if not label.visible:
			available.append(label)
	if available.is_empty():
		return
	for word in words:
		if available.is_empty():
			break
		if recent_phrases.has(word):
			continue
		var label: Label3D = available.pop_back()
		recent_phrases.append(word)
		while recent_phrases.size() > 48:
			recent_phrases.pop_front()
		label.text = word
		label.set_meta("birth_color", display_color)
		label.font_size = 22 if word.length() > 14 else 34
		label.pixel_size = 0.0016 if word.length() > 14 else 0.0022
		label.modulate = Color(display_color.r, display_color.g, display_color.b, 0.0)
		label.visible = true
		label.set_meta("life", rng.randf_range(OrbVisualScale.KEYWORD_LIFE_MIN, OrbVisualScale.KEYWORD_LIFE_MAX))
		label.set_meta("age", 0.0)
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(1.15, 1.72)
		label.position = Vector3(
			cos(angle) * radius,
			rng.randf_range(-0.45, 0.55),
			sin(angle) * radius * 0.55
		)
		label.rotation.y = angle
	pass


func update_keywords(delta: float) -> void:
	for label in keyword_labels:
		if not label.visible:
			continue
		var age: float = float(label.get_meta("age", 0.0)) + delta
		var life: float = float(label.get_meta("life", 2.5))
		label.set_meta("age", age)
		var t: float = age / life
		var alpha: float = sin(clampf(t, 0.0, 1.0) * PI) * 0.75
		var birth: Color = label.get_meta("birth_color", display_color)
		label.modulate = Color(birth.r, birth.g, birth.b, alpha)
		label.position += Vector3(0.0, delta * OrbVisualScale.KEYWORD_DRIFT_SPEED, 0.0)
		if age >= life:
			label.visible = false
	pass
