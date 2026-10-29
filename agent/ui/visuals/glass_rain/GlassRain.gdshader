shader_type canvas_item;

// The live interface behind a rainy window. Fog frosts (blurs and veils) the screen, wet trails
// and drops stay clear, and each drop is a small lens with a dark rim and a glint.
// Lightning flashes the pane. Light themes read as daylight glass: the fog is a cool grey veil
// darker than paper, beads are shaded from the light and cast a soft shadow onto the pane, and
// lightning bleaches the fog. Zero activity or an empty field is an identity pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float lightning : hint_range(0.0, 1.0) = 0.0;
uniform float lens_px = 120.0;
uniform float fog_blur = 2.6;
uniform float fog_veil : hint_range(0.0, 1.0) = 0.28;
uniform float glint_gain : hint_range(0.0, 1.0) = 1.0;
uniform float rim_shade : hint_range(0.0, 1.0) = 0.12;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_px = 7.0;
uniform vec4 fog_color : source_color = vec4(0.6, 0.65, 0.72, 1.0);
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

// Four taps soften the coarse field; the square root turns water mass into a domed bead.
float drop_height(vec2 uv, vec2 cell) {
	vec2 h = cell * 0.75;
	float water = texture(field_tex, uv + vec2(-h.x, -h.y)).r + texture(field_tex, uv + vec2(h.x, -h.y)).r
		+ texture(field_tex, uv + vec2(-h.x, h.y)).r + texture(field_tex, uv + vec2(h.x, h.y)).r;
	return sqrt(clamp(water * 0.25 * 2.2, 0.0, 1.0));
}

void fragment() {
	vec3 source = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec2 cell = vec2(1.0) / vec2(textureSize(field_tex, 0));
		vec4 field = texture(field_tex, SCREEN_UV);
		float drop = smoothstep(0.2, 0.5, drop_height(SCREEN_UV, cell));
		vec2 slope = vec2(drop_height(SCREEN_UV + vec2(cell.x, 0.0), cell) - drop_height(SCREEN_UV - vec2(cell.x, 0.0), cell),
			drop_height(SCREEN_UV + vec2(0.0, cell.y), cell) - drop_height(SCREEN_UV - vec2(0.0, cell.y), cell));
		vec2 lens = -slope * lens_px * SCREEN_PIXEL_SIZE;
		float fog = field.g * (1.0 - drop);
		vec3 seen = textureLod(screen_texture, clamp(SCREEN_UV + lens, vec2(0.0), vec2(1.0)), fog * fog_blur).rgb;
		seen = mix(seen, fog_color.rgb, fog * fog_veil);

		float rim = clamp(length(slope) * 1.2, 0.0, 1.0) * drop;
		vec3 normal = normalize(vec3(-slope * 2.6, 1.0));
		vec3 light_dir = normalize(vec3(-0.5, -0.65, 0.58));
		float glint = pow(max(dot(normal, light_dir), 0.0), 14.0) - pow(light_dir.z, 14.0);
		vec3 tint = mix(accent_color.rgb, error_color.rgb, failure_tint);
		if (light_mode > 0.5) {
			vec2 shadow_uv = SCREEN_UV - vec2(0.6, 1.0) * shadow_px * SCREEN_PIXEL_SIZE;
			float shadow = smoothstep(0.15, 0.6, drop_height(shadow_uv, cell * 1.8)) * (1.0 - drop);
			seen *= 1.0 - shadow * 0.16;
			float lambert = dot(normal, light_dir) - light_dir.z;
			float body_shade = smoothstep(0.0, 0.45, -lambert) * drop;
			seen = mix(seen, seen * mix(vec3(0.62, 0.68, 0.76), tint, 0.25), body_shade * rim_shade);
			seen = mix(seen, vec3(1.0), clamp(glint, 0.0, 1.0) * drop * glint_gain);
			seen = mix(seen, vec3(1.0), lightning * fog * 0.85);
		} else {
			seen *= 1.0 - rim * rim_shade;
			seen += (fog_color.rgb * 0.5 + 0.08) * drop * (1.0 - rim) * 0.18;
			seen += mix(vec3(1.0), tint, 0.4) * clamp(glint, 0.0, 1.0) * drop * 0.8 * glint_gain;
			seen += vec3(0.82, 0.88, 1.0) * lightning * 0.42;
		}
		result = mix(source, seen, live);
	}
	COLOR = vec4(result, 1.0);
}
