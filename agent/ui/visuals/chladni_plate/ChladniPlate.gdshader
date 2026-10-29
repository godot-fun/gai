shader_type canvas_item;

// Sand grains drawn over the live interface. Dense sand on the nodal lines reads as solid
// figures; sparse sand is a light scatter of grains that flicker where the plate still shakes.
// A faint ghost of the current nodal figure hints where the sand is heading.
// Zero activity is an identity pass.
#include "res://agent/ui/visuals/chladni_plate/ChladniMode.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform float drive : hint_range(0.0, 1.0) = 0.0;
uniform float grain_px = 2.0;
uniform float sand_opacity : hint_range(0.0, 1.0) = 0.9;
uniform float ghost_gain : hint_range(0.0, 1.0) = 0.1;
uniform vec4 sand_color : source_color = vec4(0.92, 0.88, 0.78, 1.0);
uniform vec4 line_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		float sand = texture(field_tex, SCREEN_UV).r;
		float amplitude = abs(plate_amplitude(SCREEN_UV, viewport_px.x / max(viewport_px.y, 1.0)));
		float ghost = (1.0 - smoothstep(0.0, 0.05, amplitude)) * drive * ghost_gain * live;
		result = mix(result, line_color.rgb, ghost);

		vec2 grain = floor(FRAGCOORD.xy / grain_px);
		float bounce = amplitude * drive > 0.22 ? floor(field_time * 24.0) : 0.0;
		float pick = grain_hash(grain + vec2(bounce * 17.0, bounce * 5.0));
		float coverage = 1.0 - exp(-sand * 0.22);
		float present = step(pick, coverage);
		float shade = 0.72 + 0.28 * grain_hash(grain * 1.37 + vec2(5.1, 2.3));
		vec3 grain_color = mix(sand_color.rgb, error_color.rgb, failure_tint * 0.7) * shade;
		result = mix(result, grain_color, present * sand_opacity * live);
	}
	COLOR = vec4(result, 1.0);
}
