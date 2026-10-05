class_name CharParticle
extends RefCounted

## Single character following a 3D curve — rendered via Label3D billboard.

var label: Label3D
var curve: Curve3D
var progress: float = 0.0
var speed: float = 0.22
var alive: bool = false
var color: Color = Color.WHITE
var near_neuron_index: int = -1


func reset(
	p_label: Label3D,
	p_curve: Curve3D,
	p_char: String,
	p_color: Color,
	p_speed: float,
	p_near_neuron: int
) -> void:
	label = p_label
	curve = p_curve
	progress = 0.0
	speed = p_speed
	alive = true
	color = p_color
	near_neuron_index = p_near_neuron
	label.text = p_char
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.visible = true
	pass


func update(delta: float) -> bool:
	if not alive or label == null or curve == null:
		return false
	progress += delta * speed
	var t := clampf(progress, 0.0, 1.0)
	var pos := curve.sample_baked(t * curve.get_baked_length())
	label.position = pos
	var fade := sin(t * PI)
	label.modulate = Color(color.r, color.g, color.b, fade * 0.95)
	if progress >= 1.0:
		alive = false
		label.visible = false
		return false
	return true


func release() -> void:
	alive = false
	if label != null:
		label.visible = false
		label.text = ""
	pass
