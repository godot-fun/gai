shader_type canvas_item;

// Multi-scale additive bloom for the neural field (matches ai-visualizer field + 1/4 + 1/8 taps).
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec4 background_color : source_color = vec4(0.007843, 0.011765, 0.039216, 1.0);

vec3 sample_wide(sampler2D tex, vec2 uv, vec2 texel, float scale) {
	vec3 accum = vec3(0.0);
	float weight = 0.0;
	for (int ox = -1; ox <= 1; ox++) {
		for (int oy = -1; oy <= 1; oy++) {
			vec2 off = vec2(float(ox), float(oy)) * texel * scale;
			accum += texture(tex, uv + off).rgb;
			weight += 1.0;
		}
	}
	return accum / weight;
}

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(field_tex, 0));
	vec3 sharp = texture(field_tex, UV).rgb;
	vec3 wide4 = sample_wide(field_tex, UV, texel, 4.0);
	vec3 wide8 = sample_wide(field_tex, UV, texel, 8.0);
	// Keep the sharp pass dominant so cluster dots and labels stay readable.
	vec3 glow = sharp + wide4 * 0.82 + wide8 * 0.58;
	COLOR = vec4(background_color.rgb + glow, 1.0);
}
