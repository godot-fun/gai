shader_type canvas_item;

// Doom fire drawn as crisp pixels over the live interface. Heat is quantized to the 37 steps of
// the original palette (black, deep red, red, orange, yellow, white); cold cells stay clear.
// Embers float up above the flames. A failed tool cools the palette toward the error color.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_nearest;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float ember_rate : hint_range(0.0, 1.0) = 0.0;
uniform vec4 error_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);

const float LEVELS = 36.0;

vec3 fire_palette(float heat) {
	vec3 color = mix(vec3(0.03, 0.01, 0.01), vec3(0.45, 0.04, 0.02), smoothstep(0.0, 0.2, heat));
	color = mix(color, vec3(0.86, 0.16, 0.03), smoothstep(0.2, 0.45, heat));
	color = mix(color, vec3(1.0, 0.52, 0.07), smoothstep(0.45, 0.68, heat));
	color = mix(color, vec3(1.0, 0.84, 0.24), smoothstep(0.68, 0.88, heat));
	return mix(color, vec3(1.0, 0.98, 0.88), smoothstep(0.88, 1.0, heat));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.05, activity);
	vec3 result = source;
	if (live > 0.001) {
		float heat = texture(field_tex, SCREEN_UV).r;
		float level = floor(heat * LEVELS + 0.5) / LEVELS;
		vec3 color = fire_palette(level);
		color = mix(color, error_color.rgb * (0.4 + level * 0.8), failure_tint * 0.65);
		float alpha = smoothstep(0.02, light_mode > 0.5 ? 0.34 : 0.26, level);
		result = mix(source, color, alpha);
		if (light_mode < 0.5) {
			result += color * smoothstep(0.55, 1.0, level) * 0.2;
		}
		if (ember_rate > 0.001) {
			vec2 grid_uv = vec2(SCREEN_UV.x * viewport_px.x / viewport_px.y, SCREEN_UV.y) * 70.0;
			float column = floor(grid_uv.x);
			float rise = field_time * (3.0 + hash12(vec2(column, 3.0)) * 5.0);
			vec2 ember_cell = vec2(column, floor(grid_uv.y + rise));
			float pick = hash12(ember_cell);
			vec2 local = fract(vec2(grid_uv.x, grid_uv.y + rise)) - 0.5;
			local.x += sin(field_time * 2.0 + pick * 30.0) * 0.25;
			float spark = (1.0 - smoothstep(0.05, 0.12, length(local))) * step(pick, 0.035 * ember_rate);
			float height_fade = smoothstep(0.25, 0.85, SCREEN_UV.y);
			vec3 ember = mix(vec3(1.0, 0.62, 0.18), error_color.rgb, failure_tint * 0.65);
			result = mix(result, ember, spark * height_fade * 0.9);
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
