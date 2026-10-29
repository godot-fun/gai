shader_type canvas_item;

// Heat-mirage refraction: edge luminance bends the live interface like hot air over asphalt.
// Zero strength = identity sample.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float mirage_strength : hint_range(0.0, 1.0) = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float field_energy : hint_range(0.0, 1.0) = 0.0;
uniform float flow_phase = 0.0;
uniform float shock_energy : hint_range(0.0, 1.0) = 0.0;
uniform float shock_progress : hint_range(-0.1, 1.25) = 1.2;
uniform float shock_angle = 0.0;
uniform float max_deflection_px : hint_range(0.0, 80.0) = 42.0;
uniform float presentation_gain : hint_range(0.0, 1.0) = 1.0;
uniform float false_color_gain : hint_range(0.0, 1.0) = 1.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float sample_luma(vec2 uv) {
	return luminance(texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb);
}

vec4 mirage_field(vec2 uv, vec2 pixel_size, float center_luma) {
	vec2 step = pixel_size * 2.8;
	float left = sample_luma(uv - vec2(step.x, 0.0));
	float right = sample_luma(uv + vec2(step.x, 0.0));
	float up = sample_luma(uv - vec2(0.0, step.y));
	float down = sample_luma(uv + vec2(0.0, step.y));
	float lap = left + right + up + down - 4.0 * center_luma;
	vec2 grad = vec2(right - left, down - up);
	float grad_len = length(grad);
	float edge_mask = smoothstep(0.0015, 0.028, grad_len);
	vec2 dir = grad / max(grad_len, 0.0008);
	vec2 offset = dir * lap * mirage_strength * max_deflection_px * pixel_size * 8.8 * edge_mask;
	offset += vec2(
		sin(flow_phase + uv.y * 20.0 + uv.x * 3.0),
		cos(flow_phase * 0.86 + uv.x * 18.0 + uv.y * 2.0)
	) * flow_strength * max_deflection_px * 0.22 * pixel_size;
	if (shock_energy > 0.01 && shock_progress < 1.12) {
		vec2 shock_dir = vec2(cos(shock_angle), sin(shock_angle));
		float plane = dot(uv - vec2(0.5), shock_dir);
		float wave = sin((plane * 110.0 - shock_progress * 16.0) * 3.14159265);
		offset += shock_dir * wave * shock_energy * max_deflection_px * 0.42 * pixel_size * (1.0 - clamp(shock_progress, 0.0, 1.0));
	}
	return vec4(offset.x, offset.y, lap * edge_mask, grad_len);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float motion = max(mirage_strength, flow_strength);
	float active = smoothstep(0.0, 0.024, max(field_energy, motion * 0.8)) * body_mask;
	bool effect_live = active >= 0.001 || shock_energy >= 0.02;

	vec3 result = source;
	if (effect_live) {
		float center_luma = luminance(source);
		vec4 field = mirage_field(SCREEN_UV, SCREEN_PIXEL_SIZE, center_luma);
		vec2 refract_uv = clamp(SCREEN_UV - field.xy, vec2(0.0), vec2(1.0));
		vec3 refracted = texture(screen_texture, refract_uv).rgb;
		float blend = active * presentation_gain;
		result = mix(source, refracted, blend);
		vec2 streak_uv = clamp(SCREEN_UV - field.xy * 0.55, vec2(0.0), vec2(1.0));
		vec3 streak = texture(screen_texture, streak_uv).rgb;
		result = mix(result, streak, blend * 0.22);
		float rim = clamp(abs(field.z) * 16.0, 0.0, 1.0) * active * false_color_gain;
		result = mix(result, accent_color.rgb, rim * 0.10);
	}

	COLOR = vec4(result, 1.0);
}
