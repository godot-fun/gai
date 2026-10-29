shader_type canvas_item;
render_mode blend_disabled;

// Stable-fluids solver in one RGBA field: RG = velocity in cells per step, B = pressure,
// A = signed ink (positive warm, negative cool). Pass kinds: advect + impulses, Jacobi pressure
// iterations with divergence computed from the untouched velocity, then projection.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

const int PASS_ADVECT = 0;
const int PASS_PRESSURE = 1;
const int PASS_PROJECT = 2;

uniform float velocity_dissipation : hint_range(0.9, 1.0) = 0.985;
uniform float ink_dissipation : hint_range(0.9, 1.0) = 0.992;
uniform float buoyancy = 0.04;

void fragment() {
	vec4 s = state_at(UV);
	if (reset) {
		COLOR = vec4(0.0);
	} else if (pass_kind == PASS_ADVECT) {
		vec4 carried = state_at(UV - s.rg * texel);
		vec2 velocity = carried.rg * velocity_dissipation;
		float ink = carried.a * ink_dissipation;
		velocity.y -= buoyancy * abs(ink);
		for (int index = 0; index < impulse_count; index++) {
			vec4 shape = impulse_shapes[index];
			vec4 payload = impulse_vectors[index];
			float falloff = impulse_falloff(UV, shape);
			vec2 delta = impulse_delta(UV, shape);
			vec2 swirl = vec2(-delta.y, delta.x) / max(length(delta), 0.0001);
			velocity += (payload.xy + swirl * payload.z) * falloff;
			ink += shape.w * falloff;
		}
		COLOR = vec4(clamp(velocity, vec2(-8.0), vec2(8.0)), s.b, clamp(ink, -1.0, 1.0));
	} else if (pass_kind == PASS_PRESSURE) {
		vec4 left = state_offset(UV, vec2(-1.0, 0.0));
		vec4 right = state_offset(UV, vec2(1.0, 0.0));
		vec4 up = state_offset(UV, vec2(0.0, -1.0));
		vec4 down = state_offset(UV, vec2(0.0, 1.0));
		float divergence = 0.5 * ((right.r - left.r) + (down.g - up.g));
		float pressure = (left.b + right.b + up.b + down.b - divergence) * 0.25;
		COLOR = vec4(s.rg, pressure, s.a);
	} else {
		float left = state_offset(UV, vec2(-1.0, 0.0)).b;
		float right = state_offset(UV, vec2(1.0, 0.0)).b;
		float up = state_offset(UV, vec2(0.0, -1.0)).b;
		float down = state_offset(UV, vec2(0.0, 1.0)).b;
		vec2 velocity = s.rg - 0.5 * vec2(right - left, down - up);
		COLOR = vec4(velocity, s.b * 0.9, s.a);
	}
}
