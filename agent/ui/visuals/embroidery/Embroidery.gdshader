shader_type canvas_item;

// Linen weave laid over the live interface: alternating warp and weft threads with slubs and a
// faint grain, darkening the gaps between threads on light themes and catching light on the
// raised threads on dark ones. Zero presence is an identity pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;

const float THREAD_PX = 4.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 result = source;
	if (presence > 0.001) {
		vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
		float scale = max(viewport_px.y / 1440.0, 0.5);
		vec2 px = SCREEN_UV * viewport_px / (THREAD_PX * scale);
		vec2 cell = floor(px);
		vec2 f = fract(px);
		// Over-under: even cells show the warp on top, odd cells the weft.
		bool warp_on_top = mod(cell.x + cell.y, 2.0) < 1.0;
		float across = warp_on_top ? f.x : f.y;
		float along = warp_on_top ? f.y : f.x;
		float thread_profile = sin(across * PI);
		float gap = 1.0 - smoothstep(0.0, 0.35, thread_profile);
		float slub = hash12(warp_on_top ? vec2(cell.x, floor(cell.y / 7.0)) : vec2(floor(cell.x / 7.0), cell.y) + 31.0);
		float sheen = thread_profile * (0.6 + 0.4 * sin(along * PI)) * (0.7 + 0.6 * slub);
		if (light_mode > 0.5) {
			result = source * (1.0 - gap * 0.09 - (1.0 - sheen) * 0.035);
			result = mix(result, result * vec3(1.0, 0.985, 0.95), 0.6);
		} else {
			result = source * (1.0 - gap * 0.18) + vec3(sheen * 0.03);
		}
		result = mix(source, result, presence);
	}
	COLOR = vec4(result, 1.0);
}
