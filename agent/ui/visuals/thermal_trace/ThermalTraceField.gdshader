shader_type canvas_item;
render_mode blend_disabled;

// Heat from real interface activity. R = heat, G = last sensed luminance. Pass 0 compares the
// previous root frame with the stored luminance and adds the difference as heat; later passes
// diffuse it. The display only shifts chroma, so frame luminance stays free of feedback.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

const int PASS_SENSE = 0;

uniform sampler2D previous_frame_tex : repeat_disable, filter_linear;
uniform float sensitivity = 5.0;
uniform float cooling : hint_range(0.9, 1.0) = 0.985;
uniform float diffusion : hint_range(0.0, 1.0) = 0.35;

float sensed_luminance(vec2 uv) {
	vec2 spread = texel * 0.25;
	vec3 sum = texture(previous_frame_tex, uv + vec2(-spread.x, -spread.y)).rgb
		+ texture(previous_frame_tex, uv + vec2(spread.x, -spread.y)).rgb
		+ texture(previous_frame_tex, uv + vec2(-spread.x, spread.y)).rgb
		+ texture(previous_frame_tex, uv + vec2(spread.x, spread.y)).rgb;
	return dot(sum * 0.25, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 s = state_at(UV);
	if (pass_kind == PASS_SENSE) {
		float luminance = sensed_luminance(UV);
		if (reset) {
			COLOR = vec4(0.0, luminance, 0.0, 1.0);
		} else {
			float change = max(abs(luminance - s.g) - 0.012, 0.0);
			float heat = s.r * cooling + change * sensitivity;
			for (int index = 0; index < impulse_count; index++) {
				heat += impulse_shapes[index].w * impulse_falloff(UV, impulse_shapes[index]);
			}
			COLOR = vec4(clamp(heat, 0.0, 1.6), luminance, 0.0, 1.0);
		}
	} else {
		float neighbors = (state_offset(UV, vec2(1.0, 0.0)).r + state_offset(UV, vec2(-1.0, 0.0)).r
			+ state_offset(UV, vec2(0.0, 1.0)).r + state_offset(UV, vec2(0.0, -1.0)).r) * 0.25;
		COLOR = vec4(mix(s.r, neighbors, diffusion), s.g, 0.0, 1.0);
	}
}
