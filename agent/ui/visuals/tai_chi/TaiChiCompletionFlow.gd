class_name TaiChiCompletionFlow
extends RefCounted

## Pulls all motion back into a final quiet flash before the visual fades away.

const DURATION := 1.25

var progress: float = 0.0
var active: bool = false
var failed: bool = false


func reset() -> void:
	progress = 0.0
	active = false
	failed = false
	pass


func begin(has_error: bool) -> void:
	active = true
	failed = has_error
	progress = 0.0
	pass


func advance(delta: float) -> bool:
	if not active or progress >= 1.0:
		return false
	progress = minf(1.0, progress + delta / DURATION)
	return true


func draw(canvas: Control, center: Vector2) -> void:
	if not active:
		return
	var pulse := sin(progress * PI)
	var color := ColorBase.error if failed else ColorBase.primary_text
	for index in 4:
		canvas.draw_arc(center, 16.0 + float(index) * 19.0 + progress * 28.0, 0.0, TAU, 64, Color(color, pulse * (0.16 - float(index) * 0.025)), 1.4, true)
	pass
