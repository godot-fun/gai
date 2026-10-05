class_name OrbPhase
extends RefCounted

## Visual phase for the Jarvis orb — driven by AgentEvents lifecycle.

enum Phase {
	IDLE,
	AWAKE,
	REASONING,
	GENERATING,
	TOOL_EXEC,
	TURN_COOLDOWN,
	SUCCESS,
	ERROR,
}

enum PathStyle {
	SPIRAL_IN,
	TRANSVERSE,
	ORBIT,
	CHAOTIC,
}


static func path_style_for(phase: Phase) -> PathStyle:
	match phase:
		Phase.REASONING:
			return PathStyle.SPIRAL_IN
		Phase.TOOL_EXEC:
			return PathStyle.ORBIT
		Phase.ERROR:
			return PathStyle.CHAOTIC
		_:
			return PathStyle.TRANSVERSE


static func color_for(phase: Phase) -> Color:
	match phase:
		Phase.REASONING:
			return phase_color_from_theme(0.72, 0.85, 1.0)
		Phase.GENERATING:
			return phase_color_from_theme(0.0, 1.05, 1.02)
		Phase.TOOL_EXEC:
			return phase_color_from_theme(0.12, 0.9, 1.05)
		Phase.SUCCESS:
			return ThemeColor.accent_theme_color().lerp(ColorBase.success, 0.45)
		Phase.ERROR:
			return ThemeColor.accent_theme_color().lerp(ColorBase.error, 0.55)
		Phase.AWAKE, Phase.TURN_COOLDOWN:
			return phase_color_from_theme()
		Phase.IDLE:
			return phase_color_from_theme(0.0, 1.0, 1.0, 0.6)
		_:
			return phase_color_from_theme(0.0, 1.0, 1.0, 0.6)


## Hue/sat/value offsets relative to ThemeColor.theme_color (HSV).
static func phase_color_from_theme(
	hue_offset: float = 0.0,
	sat_mul: float = 1.0,
	val_mul: float = 1.0,
	alpha: float = 1.0,
) -> Color:
	var base := ThemeColor.theme_color
	var rgb := Color.from_hsv(
		fmod(base.h + hue_offset, 1.0),
		clampf(base.s * sat_mul, 0.0, 1.0),
		clampf(base.v * val_mul, 0.0, 1.0),
	)
	return Color(rgb.r, rgb.g, rgb.b, alpha)
