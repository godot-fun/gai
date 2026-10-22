class_name JarvisOrb
extends Node3D

## 3D Jarvis brain orb — neuron net, rings, and char overlay.

var neuron_net: JarvisOrbNeuronNet
var rings: JarvisOrbRings3D
var char_overlay: JarvisOrbCharOverlay

var phase: OrbPhase.Phase = OrbPhase.Phase.IDLE
var spin_speed: float = 0.7
var stream_char_total: int = 0
var orb_color_controller: OrbColorController = OrbColorController.new()

var applied_display_color: Color = Color.TRANSPARENT


func _ready() -> void:
	scale = Vector3.ONE * OrbVisualScale.WORLD_SCALE
	rings = JarvisOrbRings3D.new()
	add_child(rings)

	neuron_net = JarvisOrbNeuronNet.new()
	add_child(neuron_net)

	char_overlay = JarvisOrbCharOverlay.new()
	char_overlay.setup(neuron_net)
	add_child(char_overlay)
	orb_color_controller.snap_to(OrbPhase.color_for(OrbPhase.Phase.AWAKE))
	gdf.events.theme_color_changed.connect(on_theme_color_changed)
	push_display_color()
	pass


func on_theme_color_changed() -> void:
	orb_color_controller.set_target(OrbPhase.color_for(phase))
	push_display_color()
	pass


func _process(delta: float) -> void:
	neuron_net.wander_speed_scale = spin_speed
	orb_color_controller.update(delta)
	push_display_color()
	pass


func set_phase(new_phase: OrbPhase.Phase) -> void:
	phase = new_phase
	orb_color_controller.set_target(OrbPhase.color_for(new_phase))
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
	push_display_color()
	pass


func add_step_text(text: String) -> void:
	if text.is_empty():
		return
	stream_char_total += text.length()
	char_overlay.enqueue_sentence(text)
	pass


func apply_neuron_growth() -> void:
	neuron_net.apply_growth(stream_char_total)
	pass


func push_display_color() -> void:
	var color: Color = orb_color_controller.display_color
	if color.is_equal_approx(applied_display_color):
		return
	applied_display_color = color
	neuron_net.apply_display_color(color)
	rings.apply_display_color(color)
	char_overlay.display_color = color
	pass


func reset_growth() -> void:
	orb_color_controller.snap_to(OrbPhase.color_for(OrbPhase.Phase.IDLE))
	stream_char_total = 0
	neuron_net.reset_growth()
	char_overlay.reset_growth()
	push_display_color()
	pass
