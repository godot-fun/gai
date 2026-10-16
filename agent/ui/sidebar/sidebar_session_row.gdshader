shader_type canvas_item;
render_mode blend_mix;

uniform vec4 accent_color : source_color = vec4(0.0, 0.84, 0.68, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float corner_radius : hint_range(0.0, 32.0) = 6.0;
uniform vec2 rect_size = vec2(240.0, 36.0);
uniform float scan_speed : hint_range(0.0, 4.0) = 1.4;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.4;
uniform float is_dark : hint_range(0.0, 1.0) = 1.0;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_sz = max(rect_size * 0.5 - vec2(0.5), vec2(1.0));
	float r = min(corner_radius, min(half_sz.x, half_sz.y));
	vec2 p = (UV - 0.5) * rect_size;
	float d = sd_rounded_box(p, half_sz, r);
	float mask = 1.0 - smoothstep(0.0, 1.25, d);
	COLOR = vec4(0.0);
	if (mask * strength > 0.001) {
		vec3 rgb = vec3(0.0);
		float alpha = 0.0;
		float visibility = mix(1.0, 1.65, is_dark);

		float px = UV.x * rect_size.x;
		float py = UV.y * rect_size.y;

		// Horizontal scan lines
		float scan_wave = sin(py * 1.45 + TIME * scan_speed * 6.28318);
		float scan_shade = 0.045 * visibility * (0.5 + 0.5 * scan_wave);
		vec3 scan_tint = mix(vec3(0.0), accent_color.rgb, 0.35);
		rgb += scan_tint * scan_shade;
		alpha = max(alpha, scan_shade * 0.85);

		// Data shimmer grid
		float grid = sin(px * 0.11 + TIME * 2.6) * sin(py * 0.08 - TIME * 1.9);
		rgb += accent_color.rgb * grid * 0.018 * visibility;
		alpha = max(alpha, abs(grid) * 0.04 * visibility);

		// Left energy rail + soft bleed
		float rail_w = 4.0;
		float rail = smoothstep(rail_w + 2.0, 0.0, px);
		float pulse = 0.68 + 0.32 * sin(TIME * pulse_speed);
		vec3 rail_rgb = accent_color.rgb * (1.1 + 0.35 * sin(TIME * pulse_speed * 1.6));
		rgb = mix(rgb, rail_rgb, rail * 0.92);
		alpha = max(alpha, rail * mix(0.55, 0.78, is_dark) * pulse);

		float bleed = exp(-px * 0.055) * 0.14 * visibility * pulse;
		rgb += accent_color.rgb * bleed;
		alpha = max(alpha, bleed * 0.35);

		// Traveling sweep along the top edge
		float sweep_pos = fract(TIME * 0.22);
		float sweep_band = smoothstep(0.14, 0.0, abs(UV.x - sweep_pos));
		float top_band = smoothstep(0.12, 0.0, UV.y);
		float sweep = sweep_band * top_band * 0.42 * visibility;
		rgb += accent_color.rgb * sweep;
		alpha = max(alpha, sweep * 0.5);

		// Rounded border glow
		float border = 1.0 - smoothstep(0.0, 1.35, abs(d));
		float border_pulse = 0.55 + 0.45 * sin(TIME * 1.35 + px * 0.04);
		rgb += accent_color.rgb * border * 0.07 * visibility * border_pulse;
		alpha = max(alpha, border * mix(0.12, 0.24, is_dark) * border_pulse);

		// Corner brackets (HUD)
		float bracket_len = min(rect_size.x, rect_size.y) * 0.22;
		float corner_x = min(px, rect_size.x - px);
		float corner_y = min(py, rect_size.y - py);
		float bracket = 0.0;
		if (corner_x < bracket_len && corner_y < 1.8) {
			bracket = smoothstep(1.8, 0.0, corner_y);
		}
		if (corner_y < bracket_len && corner_x < 1.8) {
			bracket = max(bracket, smoothstep(1.8, 0.0, corner_x));
		}
		rgb += accent_color.rgb * bracket * 0.22 * visibility;
		alpha = max(alpha, bracket * mix(0.18, 0.32, is_dark));

		alpha *= mask * strength;
		COLOR = vec4(rgb, alpha);
	}
}
