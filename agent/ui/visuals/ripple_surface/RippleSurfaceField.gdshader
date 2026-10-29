shader_type canvas_item;
render_mode blend_disabled;

// Damped wave equation on a height field. R = height, G = vertical velocity.
// Clamped neighbor reads give reflecting window edges.
#include "res://agent/ui/visuals/SimulationField.gdshaderinc"

uniform float wave_speed : hint_range(0.0, 0.5) = 0.45;
uniform float damping : hint_range(0.9, 1.0) = 0.995;

void fragment() {
	if (reset) {
		COLOR = vec4(0.0);
	} else {
		vec4 s = state_at(UV);
		float laplacian = state_offset(UV, vec2(1.0, 0.0)).r + state_offset(UV, vec2(-1.0, 0.0)).r
			+ state_offset(UV, vec2(0.0, 1.0)).r + state_offset(UV, vec2(0.0, -1.0)).r - 4.0 * s.r;
		float velocity = (s.g + laplacian * wave_speed) * damping;
		float height = (s.r + velocity) * 0.9992;
		for (int index = 0; index < impulse_count; index++) {
			height += impulse_shapes[index].w * impulse_falloff(UV, impulse_shapes[index]);
		}
		COLOR = vec4(height, velocity, 0.0, 1.0);
	}
}
