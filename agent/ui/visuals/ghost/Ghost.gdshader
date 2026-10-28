shader_type canvas_item;

// No visible object is rendered. Text and fine UI detail detach from their surfaces while panels
// and empty space remain still, making the body legible only through what floats around it.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 presence_center = vec2(0.68, 0.58);
uniform vec2 trail_center = vec2(0.72, 0.58);
uniform vec2 motion_velocity = vec2(0.0);
uniform float motion_phase = 0.0;
uniform float radius_px : hint_range(64.0, 384.0) = 224.0;
uniform vec4 effect_area_rect = vec4(0.0, 0.04, 1.0, 0.96);

float edge_strength(vec2 uv, vec2 pixel_size) {
	vec3 left = texture(screen_texture, clamp(uv - vec2(pixel_size.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 right = texture(screen_texture, clamp(uv + vec2(pixel_size.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 up = texture(screen_texture, clamp(uv - vec2(0.0, pixel_size.y), vec2(0.0), vec2(1.0))).rgb;
	vec3 down = texture(screen_texture, clamp(uv + vec2(0.0, pixel_size.y), vec2(0.0), vec2(1.0))).rgb;
	return clamp(length(right - left) * 1.35 + length(down - up) * 1.35, 0.0, 1.0);
}

vec3 local_surface(vec2 uv, vec2 pixel_size) {
	vec2 spread = pixel_size * 7.0;
	vec3 horizontal = texture(screen_texture, clamp(uv - vec2(spread.x, 0.0), vec2(0.0), vec2(1.0))).rgb
		+ texture(screen_texture, clamp(uv + vec2(spread.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
	vec3 vertical = texture(screen_texture, clamp(uv - vec2(0.0, spread.y), vec2(0.0), vec2(1.0))).rgb
		+ texture(screen_texture, clamp(uv + vec2(0.0, spread.y), vec2(0.0), vec2(1.0))).rgb;
	return (horizontal + vertical) * 0.25;
}

float detail_mask(vec2 uv, vec2 pixel_size) {
	vec3 color = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	vec3 surface = local_surface(uv, pixel_size);
	float edge = edge_strength(uv, pixel_size);
	float local_contrast = length(color - surface);
	return smoothstep(0.075, 0.42, max(edge * 0.82, local_contrast * 1.32));
}

float area_mask(vec2 uv, vec4 rect, vec2 pixel_size) {
	vec2 feather = pixel_size * 10.0;
	float horizontal = smoothstep(rect.x, rect.x + feather.x, uv.x)
		* (1.0 - smoothstep(rect.x + rect.z - feather.x, rect.x + rect.z, uv.x));
	float vertical = smoothstep(rect.y, rect.y + feather.y, uv.y)
		* (1.0 - smoothstep(rect.y + rect.w - feather.y, rect.y + rect.w, uv.y));
	return horizontal * vertical;
}

vec2 rotate_vector(vec2 value, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(vec2(cosine, -sine), vec2(sine, cosine)) * value;
}

vec3 presence_field(vec2 uv, vec2 center, float radius, float phase, vec2 pixel_size) {
	vec2 pixel_delta = (uv - center) / pixel_size;
	float rotation = sin(phase * 0.31) * 0.22;
	vec2 local = rotate_vector(pixel_delta, -rotation);
	float angle = atan(local.y, local.x);
	float irregularity = sin(angle * 3.0 + phase * 0.61) * 0.065
		+ sin(angle * 5.0 - phase * 0.43) * 0.032;
	vec2 axes = vec2(radius * (1.0 + irregularity), radius * (0.70 - irregularity * 0.18));
	float ellipse = length(local / axes);
	float signed_distance = (ellipse - 1.0) * radius;
	vec2 normal_vector = vec2(local.x / max(axes.x * axes.x, 1.0), local.y / max(axes.y * axes.y, 1.0));
	vec2 local_normal = normal_vector / max(length(normal_vector), 0.0001);
	vec2 normal = rotate_vector(local_normal, rotation);
	return vec3(normal, signed_distance);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 source = texture(screen_texture, uv).rgb;
	float area = area_mask(uv, effect_area_rect, SCREEN_PIXEL_SIZE);
	float strength = presence_strength * area;
	if (strength <= 0.0001) {
		COLOR = vec4(source, 1.0);
	} else {
		vec3 trail_field = presence_field(uv, trail_center, radius_px * 0.92, motion_phase - 0.34, SCREEN_PIXEL_SIZE);
		vec3 field = presence_field(uv, presence_center, radius_px, motion_phase, SCREEN_PIXEL_SIZE);
		float body_contact = 1.0 - smoothstep(-radius_px * 0.62, radius_px * 0.24, field.z);
		float trail_contact = 1.0 - smoothstep(-radius_px * 0.52, radius_px * 0.18, trail_field.z);
		float contact = clamp(max(body_contact, trail_contact * 0.30), 0.0, 1.0);

		float horizontal_band = floor(uv.y / max(SCREEN_PIXEL_SIZE.y * 18.0, 0.0001));
		float vertical_group = floor(uv.x / max(SCREEN_PIXEL_SIZE.x * 132.0, 0.0001));
		float group_variation = sin(horizontal_band * 1.731 + vertical_group * 0.619 + motion_phase * 0.23);
		float velocity_length = length(motion_velocity);
		vec2 velocity_direction = motion_velocity / max(velocity_length, 0.0001);
		vec2 drift_direction = normalize(vec2(0.34 + group_variation * 0.24, -1.0 + group_variation * 0.08)
			+ velocity_direction * clamp(velocity_length * 5.5, 0.0, 0.58));
		float lift_reference_px = mix(128.0, 224.0, presence_strength);
		float lift_px = lift_reference_px * (0.075 + (group_variation * 0.5 + 0.5) * 0.050) * contact * strength;
		vec2 floating_uv = clamp(uv - drift_direction * SCREEN_PIXEL_SIZE * lift_px, vec2(0.0), vec2(1.0));

		float origin_detail = detail_mask(uv, SCREEN_PIXEL_SIZE);
		float origin_release = origin_detail * contact * strength;
		vec3 result = mix(source, local_surface(uv, SCREEN_PIXEL_SIZE), origin_release * 0.84);

		float floating_detail = detail_mask(floating_uv, SCREEN_PIXEL_SIZE);
		float floating_contact = clamp(contact + 0.16, 0.0, 1.0);
		vec3 floating_color = texture(screen_texture, floating_uv).rgb;
		result = mix(result, floating_color, floating_detail * floating_contact * strength * 0.96);

		vec2 depth_uv = clamp(floating_uv + vec2(-drift_direction.y, drift_direction.x)
			* SCREEN_PIXEL_SIZE * (2.0 + group_variation * 1.2), vec2(0.0), vec2(1.0));
		float depth_detail = detail_mask(depth_uv, SCREEN_PIXEL_SIZE);
		result = mix(result, texture(screen_texture, depth_uv).rgb, depth_detail * floating_detail * strength * 0.12);
		COLOR = vec4(result, 1.0);
	}
}
