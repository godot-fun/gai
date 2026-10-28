shader_type canvas_item;

// The void is deliberately opaque and surface-colored. Its surrounding displacement makes it
// read as a volume of missing layout rather than a lens, hole, or translucent overlay.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 void_center = vec2(0.72, 0.58);
uniform vec2 void_size = vec2(0.15, 0.09);
uniform float void_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 void_color : source_color = vec4(0.96, 0.96, 0.97, 1.0);
uniform vec4 accent_color : source_color = vec4(0.2, 0.7, 0.7, 1.0);
uniform vec4 effect_area_rect = vec4(0.0, 0.04, 1.0, 0.96);

float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 corner = abs(point) - half_size + radius;
	return length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
}

float area_mask(vec2 uv, vec4 area, vec2 pixel_size) {
	float feather = pixel_size.y * 8.0;
	return smoothstep(area.y, area.y + feather, uv.y)
		* (1.0 - smoothstep(area.y + area.w - feather, area.y + area.w, uv.y));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 half_size = max(void_size * 0.5, SCREEN_PIXEL_SIZE * 18.0);
	vec2 local = uv - void_center;
	float corner_radius = min(half_size.x, half_size.y) * 0.32;
	float signed_distance = rounded_box_distance(local, half_size, corner_radius);
	float inside = 1.0 - smoothstep(-SCREEN_PIXEL_SIZE.y * 2.0, SCREEN_PIXEL_SIZE.y * 6.0, signed_distance);
	float influence = 1.0 - smoothstep(0.0, max(half_size.x, half_size.y) * 1.35, max(signed_distance, 0.0));
	vec2 normalized_local = local / max(half_size, SCREEN_PIXEL_SIZE * 8.0);
	vec2 outward = normalize(normalized_local + vec2(0.0001, 0.0001));
	float squeeze = influence * influence * void_amount;
	vec2 source_uv = uv - outward * vec2(half_size.x * 0.62, half_size.y * 0.42) * squeeze;
	vec3 displaced = texture(screen_texture, clamp(source_uv, vec2(0.0), vec2(1.0))).rgb;
	float active_area = area_mask(uv, effect_area_rect, SCREEN_PIXEL_SIZE);
	vec3 result = mix(texture(screen_texture, uv).rgb, displaced, squeeze * active_area);
	float void_mask = inside * void_amount * active_area;
	result = mix(result, void_color.rgb, void_mask);
	float rim = exp(-abs(signed_distance) / max(SCREEN_PIXEL_SIZE.y * 3.0, 0.0001)) * void_amount * active_area;
	result = mix(result, accent_color.rgb, rim * 0.045);
	COLOR = vec4(result, 1.0);
}
