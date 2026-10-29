shader_type canvas_item;

// Screen-space material separation. Masks are reconstructed from the current frame so the effect
// does not need persistent feedback and returns pixel-identically to the source at rest.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float layer_separation : hint_range(0.0, 1.0) = 0.0;
uniform float parallax_phase = 0.0;
uniform float parallax_direction = 1.0;
uniform float max_separation_px : hint_range(0.0, 64.0) = 34.0;
uniform float toolbar_height_px = 0.0;
uniform vec4 focus_rect = vec4(0.18, 0.58, 0.78, 0.12);
uniform float focus_enabled = 0.0;
uniform vec4 chat_area_rect = vec4(0.14, 0.04, 0.86, 0.96);
uniform float chat_area_enabled = 0.0;
uniform vec4 effect_area_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.1, 0.8, 0.7, 1.0);
uniform float top_separation_boost : hint_range(1.0, 2.0) = 1.5;
uniform float vertical_falloff_power : hint_range(0.25, 2.0) = 0.9;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float edge_strength(vec2 uv, vec2 pixel_size) {
	vec3 left = texture(screen_texture, clamp(uv - vec2(pixel_size.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 right = texture(screen_texture, clamp(uv + vec2(pixel_size.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 up = texture(screen_texture, clamp(uv - vec2(0.0, pixel_size.y), vec2(0.0), vec2(1.0))).rgb;
	vec3 down = texture(screen_texture, clamp(uv + vec2(0.0, pixel_size.y), vec2(0.0), vec2(1.0))).rgb;
	return clamp(length(right - left) * 1.45 + length(down - up) * 1.45, 0.0, 1.0);
}

vec3 local_surface(vec2 uv, vec2 pixel_size) {
	vec2 spread = pixel_size * 7.0;
	vec3 horizontal = texture(screen_texture, clamp(uv - vec2(spread.x, 0.0), vec2(0.0), vec2(1.0))).rgb
		+ texture(screen_texture, clamp(uv + vec2(spread.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 vertical = texture(screen_texture, clamp(uv - vec2(0.0, spread.y), vec2(0.0), vec2(1.0))).rgb
		+ texture(screen_texture, clamp(uv + vec2(0.0, spread.y), vec2(0.0), vec2(1.0))).rgb;
	return (horizontal + vertical) * 0.25;
}

vec3 layer_masks(vec2 uv, vec2 pixel_size) {
	vec3 color = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float edge = edge_strength(uv, pixel_size);
	float light = luminance(color);
	float saturation = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
	float accent_distance = distance(color, accent_color.rgb);
	float accent = (1.0 - smoothstep(0.10, 0.62, accent_distance)) * (0.34 + edge * 0.66);
	accent = max(accent, saturation * edge * 0.72);
	float highlight = edge * smoothstep(0.62, 0.96, light);
	float text = edge * (1.0 - accent * 0.58) * (1.0 - highlight * 0.35);
	return clamp(vec3(text, accent, highlight), vec3(0.0), vec3(1.0));
}

float area_mask(vec2 uv, vec4 rect, vec2 pixel_size) {
	vec2 feather = pixel_size * 10.0;
	float horizontal = smoothstep(rect.x, rect.x + feather.x, uv.x)
		* (1.0 - smoothstep(rect.x + rect.z - feather.x, rect.x + rect.z, uv.x));
	float vertical = smoothstep(rect.y, rect.y + feather.y, uv.y)
		* (1.0 - smoothstep(rect.y + rect.w - feather.y, rect.y + rect.w, uv.y));
	return horizontal * vertical;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float effect_area = area_mask(SCREEN_UV, effect_area_rect, SCREEN_PIXEL_SIZE);
	float chat_area = area_mask(SCREEN_UV, chat_area_rect, SCREEN_PIXEL_SIZE) * chat_area_enabled;
	float effect_top = effect_area_rect.y;
	float fallback_stable_start = effect_area_rect.y + effect_area_rect.w * 0.88;
	float stable_start = mix(fallback_stable_start, focus_rect.y, focus_enabled);
	stable_start = max(stable_start, effect_top + SCREEN_PIXEL_SIZE.y);
	float vertical_progress = clamp((SCREEN_UV.y - effect_top) / (stable_start - effect_top), 0.0, 1.0);
	float vertical_gradient = pow(1.0 - vertical_progress, vertical_falloff_power);
	float region_scale = mix(0.55, 1.0, chat_area);
	float motion_strength = vertical_gradient * region_scale * top_separation_boost;
	float active = clamp(layer_separation * effect_area * motion_strength, 0.0, 1.0);
	float breathing = sin(parallax_phase * 0.86) * 0.10;
	vec2 direction = normalize(vec2(0.86 + breathing, -0.52 + breathing * 0.35)) * parallax_direction;
	vec2 perpendicular = vec2(-direction.y, direction.x);
	vec2 max_offset = max_separation_px * SCREEN_PIXEL_SIZE * layer_separation * effect_area * motion_strength;

	vec2 panel_uv = clamp(SCREEN_UV + direction * max_offset * 0.10, vec2(0.0), vec2(1.0));
	vec3 result = mix(source, texture(screen_texture, panel_uv).rgb, active * 0.16);
	vec3 origin_masks = layer_masks(SCREEN_UV, SCREEN_PIXEL_SIZE);
	float origin_detail = clamp(origin_masks.x + origin_masks.y + origin_masks.z, 0.0, 1.0);
	result = mix(result, local_surface(SCREEN_UV, SCREEN_PIXEL_SIZE), origin_detail * active * 0.58);

	vec2 text_uv = clamp(SCREEN_UV - direction * max_offset * 0.76, vec2(0.0), vec2(1.0));
	vec2 accent_uv = clamp(SCREEN_UV + direction * max_offset * 0.48 - perpendicular * max_offset * 0.34, vec2(0.0), vec2(1.0));
	vec2 highlight_uv = clamp(SCREEN_UV - direction * max_offset * 1.14 - perpendicular * max_offset * 0.26, vec2(0.0), vec2(1.0));
	vec3 text_masks = layer_masks(text_uv, SCREEN_PIXEL_SIZE);
	vec3 accent_masks = layer_masks(accent_uv, SCREEN_PIXEL_SIZE);
	vec3 highlight_masks = layer_masks(highlight_uv, SCREEN_PIXEL_SIZE);

	float cast_shadow = clamp(text_masks.x * 0.55 + accent_masks.y * 0.42 + highlight_masks.z * 0.30, 0.0, 1.0);
	result *= 1.0 - cast_shadow * active * 0.12;
	result = mix(result, texture(screen_texture, text_uv).rgb, text_masks.x * active * 0.92);
	result = mix(result, texture(screen_texture, accent_uv).rgb, accent_masks.y * active * 0.90);
	result = mix(result, texture(screen_texture, highlight_uv).rgb, highlight_masks.z * active * 0.88);

	float exposed_edge = clamp(text_masks.x + accent_masks.y + highlight_masks.z, 0.0, 1.0);
	result = mix(result, accent_color.rgb, exposed_edge * active * 0.025);
	COLOR = vec4(result, 1.0);
}
