shader_type canvas_item;

// Two distant transcript entries become adjacent without changing the actual Control layout.
// A piecewise inverse map folds the intervening screen space into one curved crease.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 upper_anchor_rect = vec4(0.2, 0.24, 0.7, 0.10);
uniform vec4 lower_anchor_rect = vec4(0.2, 0.72, 0.7, 0.10);
uniform vec4 chat_area_rect = vec4(0.14, 0.04, 0.86, 0.96);
uniform float anchors_enabled = 0.0;
uniform vec4 sidebar_upper_anchor_rect = vec4(0.0, 0.16, 0.13, 0.04);
uniform vec4 sidebar_lower_anchor_rect = vec4(0.0, 0.82, 0.13, 0.04);
uniform vec4 sidebar_area_rect = vec4(0.0, 0.04, 0.13, 0.96);
uniform float sidebar_enabled = 0.0;
uniform float sidebar_fold_strength : hint_range(0.0, 1.0) = 0.62;
uniform float fold_amount : hint_range(0.0, 1.0) = 0.0;
uniform float fold_phase = 0.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float inverse_piecewise_map(float output_y, float area_top, float area_bottom, float source_top, float source_bottom, float destination_top, float destination_bottom) {
	if (output_y < destination_top) {
		float progress = (output_y - area_top) / max(destination_top - area_top, 0.0001);
		return mix(area_top, source_top, clamp(progress, 0.0, 1.0));
	}
	if (output_y < destination_bottom) {
		float progress = (output_y - destination_top) / max(destination_bottom - destination_top, 0.0001);
		return mix(source_top, source_bottom, clamp(progress, 0.0, 1.0));
	}
	float progress = (output_y - destination_bottom) / max(area_bottom - destination_bottom, 0.0001);
	return mix(source_bottom, area_bottom, clamp(progress, 0.0, 1.0));
}

float region_column_mask(vec2 uv, vec4 area_rect, vec2 pixel_size) {
	float column_left = area_rect.x;
	float column_right = area_rect.x + area_rect.z;
	float feather = pixel_size.x * 18.0;
	return smoothstep(column_left - feather, column_left + feather, uv.x)
		* (1.0 - smoothstep(column_right - feather, column_right + feather, uv.x));
}

float region_vertical_mask(vec2 uv, vec4 area_rect, vec2 pixel_size) {
	float feather = pixel_size.y * 8.0;
	return smoothstep(area_rect.y, area_rect.y + feather, uv.y)
		* (1.0 - smoothstep(area_rect.y + area_rect.w - feather, area_rect.y + area_rect.w, uv.y));
}

float region_curved_sheet(vec2 uv, vec4 area_rect) {
	float column_local = clamp((uv.x - area_rect.x) / max(area_rect.z, 0.0001), 0.0, 1.0);
	return pow(max(sin(column_local * 3.14159265), 0.0), 0.55);
}

float region_active_fold(vec2 uv, vec4 area_rect, float amount, float enabled, vec2 pixel_size) {
	float column_mask = region_column_mask(uv, area_rect, pixel_size);
	float curved_sheet = region_curved_sheet(uv, area_rect);
	return amount * enabled * column_mask * (0.76 + curved_sheet * 0.24);
}

