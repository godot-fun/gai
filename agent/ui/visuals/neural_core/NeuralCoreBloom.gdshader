shader_type canvas_item;
render_mode blend_add;

// Sparse splats: additive glow over chat; empty pixels discard (no wash).
uniform sampler2D field_tex : filter_linear, repeat_disable;

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
	vec3 raw = sharp + wide4 * 0.90 + wide8 * 0.68;
	float energy = length(raw);
	if (energy < 0.014) {
		discard;
	}
	vec3 glow = raw * 2.05;
	float alpha = clamp(sqrt(energy) * 1.55, 0.12, 1.0);
	COLOR = vec4(glow, alpha);
}
