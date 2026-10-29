shader_type canvas_item;

// Phosphor oscilloscope faceplate: reasoning and content steer horizontal and vertical beam
// deflection. At zero drive the pass is pixel-identical to the rendered application.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float reasoning_drive : hint_range(0.0, 1.0) = 0.0;
uniform float content_drive : hint_range(0.0, 1.0) = 0.0;
uniform float beam_energy : hint_range(0.0, 1.0) = 0.0;
uniform float beam_phase = 0.0;
uniform float frequency_ratio : hint_range(1.0, 3.0) = 1.5;
uniform float max_offset_px : hint_range(0.0, 64.0) = 34.0;
uniform float phosphor_burst : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

vec2 beam_displacement(float phase, float ratio, float reasoning, float content, vec2 pixel_size) {
	float x_signal = sin(phase) * reasoning;
	float y_signal = sin(phase * ratio + 0.72) * content;
	return vec2(x_signal, y_signal) * max_offset_px * pixel_size;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float motion = max(reasoning_drive, content_drive);
	float active = smoothstep(0.0, 0.028, max(beam_energy, motion * 0.85)) * body_mask;
	bool effect_live = active >= 0.001 || phosphor_burst >= 0.02 || failure_tint >= 0.02;

	vec3 result = source;
	if (effect_live) {
		vec2 disp = beam_displacement(beam_phase, frequency_ratio, reasoning_drive, content_drive, SCREEN_PIXEL_SIZE);
		disp *= 1.0 + phosphor_burst * 0.42;

		float persistence = active * (0.20 + phosphor_burst * 0.20);
		int trail_taps = phosphor_burst > 0.18 ? 3 : 2;
		for (int tap = 1; tap <= 3; tap++) {
			if (tap > trail_taps) {
				continue;
			}
			float weight = persistence * (0.58 - float(tap - 1) * 0.16);
			vec2 trail_uv = clamp(SCREEN_UV - disp * float(tap) * 0.36, vec2(0.0), vec2(1.0));
			result = mix(result, texture(screen_texture, trail_uv).rgb, weight);
		}

		vec2 scope_uv = clamp(SCREEN_UV - disp, vec2(0.0), vec2(1.0));
		vec3 scope = texture(screen_texture, scope_uv).rgb;
		result = mix(result, scope, active);

		float edge = clamp(abs(luminance(source) - luminance(scope)) * 2.4, 0.0, 1.0);
		vec3 phosphor = mix(accent_color.rgb, error_color.rgb, failure_tint);
		result = mix(result, phosphor, edge * active * (0.038 + phosphor_burst * 0.075));
	}

	COLOR = vec4(result, 1.0);
}
