shader_type canvas_item;

// Darkroom display: the live interface as a monochrome print under a red safelight. Detail that
// stands furthest from the paper tone develops first; the developer surface refracts the print
// and catches the safelight in glints. A light leak fogs the paper from one point. As the lights
// come on the true-color interface returns. Zero activity or full lights is an identity pass.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
// 0 = safelight only, 1 = room lights on.
uniform float lights : hint_range(0.0, 1.0) = 1.0;
uniform float leak : hint_range(0.0, 1.0) = 0.0;
uniform vec2 leak_position = vec2(0.5, 0.5);
uniform float field_cell_px = 4.0;
uniform float refraction_px = 10.0;
uniform float exposure = 1.0;
uniform float grain_gain = 0.05;
uniform vec4 safelight_color : source_color = vec4(1.0, 0.24, 0.10, 1.0);
uniform vec4 paper_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 leak_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity) * (1.0 - lights);
	vec3 result = source;
	if (live > 0.001) {
		vec4 field = texture(field_tex, SCREEN_UV);
		vec2 step_uv = SCREEN_PIXEL_SIZE * field_cell_px;
		vec2 slope = vec2(
			texture(field_tex, SCREEN_UV + vec2(step_uv.x, 0.0)).g - texture(field_tex, SCREEN_UV - vec2(step_uv.x, 0.0)).g,
			texture(field_tex, SCREEN_UV + vec2(0.0, step_uv.y)).g - texture(field_tex, SCREEN_UV - vec2(0.0, step_uv.y)).g
		);
		vec2 print_uv = clamp(SCREEN_UV + slope * refraction_px * SCREEN_PIXEL_SIZE, vec2(0.0), vec2(1.0));
		vec3 ui = texture(screen_texture, print_uv).rgb;

		float paper = luma(paper_color.rgb);
		float tone = luma(ui);
		float appear = smoothstep(0.0, 1.0, field.r * (0.9 + 1.4 * abs(tone - paper)));
		float print_tone = mix(paper, tone, appear);
		float grain = (grain_hash(floor(FRAGCOORD.xy) + vec2(fract(field_time * 13.0) * 91.0)) - 0.5) * grain_gain;
		print_tone = clamp(print_tone + grain * (1.0 - 0.5 * appear), 0.0, 1.0);
		vec3 safelit = safelight_color.rgb * (0.06 + 0.94 * pow(print_tone, 0.8)) * exposure;
		// Highlights overexpose under the safelight toward warm white, which keeps text legible.
		safelit += vec3(0.42, 0.24, 0.16) * smoothstep(0.55, 0.95, print_tone) * appear * exposure;

		vec3 surface_normal = normalize(vec3(-slope * 24.0, 1.0));
		float glint = pow(clamp(dot(surface_normal, normalize(vec3(-0.35, -0.55, 0.75))), 0.0, 1.0), 90.0);
		safelit += (safelight_color.rgb * 0.7 + vec3(0.25)) * glint * 0.6;

		if (leak > 0.001) {
			vec2 view = vec2(viewport_px.x / max(viewport_px.y, 1.0), 1.0);
			vec2 delta = (SCREEN_UV - leak_position) * view;
			float fog = exp(-length(delta) * 3.2) * leak;
			float core = exp(-length(delta) * 14.0) * leak;
			float angle = atan(delta.y, delta.x);
			float rays = 0.55 + 0.45 * sin(angle * 7.0 + 1.3) * sin(angle * 3.0 - 0.7);
			float streak = exp(-abs(delta.y + delta.x * 0.35) * 22.0) * exp(-length(delta) * 1.2) * leak;
			safelit = mix(safelit, leak_color.rgb * 0.85, clamp(fog * rays, 0.0, 1.0));
			safelit += leak_color.rgb * streak * 0.45 + vec3(1.0, 0.92, 0.8) * core;
		}

		float vignette = smoothstep(1.15, 0.35, length((SCREEN_UV - vec2(0.5, 0.55)) * vec2(1.0, 1.2)));
		safelit *= mix(0.55, 1.0, vignette);
		result = mix(source, clamp(safelit, 0.0, 1.0), live);
	}
	float flash = sin(clamp(lights, 0.0, 1.0) * PI) * smoothstep(0.0, 0.02, activity);
	result += vec3(1.0, 0.9, 0.72) * flash * 0.12;
	COLOR = vec4(result, 1.0);
}
