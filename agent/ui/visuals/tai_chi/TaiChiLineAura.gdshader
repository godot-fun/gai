shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float half_width_uv = 0.38;
uniform float opening_y_uv = 0.67;
uniform float yang_y_uv = 0.43;
uniform float yin_y_uv = 0.57;
uniform float yin_gap_uv = 0.0;
uniform float opening_progress : hint_range(0.0, 1.0) = 0.0;
uniform float duality_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool duality_active = false;
uniform vec4 aura_color : source_color = vec4(1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float flowing_aura(vec2 uv, float line_y, float extent, float gap, float seed) {
	float x_from_center = abs(uv.x - 0.5);
	float inside_extent = 1.0 - smoothstep(extent - 0.008, extent, x_from_center);
	float outside_gap = smoothstep(gap, gap + 0.008, x_from_center);
	float distance_px = abs(uv.y - line_y) * viewport_size.y;
	float soft_band = smoothstep(18.0, 2.0, distance_px) * smoothstep(0.6, 3.4, distance_px);
	float cell_noise = hash(floor(vec2(uv.x * viewport_size.x * 0.035 - TIME * 4.0, seed + uv.y * 23.0)));
	float current = 0.55 + 0.45 * sin(uv.x * viewport_size.x * 0.045 - TIME * 1.35 + seed);
	return inside_extent * outside_gap * soft_band * mix(current, cell_noise, 0.22);
}

void fragment() {
	float aura = 0.0;
	if (duality_active) {
		aura += flowing_aura(UV, yang_y_uv, half_width_uv, 0.0, 2.0);
		aura += flowing_aura(UV, yin_y_uv, half_width_uv, yin_gap_uv, 7.0);
		aura *= smoothstep(0.0, 0.34, duality_progress);
	} else {
		aura = flowing_aura(UV, opening_y_uv, half_width_uv * opening_progress, 0.0, 4.0);
		aura *= opening_progress;
	}
	COLOR = vec4(aura_color.rgb, aura * aura_color.a * 0.12);
}
