shader_type canvas_item;

// Mandelbrot set over the live interface. Escaping points near the set glow along its filaments
// (distance estimate) and carry smooth iteration bands around the accent hue; far-away points
// stay clear so the interface shows through. The set's interior is a faint tinted silhouette.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(-0.6, 0.0);
// Half of the viewport height in the complex plane.
uniform float scale = 1.25;
uniform float rotation = 0.0;
uniform int max_iterations = 120;
uniform float palette_phase = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);

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
	vec3 result = source;
	if (presence > 0.001) {
		float aspect = viewport_px.x / viewport_px.y;
		vec2 q = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 2.0 * scale;
		float cs = cos(rotation);
		float sn = sin(rotation);
		vec2 c = center + vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
		vec2 z = vec2(0.0);
		vec2 dz = vec2(0.0);
		int escaped_at = -1;
		for (int index = 0; index < 400; index++) {
			if (index >= max_iterations) {
				break;
			}
			dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x) + vec2(1.0, 0.0);
			z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
			if (dot(z, z) > 1024.0) {
				escaped_at = index;
				break;
			}
		}
		vec3 accent_hsv = rgb_to_hsv(accent_color.rgb);
		float alpha;
		vec3 color;
		if (escaped_at < 0) {
			color = light_mode > 0.5 ? accent_color.rgb * 0.5 : vec3(0.0);
			alpha = light_mode > 0.5 ? 0.08 : 0.22;
		} else {
			float mag = length(z);
			float smooth_n = float(escaped_at) + 1.0 - log2(max(log(mag), 1e-6));
			float distance_estimate = 0.5 * mag * log(mag) / max(length(dz), 1e-12);
			float pixel_size = 2.0 * scale / viewport_px.y;
			float filament = exp(-distance_estimate / (pixel_size * 2.2));
			float band = smooth_n * 0.045 + palette_phase;
			vec3 hsv = vec3(fract(accent_hsv.x + 0.16 * sin(band * TAU)), clamp(max(accent_hsv.y, 0.55) + 0.2 * cos(band * TAU * 0.5), 0.0, 1.0), light_mode > 0.5 ? 0.6 : 1.0);
			color = hsv_to_rgb(hsv);
			float depth = pow(clamp(smooth_n / float(max_iterations), 0.0, 1.0), 0.55);
			float halo = smoothstep(0.08, 0.55, depth) * 0.45;
			alpha = clamp(filament * (0.85 + pulse * 0.15) + halo, 0.0, 0.92);
			if (light_mode < 0.5) {
				color = mix(color, vec3(1.0), filament * 0.35 + pulse * 0.25);
			}
		}
		color = mix(color, error_color.rgb, failure_tint * 0.6);
		result = mix(source, color, alpha * presence);
	}
	COLOR = vec4(result, 1.0);
}
