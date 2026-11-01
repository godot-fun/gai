shader_type canvas_item;
render_mode blend_mix;

uniform vec2 lens_center_px;
uniform vec2 viewport_size;
uniform float ring_radius = 36.0;
uniform float ring_radius_close = 30.0;
uniform float lens_close = 0.0;
uniform float context_usage = 0.0;
uniform float flow_activity = 0.0;
uniform vec4 border_color : source_color = vec4(0.72, 0.74, 0.78, 0.34);
uniform vec4 pulse_color : source_color = vec4(0.15, 0.8, 1.0, 1.0);

float soft_ring(float dist, float radius, float width) {
	return exp(-abs(dist - radius) / max(width, 0.001));
}

float angular_arc(float angle, float offset, float segments, float fill, float feather) {
	float cell = fract(angle / 6.2831853 * segments + offset);
	return 1.0 - smoothstep(fill - feather, fill + feather, cell);
}

void fragment() {
	vec2 p = UV * viewport_size - lens_center_px;
	float dist = length(p);
	float close_eased = smoothstep(0.0, 1.0, lens_close);
	float lens_alpha = 1.0 - close_eased;
	float gauge_r = mix(ring_radius, ring_radius_close, close_eased);
	float angle = atan(p.y, p.x);
	float activity = clamp(flow_activity, 0.0, 1.0);
	float usage = clamp(context_usage, 0.0, 1.0);
	float speed = mix(0.075, 0.19, max(activity, usage));
	float breath = 0.5 + 0.5 * sin(TIME * mix(1.35, 2.35, usage));

	// A broad, quiet aura keeps the lens present even before the first packet arrives.
	float outer_halo = soft_ring(dist, gauge_r + 1.5, 9.0) * (0.10 + breath * 0.08);
	float inner_halo = (1.0 - smoothstep(gauge_r - 12.0, gauge_r, dist)) * (0.045 + breath * 0.025);

	// Broken counter-rotating tracks make the ring read as a live context processor.
	float track = soft_ring(dist, gauge_r, 1.35);
	float clockwise = angular_arc(angle, TIME * speed, 3.0, 0.58, 0.055);
	float counter = angular_arc(-angle, TIME * speed * 0.72 + 0.31, 5.0, 0.18, 0.035);
	float energy_arcs = track * max(clockwise * 0.92, counter * (0.68 + activity * 0.28));
	float rim = soft_ring(dist, gauge_r, 0.72) * max(border_color.a, 0.52);
	float outer_track = soft_ring(dist, gauge_r + 5.0, 0.72) * angular_arc(-angle, TIME * speed * 0.45, 4.0, 0.11, 0.04);
	float inner_track = soft_ring(dist, gauge_r - 5.0, 0.62) * angular_arc(angle, TIME * speed * 0.62 + 0.5, 3.0, 0.16, 0.045);

	// Two orbiting nodes give the motion a clear focal point at a glance.
	vec2 orbit_a = vec2(cos(TIME * 0.95), sin(TIME * 0.95)) * (gauge_r + 5.0);
	vec2 orbit_b = vec2(cos(-TIME * 0.68 + 3.14159265), sin(-TIME * 0.68 + 3.14159265)) * (gauge_r - 5.0);
	float orbit_nodes = exp(-length(p - orbit_a) / 2.6) * 0.72 + exp(-length(p - orbit_b) / 2.2) * 0.58;

	// A faint travelling scan escapes the rim periodically without waiting for input.
	float scan_phase = fract(TIME * 0.16 + angle / 6.2831853);
	float scan_radius = gauge_r + 2.0 + scan_phase * 9.0;
	float scan = soft_ring(dist, scan_radius, 1.8) * (1.0 - scan_phase) * 0.16;

	float base_alpha = outer_halo + inner_halo + rim + energy_arcs * (0.46 + usage * 0.22) + (outer_track + inner_track) * 0.46 + orbit_nodes + scan;
	float accent_mix = energy_arcs * 0.82 + (outer_track + inner_track) * 0.75 + orbit_nodes + scan * 3.5 + usage * 0.18;
	vec3 base_color = mix(border_color.rgb, pulse_color.rgb, clamp(accent_mix, 0.08, 0.88));
	float alpha = base_alpha * lens_alpha;
	vec3 color = base_color;

	if (lens_close > 0.001) {
		float wave_r = mix(ring_radius, ring_radius + 30.0, close_eased);
		float wave = soft_ring(dist, wave_r, 1.6);
		float wave_a = sin(close_eased * 3.14159265) * 0.11 * lens_alpha;
		float combined_alpha = max(alpha, wave * wave_a);
		color = mix(color, pulse_color.rgb, wave * 0.75);
		alpha = combined_alpha;
	}

	COLOR = vec4(color, clamp(alpha, 0.0, 0.94));
}
