shader_type canvas_item;

// Life cells drawn as small rounded squares over the live interface. Living cells take the
// accent hue rotated by their species tag; dead cells leave a fading afterglow. Tag 1 marks
// cells born from a failed tool and paints them in the error color.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_nearest;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float hue_spread = 0.42;
uniform float cell_opacity : hint_range(0.0, 1.0) = 0.86;
uniform float trail_opacity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.05, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec2 field_size = vec2(textureSize(field_tex, 0));
		vec2 cell_pos = SCREEN_UV * field_size;
		vec2 local = fract(cell_pos) - 0.5;
		vec4 s = texture(field_tex, (floor(cell_pos) + 0.5) / field_size);
		float edge = max(abs(local.x), abs(local.y));
		float square = 1.0 - smoothstep(0.34, 0.42, edge);
		vec3 hsv = rgb_to_hsv(accent_color.rgb);
		hsv.x = fract(hsv.x + (s.b - 0.5) * hue_spread);
		vec3 color = hsv_to_rgb(hsv);
		color = mix(color, error_color.rgb, max(step(0.97, s.b), failure_tint * 0.6));
		float alive_alpha = s.r * square * cell_opacity;
		float trail_alpha = s.g * (1.0 - s.r) * square * trail_opacity;
		if (light_mode > 0.5) {
			result = mix(result, color, alive_alpha + trail_alpha);
		} else {
			float core = 1.0 - smoothstep(0.0, 0.3, edge);
			result = mix(result, color, alive_alpha + trail_alpha);
			result += color * s.r * core * 0.35;
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
