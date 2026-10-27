shader_type canvas_item;

// A local screen-within-screen portal. The source frame is recursively remapped explicitly so the
// result does not depend on undefined same-frame feedback. At rest the application is unchanged.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 portal_rect_0_uv = vec4(0.30, 0.32, 0.40, 0.16);
uniform vec4 portal_rect_1_uv = vec4(0.30, 0.49, 0.40, 0.14);
uniform vec4 portal_rect_2_uv = vec4(0.30, 0.64, 0.40, 0.12);
uniform vec4 portal_rect_3_uv = vec4(0.30, 0.77, 0.40, 0.10);
uniform vec4 portal_rect_4_uv = vec4(0.30, 0.20, 0.40, 0.09);
uniform vec4 portal_rect_5_uv = vec4(0.30, 0.30, 0.40, 0.08);
uniform vec4 portal_rect_6_uv = vec4(0.30, 0.39, 0.40, 0.07);
uniform vec4 portal_rect_7_uv = vec4(0.30, 0.47, 0.40, 0.06);
uniform vec4 portal_enabled_near = vec4(0.0);
uniform vec4 portal_enabled_far = vec4(0.0);
uniform vec4 portal_strengths_near = vec4(1.0, 0.86, 0.73, 0.61);
uniform vec4 portal_strengths_far = vec4(0.50, 0.40, 0.31, 0.23);
uniform float recursion_energy : hint_range(0.0, 1.0) = 0.0;
uniform float recursion_phase = 0.0;
uniform float recursion_direction = 1.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float rounded_rect_mask(vec2 uv, vec4 rect, float radius_px, vec2 pixel_size) {
	vec2 center = rect.xy + rect.zw * 0.5;
	vec2 half_size_px = rect.zw / (pixel_size * 2.0);
	vec2 delta_px = (uv - center) / pixel_size;
	float radius = min(radius_px, min(half_size_px.x, half_size_px.y) * 0.24);
	vec2 q = abs(delta_px) - half_size_px + radius;
	float distance_px = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(-1.5, 3.5, distance_px);
}

vec2 rotate_around_center(vec2 uv, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	mat2 rotation = mat2(vec2(cosine, sine), vec2(-sine, cosine));
	return rotation * (uv - 0.5) + 0.5;
}

vec2 enter_portal(vec2 uv, vec4 portal_rect, float level, float portal_index) {
	vec2 local_uv = (uv - portal_rect.xy) / max(portal_rect.zw, vec2(0.0001));
	float staggered_phase = recursion_phase - portal_index * 0.42 * recursion_direction;
	float breathing = sin(staggered_phase * 1.7 + level * 1.31) * 0.012 * recursion_energy;
	float angle = recursion_direction * (0.008 + level * 0.004) * recursion_energy + breathing;
	local_uv = rotate_around_center(local_uv, angle);
	float depth_scale = 1.0 + sin(staggered_phase + level * 0.9) * 0.018 * recursion_energy;
	return (local_uv - 0.5) * depth_scale + 0.5;
}

vec3 recursive_portal_color(vec2 screen_uv, vec4 portal_rect, float portal_index, vec2 pixel_size) {
	vec2 ray_uv = enter_portal(screen_uv, portal_rect, 0.0, portal_index);
	vec3 recursive_color = texture(screen_texture, clamp(ray_uv, vec2(0.0), vec2(1.0))).rgb;
	float accumulated_depth = 0.0;

	// Each source copy contains the same portal rectangle. Entering it again creates the next
	// explicit level, while a diminishing mix keeps deep copies readable rather than noisy.
	for (int level = 1; level <= 4; level++) {
		float nested_mask = rounded_rect_mask(ray_uv, portal_rect, 15.0, pixel_size);
		vec2 next_uv = enter_portal(ray_uv, portal_rect, float(level), portal_index);
		vec3 next_color = texture(screen_texture, clamp(next_uv, vec2(0.0), vec2(1.0))).rgb;
		float level_weight = nested_mask * (0.90 - float(level) * 0.11);
		recursive_color = mix(recursive_color, next_color, level_weight);
		ray_uv = mix(ray_uv, next_uv, nested_mask);
		accumulated_depth += nested_mask;
	}
	float depth_tone = clamp(accumulated_depth / 4.0, 0.0, 1.0);
	recursive_color *= 1.0 - depth_tone * recursion_energy * 0.10;
	return recursive_color;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 result = source;
	float reveal = smoothstep(0.035, 0.42, recursion_energy);

	float mask_0 = rounded_rect_mask(SCREEN_UV, portal_rect_0_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_near.x;
	float mask_1 = rounded_rect_mask(SCREEN_UV, portal_rect_1_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_near.y;
	float mask_2 = rounded_rect_mask(SCREEN_UV, portal_rect_2_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_near.z;
	float mask_3 = rounded_rect_mask(SCREEN_UV, portal_rect_3_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_near.w;
	float mask_4 = rounded_rect_mask(SCREEN_UV, portal_rect_4_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_far.x;
	float mask_5 = rounded_rect_mask(SCREEN_UV, portal_rect_5_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_far.y;
	float mask_6 = rounded_rect_mask(SCREEN_UV, portal_rect_6_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_far.z;
	float mask_7 = rounded_rect_mask(SCREEN_UV, portal_rect_7_uv, 15.0, SCREEN_PIXEL_SIZE) * portal_enabled_far.w;
	vec4 masks_near = vec4(mask_0, mask_1, mask_2, mask_3);
	vec4 masks_far = vec4(mask_4, mask_5, mask_6, mask_7);

	// Portal bodies do not overlap in the transcript. Dynamic branches keep the expensive recursive
	// samples local to the one bubble containing this pixel instead of evaluating all eight tunnels.
	if (mask_0 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_0_uv, 0.0, SCREEN_PIXEL_SIZE), mask_0 * reveal * portal_strengths_near.x);
	} else if (mask_1 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_1_uv, 1.0, SCREEN_PIXEL_SIZE), mask_1 * reveal * portal_strengths_near.y);
	} else if (mask_2 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_2_uv, 2.0, SCREEN_PIXEL_SIZE), mask_2 * reveal * portal_strengths_near.z);
	} else if (mask_3 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_3_uv, 3.0, SCREEN_PIXEL_SIZE), mask_3 * reveal * portal_strengths_near.w);
	} else if (mask_4 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_4_uv, 4.0, SCREEN_PIXEL_SIZE), mask_4 * reveal * portal_strengths_far.x);
	} else if (mask_5 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_5_uv, 5.0, SCREEN_PIXEL_SIZE), mask_5 * reveal * portal_strengths_far.y);
	} else if (mask_6 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_6_uv, 6.0, SCREEN_PIXEL_SIZE), mask_6 * reveal * portal_strengths_far.z);
	} else if (mask_7 > 0.0) {
		result = mix(result, recursive_portal_color(SCREEN_UV, portal_rect_7_uv, 7.0, SCREEN_PIXEL_SIZE), mask_7 * reveal * portal_strengths_far.w);
	}

	float weighted_mask = dot(masks_near, portal_strengths_near) + dot(masks_far, portal_strengths_far);
	float combined_edge = clamp(length(vec2(dFdx(weighted_mask), dFdy(weighted_mask))) * 7.0, 0.0, 1.0);
	result = mix(result, accent_color.rgb, combined_edge * recursion_energy * 0.075);
	COLOR = vec4(result, 1.0);
}
