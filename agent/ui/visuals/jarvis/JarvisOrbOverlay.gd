class_name JarvisOrbOverlay
extends ColorRect

## Full-screen vignette behind the orb — non-interactive.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.0, 0.03, 0.06, 0.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	pass


func set_strength(strength: float) -> void:
	var alpha: float = clampf(strength, 0.0, 0.78)
	color = Color(0.0, 0.03, 0.06, alpha)
	pass
