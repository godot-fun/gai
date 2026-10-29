shader_type canvas_item;

// Sand grains drawn as small square cells over the live interface. The tag picks the hue: the
// accent rotated per tool, a pale grain for reasoning, and a dark grain for turn dividers. Wet
// grains darken toward the error color, and grains facing open air catch a highlight so the
// dunes read in relief.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_nearest;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform bool gravity_up = false;
uniform float hue_spread = 0.5;
uniform float sand_saturation = 0.7;
uniform float sand_opacity : hint_range(0.0, 1.0) = 0.82;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);
uniform vec4 pale_color : source_color = vec4(0.86, 0.82, 0.72, 1.0);
uniform vec4 divider_color : source_color = vec4(0.32, 0.29, 0.26, 1.0);

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

vec3 grain_color(float tag) {
	if (tag < 0.04) {
		return pale_color.rgb;
	}
	if (tag > 0.96) {
		return divider_color.rgb;
	}
	vec3 hsv = rgb_to_hsv(accent_color.rgb);
	hsv.x = fract(hsv.x + (tag - 0.5) * hue_spread);
	hsv.y *= sand_saturation;
	return hsv_to_rgb(hsv);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float live = smoothstep(0.0, 0.05, activity);
	vec3 result = source;
	if (live > 0.001) {
		ivec2 size = textureSize(field_tex, 0);
		ivec2 cell = clamp(ivec2(floor(SCREEN_UV * vec2(size))), ivec2(0), size - ivec2(1));
		vec4 s = texelFetch(field_tex, cell, 0);
		if (s.r > 0.5) {
			ivec2 above = cell + ivec2(0, gravity_up ? 1 : -1);
			bool open_above = above.y < 0 || above.y >= size.y || texelFetch(field_tex, above, 0).r < 0.5;
			float shade = 0.82 + 0.3 * s.a + (open_above ? 0.18 : 0.0);
			vec3 color = grain_color(s.g) * shade;
			color = mix(color, error_color.rgb * 0.8, clamp(s.b, 0.0, 1.0) * 0.75);
			color = mix(color, error_color.rgb, failure_tint * 0.35);
			result = mix(source, color, sand_opacity);
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
