shader_type canvas_item;

// Component compositor for zero gravity. The CPU supplies complete chat-entry rectangles and
// rigid-body transforms; the shader clears each live source and redraws it at its physical pose.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform int body_count = 0;
uniform vec4 body_rects[18];
uniform vec4 body_motions[18]; // xy: normalized offset, z: rotation, w: activity
uniform vec4 effect_area_rect = vec4(0.0, 0.04, 1.0, 0.96);

vec2 rotate_vector(vec2 value, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(vec2(cosine, -sine), vec2(sine, cosine)) * value;
}

float rect_mask(vec2 uv, vec4 rect, vec2 feather) {
	float horizontal = smoothstep(rect.x, rect.x + feather.x, uv.x)
		* (1.0 - smoothstep(rect.x + rect.z - feather.x, rect.x + rect.z, uv.x));
	float vertical = smoothstep(rect.y, rect.y + feather.y, uv.y)
		* (1.0 - smoothstep(rect.y + rect.w - feather.y, rect.y + rect.w, uv.y));
	return horizontal * vertical;
}

float area_mask(vec2 uv, vec4 rect, vec2 pixel_size) {
	return rect_mask(uv, rect, pixel_size * 10.0);
}

vec3 exposed_surface(vec2 uv, vec4 rect, vec2 pixel_size) {
	vec2 padding = pixel_size * 9.0;
	vec2 left_uv = vec2(max(rect.x - padding.x, 0.0), uv.y);
	vec2 right_uv = vec2(min(rect.x + rect.z + padding.x, 1.0), uv.y);
	vec2 top_uv = vec2(uv.x, max(rect.y - padding.y, effect_area_rect.y));
	vec2 bottom_uv = vec2(uv.x, min(rect.y + rect.w + padding.y, 1.0));
	vec3 sides = texture(screen_texture, left_uv).rgb + texture(screen_texture, right_uv).rgb;
	vec3 vertical = texture(screen_texture, top_uv).rgb + texture(screen_texture, bottom_uv).rgb;
	return sides * 0.38 + vertical * 0.12;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 result = texture(screen_texture, uv).rgb;
	float output_area = area_mask(uv, effect_area_rect, SCREEN_PIXEL_SIZE);

	// Clear live component locations first so the transformed copies do not become echoes.
	for (int index = 0; index < 18; index++) {
		if (index < body_count) {
			vec4 rect = body_rects[index];
			float activity = body_motions[index].w;
			float source_mask = rect_mask(uv, rect, SCREEN_PIXEL_SIZE * 2.0) * activity * output_area;
			if (source_mask > 0.0001) {
				result = mix(result, exposed_surface(uv, rect, SCREEN_PIXEL_SIZE), source_mask * 0.96);
			}
		}
	}

	// Draw complete components in transcript order using inverse rigid transforms.
	for (int index = 0; index < 18; index++) {
		if (index < body_count) {
			vec4 rect = body_rects[index];
			vec4 motion = body_motions[index];
			vec2 source_center = rect.xy + rect.zw * 0.5;
			vec2 destination_center = source_center + motion.xy;
			vec2 destination_local_px = (uv - destination_center) / SCREEN_PIXEL_SIZE;
			vec2 source_uv = source_center + rotate_vector(destination_local_px, -motion.z) * SCREEN_PIXEL_SIZE;
			float component_mask = rect_mask(source_uv, rect, SCREEN_PIXEL_SIZE * 1.5) * motion.w * output_area;
			if (component_mask > 0.0001) {
				vec3 component_color = texture(screen_texture, clamp(source_uv, vec2(0.0), vec2(1.0))).rgb;
				result = mix(result, component_color, component_mask);
			}
		}
	}

	COLOR = vec4(result, 1.0);
}
