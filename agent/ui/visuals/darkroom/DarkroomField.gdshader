shader_type canvas_item;
render_mode blend_disabled;

// Developer tray. R = how far the print has developed, G = liquid height, B = liquid velocity.
// Development runs unevenly with the chemistry and faster where the liquid moves; a fresh sheet
// bleaches back toward blank but never below a readable floor.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform float develop_step = 0.0;
uniform float bleach_step = 0.0;
uniform float bleach_floor = 0.2;
uniform float start_develop = 0.22;
uniform float agitate_gain = 6.0;
uniform float wave_speed : hint_range(0.0, 0.5) = 0.42;
uniform float wave_damping : hint_range(0.9, 1.0) = 0.986;

float chem_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = field_hash(cell);
	float b = field_hash(cell + vec2(1.0, 0.0));
	float c = field_hash(cell + vec2(0.0, 1.0));
	float d = field_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

float chemistry(vec2 uv) {
	vec2 p = uv * vec2(aspect, 1.0);
	return chem_noise(p * 4.0) * 0.65 + chem_noise(p * 11.0 + vec2(7.3, 1.9)) * 0.35;
}

void fragment() {
	vec4 s = state_at(UV);
	float chem = chemistry(UV);
	if (reset) {
		COLOR = vec4(start_develop * (0.8 + 0.4 * chem), 0.0, 0.0, 1.0);
	} else {
		float height = s.g;
		float laplacian = state_offset(UV, vec2(1.0, 0.0)).g + state_offset(UV, vec2(-1.0, 0.0)).g
			+ state_offset(UV, vec2(0.0, 1.0)).g + state_offset(UV, vec2(0.0, -1.0)).g - 4.0 * height;
		float velocity = (s.b + laplacian * wave_speed) * wave_damping;
		for (int index = 0; index < impulse_count; index++) {
			velocity += impulse_shapes[index].w * impulse_falloff(UV, impulse_shapes[index]);
		}
		height = (height + velocity) * 0.998;
		float agitation = min(abs(velocity) * agitate_gain, 1.5);
		float developed = s.r + develop_step * (0.45 + 0.9 * chem) * (1.0 + agitation);
		float bleached = developed - bleach_step * (0.6 + 0.8 * chem);
		developed = max(bleached, min(developed, bleach_floor));
		COLOR = vec4(clamp(developed, 0.0, 1.0), clamp(height, -2.0, 2.0), clamp(velocity, -2.0, 2.0), 1.0);
	}
}
