class_name JarvisOrb
extends Node3D

## 3D Jarvis brain orb — neuron net, rings, and char overlay.

var neuron_net: JarvisOrbNeuronNet
var rings: JarvisOrbRings3D
var char_overlay: JarvisOrbCharOverlay

var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var spin_speed: float = 0.7
var stream_char_total: int = 0
var color_controller: OrbColorController = OrbColorController.new()

var growth_dirty: bool = false
var growth_flush_timer: float = 0.0


func _ready() -> void:
	scale = Vector3.ONE * OrbVisualScale.WORLD_SCALE
	rings = JarvisOrbRings3D.new()
	add_child(rings)

	neuron_net = JarvisOrbNeuronNet.new()
	add_child(neuron_net)

	char_overlay = JarvisOrbCharOverlay.new()
	char_overlay.setup(neuron_net)
	add_child(char_overlay)
	color_controller.snap_to(OrbPhase.color_for(OrbPhase.Phase.AWAKE))
	gdf.events.theme_color_changed.connect(on_theme_color_changed)
	apply_display_color()
	pass


func on_theme_color_changed() -> void:
	color_controller.set_target(OrbPhase.color_for(phase))
	pass


func _process(delta: float) -> void:
	if neuron_net != null:
		neuron_net.wander_speed_scale = spin_speed

	color_controller.update(delta)
	apply_display_color()

	if growth_flush_timer > 0.0:
		growth_flush_timer = maxf(0.0, growth_flush_timer - delta)
		if growth_flush_timer <= 0.0 and growth_dirty:
			flush_growth()
	pass


func set_phase(new_phase: OrbPhase.Phase) -> void:
	phase = new_phase
	color_controller.set_target(OrbPhase.color_for(new_phase))
	char_overlay.set_phase(new_phase)
	rings.set_tool_mode(new_phase == OrbPhase.Phase.TOOL_EXEC)
	neuron_net.set_thinking(new_phase == OrbPhase.Phase.REASONING)
	match new_phase:
		OrbPhase.Phase.REASONING:
			spin_speed = 2.35
		OrbPhase.Phase.TOOL_EXEC:
			spin_speed = 1.1
		OrbPhase.Phase.ERROR:
			spin_speed = 1.6
		_:
			spin_speed = 0.7
	if new_phase != OrbPhase.Phase.IDLE:
		neuron_net.pulse_random(0.9)
	pass


func add_step_text(text: String) -> void:
	if text.is_empty():
		return
	stream_char_total += text.length()
	offer_segments([text])
	pass


func offer_segments(segments: Array[String]) -> void:
	if segments.is_empty():
		return
	char_overlay.stage_segments(segments)
	growth_dirty = true
	growth_flush_timer = OrbGrowth.TEXT_BATCH_INTERVAL_S
	pass


func flush_growth() -> void:
	growth_dirty = false
	char_overlay.commit_staged_segments()
	char_overlay.apply_growth(stream_char_total)
	neuron_net.apply_growth(stream_char_total)
	pass


func apply_display_color() -> void:
	var color: Color = color_controller.display_color
	neuron_net.apply_display_color(color)
	rings.apply_display_color(color)
	char_overlay.sync_display_color(color)
	pass


func reset_growth() -> void:
	if growth_dirty:
		flush_growth()
	color_controller.snap_to(OrbPhase.color_for(OrbPhase.Phase.IDLE))
	stream_char_total = 0
	growth_dirty = false
	growth_flush_timer = 0.0
	neuron_net.reset_growth()
	char_overlay.reset_growth()
	pass


func clear_stream_queue() -> void:
	if char_overlay != null:
		char_overlay.clear_queue()
	pass
