class_name TaiChiThinkingFlow
extends RefCounted

## Breathes a restrained pair of ink currents around the center while tokens arrive.

var energy: float = 0.0
var phase: float = 0.0


func reset() -> void:
	energy = 0.0
	phase = 0.0
	pass


func awaken(amount: float = 1.0) -> void:
	energy = minf(1.0, energy + amount)
	pass


func advance(delta: float) -> bool:
	phase += delta
	var previous := energy
	energy = move_toward(energy, 0.12, delta * 0.28)
	return previous != energy or energy > 0.12


func draw(canvas: Control, center: Vector2, reveal: float) -> void:
	if reveal < 0.88 or energy <= 0.01:
		return
	var alpha := (reveal - 0.88) / 0.12 * energy
	var radius := minf(canvas.size.x, canvas.size.y) * 0.085
	for index in 24:
		var angle_a := TAU * float(index) / 24.0 + phase * 0.13
		var angle_b := TAU * float(index + 1) / 24.0 + phase * 0.13
		var wave_a := sin(angle_a * 2.0 - phase) * radius * 0.12
		var wave_b := sin(angle_b * 2.0 - phase) * radius * 0.12
		var a := center + Vector2.from_angle(angle_a) * (radius + wave_a)
		var b := center + Vector2.from_angle(angle_b) * (radius + wave_b)
		canvas.draw_line(a, b, Color(1.0, 0.86, 0.5, alpha * 0.16), 1.2, true)
	pass
