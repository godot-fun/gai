shader_type canvas_item;
render_mode blend_add;

// Field bloom + soft crescent halo (ai-visualizer faces/neural step 4).
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec2 crescent_px = vec2(256.0, 256.0);
uniform float halo_radius_px = 160.0;
uniform float halo_strength = 0.28;
uniform float alert_mix = 0.0;

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

float crescent_halo(vec2 frag_px) {
	float dist = length(frag_px - crescent_px);
	float radius = max(halo_radius_px, 1.0);
	float norm = dist / radius;
	float core = exp(-norm * norm * 1.9);
	float wing = exp(-norm * norm * 0.72);
	return (core * 0.9 + wing * 0.1) * halo_strength;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(field_tex, 0));
	vec2 frag_px = UV * tex_size;
	vec2 texel = vec2(1.0) / tex_size;
	vec3 sharp = texture(field_tex, UV).rgb;
	vec3 wide4 = sample_wide(field_tex, UV, texel, 4.0);
	vec3 wide8 = sample_wide(field_tex, UV, texel, 8.0);
	vec3 raw = sharp + wide4 + wide8;
	float h = crescent_halo(frag_px);
	vec3 halo_tint = mix(vec3(0.353, 0.510, 1.0), vec3(1.0, 0.204, 0.176), alert_mix);
	vec3 glow = raw * 1.75 + halo_tint * h * 1.35;
	float field_energy = length(sharp + wide4 * 0.65 + wide8 * 0.45);
	float energy = field_energy + h * 0.95;
	if (energy < 0.004) {
		discard;
	}
	float alpha = clamp(sqrt(energy) * 1.32 + h * 0.35, 0.10, 1.0);
	COLOR = vec4(glow, alpha);
}
