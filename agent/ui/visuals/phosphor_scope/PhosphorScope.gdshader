shader_type canvas_item;

// Phosphor oscilloscope faceplate. Reasoning and content steer the beam; cross-coupling keeps
// elliptical motion when only one channel is hot. At zero drive the pass matches the application.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float reasoning_drive : hint_range(0.0, 1.0) = 0.0;
uniform float content_drive : hint_range(0.0, 1.0) = 0.0;
uniform float beam_energy : hint_range(0.0, 1.0) = 0.0;
uniform float beam_phase = 0.0;
uniform float frequency_ratio : hint_range(1.0, 3.0) = 1.5;
uniform float max_offset_px : hint_range(0.0, 80.0) = 50.0;
uniform float phosphor_burst : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 phosphor_tint(vec3 accent, float failure) {
	vec3 crt = mix(vec3(accent.g * 0.55 + 0.12, accent.g * 0.95 + 0.55, accent.b * 0.35 + 0.08), accent, 0.42);
	return mix(crt, error_color.rgb, failure);
}

vec2 beam_channels(float phase, float ratio, float reasoning, float content, float beam) {
	float bundle = max(max(reasoning, content), beam * 0.58);
	float x_ch = sin(phase) * reasoning
		+ sin(phase * 2.0 + 0.4) * content * 0.62
		+ cos(phase) * bundle * 0.32;
	float y_ch = sin(phase * ratio + 0.72) * content
		+ cos(phase * ratio * 0.5) * reasoning * 0.62
		+ sin(phase * 0.5) * bundle * 0.30;
	return vec2(x_ch, y_ch);
}

vec2 beam_displacement(float phase, float ratio, float reasoning, float content, float beam, vec2 pixel_size) {
	return beam_channels(phase, ratio, reasoning, content, beam) * max_offset_px * pixel_size;
}

float graticule_mask(vec2 uv, vec2 pixel_size) {
	vec2 minor = abs(fract(uv * vec2(56.0, 31.5)) - 0.5);
	float minor_line = 1.0 - smoothstep(0.0, pixel_size.x * 1.35, min(minor.x, minor.y) * 2.0);
	vec2 major = abs(fract(uv * vec2(14.0, 7.875)) - 0.5);
	float major_line = 1.0 - smoothstep(0.0, pixel_size.x * 1.65, min(major.x, major.y) * 2.0);
	float center_x = 1.0 - smoothstep(0.0, pixel_size.x * 1.8, abs(uv.x - 0.5));
	float center_y = 1.0 - smoothstep(0.0, pixel_size.y * 1.8, abs(uv.y - 0.5));
	return clamp(minor_line * 0.22 + major_line * 0.38 + max(center_x, center_y) * 0.28, 0.0, 1.0);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float motion = max(reasoning_drive, content_drive);
	float active = smoothstep(0.0, 0.022, max(beam_energy, motion * 0.82)) * body_mask;
	bool effect_live = active >= 0.001 || phosphor_burst >= 0.02 || failure_tint >= 0.02;

	vec3 result = source;
	if (effect_live) {
		vec3 glow_color = phosphor_tint(accent_color.rgb, failure_tint);
		vec2 disp = beam_displacement(beam_phase, frequency_ratio, reasoning_drive, content_drive, beam_energy, SCREEN_PIXEL_SIZE);
		disp *= 1.0 + phosphor_burst * 0.55;

		vec2 scope_uv = clamp(SCREEN_UV - disp, vec2(0.0), vec2(1.0));
		vec3 scope = texture(screen_texture, scope_uv).rgb;

		float persistence = active * (0.34 + phosphor_burst * 0.38);
		int trail_taps = phosphor_burst > 0.12 ? 4 : 3;
		vec3 phosphor_accum = vec3(0.0);
		for (int tap = 1; tap <= 4; tap++) {
			if (tap > trail_taps) {
				continue;
			}
			float step = float(tap) * 0.34;
			vec2 trail_uv = clamp(SCREEN_UV - disp * step, vec2(0.0), vec2(1.0));
			vec3 trail_sample = texture(screen_texture, trail_uv).rgb;
			float weight = persistence * (0.72 - float(tap - 1) * 0.14);
			result = mix(result, trail_sample, weight * 0.55);
			phosphor_accum += abs(trail_sample - scope) * weight;
		}

		result = mix(result, scope, active);

		float edge = clamp(abs(luminance(source) - luminance(scope)) * 3.2, 0.0, 1.0);
		float streak = clamp(length(disp) * viewport_px.x * 0.08, 0.0, 1.0);
		float glow = edge * (0.14 + phosphor_burst * 0.22) + streak * active * (0.08 + phosphor_burst * 0.12);
		glow += clamp(length(phosphor_accum) * 2.4, 0.0, 1.0) * (0.10 + phosphor_burst * 0.14);
		result += glow_color * glow;

		float grid = graticule_mask(SCREEN_UV, SCREEN_PIXEL_SIZE) * active * (0.20 + phosphor_burst * 0.16);
		result = mix(result, glow_color, grid);
	}

	COLOR = vec4(result, 1.0);
}