vec2 folded_uv_for_region(vec2 uv, vec4 upper_rect, vec4 lower_rect, vec4 area_rect, float amount, float phase, float enabled, vec2 pixel_size) {
	float source_top = upper_rect.y + upper_rect.w * 0.5;
	float source_bottom = lower_rect.y + lower_rect.w * 0.5;
	float source_gap = max(source_bottom - source_top, pixel_size.y);
	float column_local = clamp((uv.x - area_rect.x) / max(area_rect.z, 0.0001), 0.0, 1.0);
	float curved_sheet = region_curved_sheet(uv, area_rect);
	float active_fold = region_active_fold(uv, area_rect, amount, enabled, pixel_size);
	float touching_gap = upper_rect.w * 0.5 + lower_rect.w * 0.5 + pixel_size.y * 7.0;
	float destination_gap = mix(source_gap, min(source_gap, touching_gap), active_fold);
	float midpoint = (source_top + source_bottom) * 0.5;
	float destination_top = midpoint - destination_gap * 0.5;
	float destination_bottom = midpoint + destination_gap * 0.5;
	float sample_y = inverse_piecewise_map(uv.y, area_rect.y, area_rect.y + area_rect.w, source_top, source_bottom, destination_top, destination_bottom);

	float crease_radius = max(touching_gap * 0.78, pixel_size.y * 24.0);
	float crease_influence = exp(-abs(uv.y - midpoint) / max(crease_radius, 0.0001));
	float phase_breath = sin(phase + column_local * 3.14159265) * 0.0018 * active_fold;
	float sample_x = uv.x + (0.5 - column_local) * crease_influence * active_fold * 0.018 + phase_breath;
	return clamp(vec2(sample_x, sample_y), vec2(0.0), vec2(1.0));
}

vec2 crease_tone(vec2 uv, vec4 upper_rect, vec4 lower_rect, vec4 area_rect, float amount, float enabled, vec2 pixel_size) {
	float midpoint = (upper_rect.y + upper_rect.w * 0.5 + lower_rect.y + lower_rect.w * 0.5) * 0.5;
	float crease_distance_px = abs(uv.y - midpoint) / pixel_size.y;
	float curved_sheet = region_curved_sheet(uv, area_rect) * region_column_mask(uv, area_rect, pixel_size);
	float highlight = exp(-crease_distance_px * 0.42) * curved_sheet * amount * enabled;
	float shadow = exp(-crease_distance_px * 0.075) * curved_sheet * amount * enabled;
	return vec2(highlight, shadow);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float chat_active = region_active_fold(SCREEN_UV, chat_area_rect, fold_amount, anchors_enabled, SCREEN_PIXEL_SIZE);
	float sidebar_amount = smoothstep(0.0, 0.92, fold_amount) * sidebar_fold_strength;
	float sidebar_active = region_active_fold(SCREEN_UV, sidebar_area_rect, sidebar_amount, sidebar_enabled, SCREEN_PIXEL_SIZE);
	vec2 chat_uv = folded_uv_for_region(SCREEN_UV, upper_anchor_rect, lower_anchor_rect, chat_area_rect, fold_amount, fold_phase, anchors_enabled, SCREEN_PIXEL_SIZE);
	vec2 sidebar_uv = folded_uv_for_region(SCREEN_UV, sidebar_upper_anchor_rect, sidebar_lower_anchor_rect, sidebar_area_rect, sidebar_amount, fold_phase + 1.7, sidebar_enabled, SCREEN_PIXEL_SIZE);
	vec3 result = mix(source, texture(screen_texture, chat_uv).rgb, chat_active * region_vertical_mask(SCREEN_UV, chat_area_rect, SCREEN_PIXEL_SIZE));
	result = mix(result, texture(screen_texture, sidebar_uv).rgb, sidebar_active * region_vertical_mask(SCREEN_UV, sidebar_area_rect, SCREEN_PIXEL_SIZE));

	vec2 chat_crease = crease_tone(SCREEN_UV, upper_anchor_rect, lower_anchor_rect, chat_area_rect, fold_amount, anchors_enabled, SCREEN_PIXEL_SIZE);
	vec2 sidebar_crease = crease_tone(SCREEN_UV, sidebar_upper_anchor_rect, sidebar_lower_anchor_rect, sidebar_area_rect, sidebar_amount, sidebar_enabled, SCREEN_PIXEL_SIZE);
	float crease_line = clamp(chat_crease.x + sidebar_crease.x, 0.0, 1.0);
	float crease_shadow = clamp(chat_crease.y + sidebar_crease.y, 0.0, 1.0);
	result *= 1.0 - crease_shadow * 0.075;
	result = mix(result, accent_color.rgb, crease_line * 0.10);
	COLOR = vec4(result, 1.0);
}
