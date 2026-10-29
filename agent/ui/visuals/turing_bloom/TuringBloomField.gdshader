shader_type canvas_item;
render_mode blend_disabled;

// Gray-Scott reaction-diffusion. R = substrate A, G = catalyst B. Impulses seed catalyst;
// feed/kill pick the regime (maze vs coral vs dissolve) and growth scales the time step.
#include "res://agent/ui/visuals/SimulationField.gdshaderinc"

uniform float feed : hint_range(0.0, 0.1) = 0.037;
uniform float kill : hint_range(0.0, 0.1) = 0.06;
uniform float growth : hint_range(0.0, 1.0) = 1.0;

vec2 laplacian(vec2 uv, vec2 center) {
	vec2 sum = -center;
	sum += 0.2 * (state_offset(uv, vec2(1.0, 0.0)).rg + state_offset(uv, vec2(-1.0, 0.0)).rg
		+ state_offset(uv, vec2(0.0, 1.0)).rg + state_offset(uv, vec2(0.0, -1.0)).rg);
	sum += 0.05 * (state_offset(uv, vec2(1.0, 1.0)).rg + state_offset(uv, vec2(-1.0, 1.0)).rg
		+ state_offset(uv, vec2(1.0, -1.0)).rg + state_offset(uv, vec2(-1.0, -1.0)).rg);
	return sum;
}

void fragment() {
	if (reset) {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0);
	} else {
		vec2 s = state_at(UV).rg;
		vec2 lap = laplacian(UV, s);
		float reaction = s.x * s.y * s.y;
		float a = s.x + (1.0 * lap.x - reaction + feed * (1.0 - s.x)) * growth;
		float b = s.y + (0.5 * lap.y + reaction - (kill + feed) * s.y) * growth;
		for (int index = 0; index < impulse_count; index++) {
			float seed = impulse_falloff(UV, impulse_shapes[index]) * impulse_shapes[index].w;
			b = max(b, seed * 0.5);
			a = min(a, 1.0 - seed * 0.5);
		}
		COLOR = vec4(clamp(a, 0.0, 1.0), clamp(b, 0.0, 1.0), 0.0, 1.0);
	}
}
