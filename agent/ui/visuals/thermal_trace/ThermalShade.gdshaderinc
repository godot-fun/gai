// Luminance the thermal display removes from a pixel at a given raw heat. Shared by the display
// and the sensing pass so the field can undo it; zero on dark themes. The small cold floor tints
// idle paper too, so the whole view reads as a thermal camera rather than only hot spots.
uniform float light_shade : hint_range(0.0, 0.6) = 0.0;

float heat_shade(float raw_heat) {
	return light_shade * mix(0.12, 1.0, smoothstep(0.02, 0.45, clamp(raw_heat, 0.0, 1.0)));
}
