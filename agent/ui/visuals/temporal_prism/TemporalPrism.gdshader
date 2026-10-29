shader_type canvas_item;

// Spatially staggered phase produces a slit-scan impression without persistent frame history.
// At zero energy the pass is pixel-identical to the rendered application.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float temporal_energy : hint_range(0.0, 1.0) = 0.0;
uniform float temporal_phase = 0.0;
uniform float temporal_direction = 1.0;
uniform float slice_count : hint_range(28.0, 96.0) = 48.0;
uniform float max_offset_px : hint_range(0.0, 64.0) = 38.0;
uniform float toolbar_height_px = 0.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float hash(float value) {
	return fract(sin(value * 91.713) * 43758.5453);
}

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float active_energy = smoothstep(0.0, 0.035, temporal_energy) * body_mask;

	float slice_position = SCREEN_UV.x * slice_count;
	float slice_index = floor(slice_position);
	float slice_local = fract(slice_position);
	float slice_progress = slice_index / max(slice_count - 1.0, 1.0);
	float delayed_progress = mix(slice_progress, 1.0 - slice_progress, step(temporal_direction, 0.0));
	float phase = temporal_phase - delayed_progress * 7.4;
	float personality = hash(slice_index + 4.0) - 0.5;
	float time_sample = sin(phase) * 0.72 + sin(phase * 2.17 + personality * 3.0) * 0.28;

	// Pin every slice at its invisible boundaries and stretch only its interior. Existing horizontal
	// lines therefore become woven time wedges rather than disconnected glitch blocks.
	float slice_interior = pow(max(sin(slice_local * 3.14159265), 0.0), 0.72);
	float slice_center = (slice_index + 0.5) / slice_count;
	float local_from_center = SCREEN_UV.x - slice_center;
	float stretch = 1.0 + time_sample * temporal_energy * 0.34;
	float stretched_x = slice_center + local_from_center / max(stretch, 0.62);
	float offset_x = time_sample * max_offset_px * SCREEN_PIXEL_SIZE.x * temporal_energy * slice_interior;
	float offset_y = sin(phase * 0.83 + slice_progress * 4.0) * max_offset_px * 0.16 * SCREEN_PIXEL_SIZE.y * temporal_energy * slice_interior;
	vec2 prism_uv = vec2(stretched_x + offset_x, SCREEN_UV.y + offset_y);
	prism_uv = mix(SCREEN_UV, prism_uv, active_energy);
	prism_uv = clamp(prism_uv, vec2(0.0), vec2(1.0));

	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 prism = texture(screen_texture, prism_uv).rgb;
	float temporal_edge = clamp(abs(luminance(source) - luminance(prism)) * 2.0, 0.0, 1.0);
	prism = mix(prism, accent_color.rgb, temporal_edge * temporal_energy * 0.055);
	vec3 result = mix(source, prism, active_energy);
	COLOR = vec4(result, 1.0);
}
