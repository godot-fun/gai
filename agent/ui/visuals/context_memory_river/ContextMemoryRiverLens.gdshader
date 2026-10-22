shader_type canvas_item;
render_mode blend_mix;

uniform vec2 lens_center_px;
uniform vec2 viewport_size;
uniform float ring_radius = 36.0;
uniform float ring_radius_close = 30.0;
uniform float lens_close = 0.0;
uniform vec4 border_color : source_color = vec4(0.72, 0.74, 0.78, 0.34);
uniform vec4 pulse_color : source_color = vec4(0.15, 0.8, 1.0, 1.0);

float soft_ring(float dist, float radius, float width) {
	return exp(-abs(dist - radius) / max(width, 0.001));
}

void fragment() {
	vec2 p = UV * viewport_size - lens_center_px;
	float dist = length(p);
	float close_eased = smoothstep(0.0, 1.0, lens_close);
	float lens_alpha = 1.0 - close_eased;
	float gauge_r = mix(ring_radius, ring_radius_close, close_eased);

	vec3 color = vec3(0.0);
	float alpha = 0.0;

	float border = soft_ring(dist, gauge_r, 0.52);
	color += border_color.rgb * border * border_color.a * lens_alpha;
	alpha = max(alpha, border * border_color.a * lens_alpha);

	if (lens_close > 0.001) {
		float wave_r = mix(ring_radius, ring_radius + 30.0, close_eased);
		float wave = soft_ring(dist, wave_r, 1.6);
		float wave_a = sin(close_eased * 3.14159265) * 0.11 * lens_alpha;
		color += pulse_color.rgb * wave * wave_a;
		alpha = max(alpha, wave * wave_a);
	}

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
