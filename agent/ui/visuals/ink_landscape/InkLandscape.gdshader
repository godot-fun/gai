shader_type canvas_item;
render_mode unshaded;

uniform vec4 ink_color : source_color = vec4(0.10, 0.12, 0.105, 1.0);
uniform vec4 accent_color : source_color = vec4(0.76, 0.20, 0.14, 1.0);
uniform float elapsed = 0.0;
uniform float reasoning : hint_range(0.0, 1.0) = 0.0;
uniform float completion : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_0 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_1 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_2 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_3 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_4 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_5 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_6 : hint_range(0.0, 1.0) = 0.0;
uniform float mountain_7 : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.48;
	}
	return value;
}

float peak(float x, float center, float width, float height) {
	float q = (x - center) / width;
	// Exponential falloff keeps a calligraphic cusp; Gaussian peaks read as soft charts.
	return exp(-abs(q) * 1.7) * height;
}

float rounded_peak(float x, float center, float width, float height) {
	float q = (x - center) / width;
	return exp(-q * q * 0.72) * height;
}

float mountain_profile(float x, float center, float width, float seed, float shape) {
	float q = (x - center) / width;
	float result = 0.0;
	if (shape < 0.5) {
		// Low, broad distant ridge.
		result = rounded_peak(x, center, width * 1.75, 0.72);
		result += rounded_peak(x, center - width * 1.7, width * 1.15, 0.22);
		result += rounded_peak(x, center + width * 1.9, width * 1.35, 0.18);
	} else if (shape < 1.5) {
		// Long rolling range made from several unequal summits.
		result = rounded_peak(x, center - width * 1.45, width * 1.25, 0.36);
		result += rounded_peak(x, center, width * 1.05, 0.62);
		result += rounded_peak(x, center + width * 1.55, width * 1.5, 0.31);
	} else if (shape < 2.5) {
		// Twin peaks with a readable saddle.
		result = rounded_peak(x, center - width * 0.62, width * 0.72, 0.88);
		result += rounded_peak(x, center + width * 0.68, width * 0.82, 0.72);
	} else if (shape < 3.5) {
		// Asymmetric cliff: a firm face and a long eroded slope.
		float left = exp(-abs(q) * 1.05);
		float right = exp(-abs(q) * 2.55);
		result = mix(left, right, step(0.0, q));
		result += rounded_peak(x, center - width * 1.35, width * 0.9, 0.24);
	} else {
		// A restrained sharp principal summit, used sparingly in the foreground.
		result = exp(-abs(q) * 1.72);
		result += rounded_peak(x, center - width * 1.25, width * 0.9, 0.28);
		result += rounded_peak(x, center + width * 1.35, width, 0.23);
	}
	float rock = (noise(vec2(x * 45.0, seed * 9.0)) - 0.5) * mix(0.025, 0.07, clamp(shape / 4.0, 0.0, 1.0));
	return max(result + rock, 0.0);
}

float mountain_layer(vec2 uv, float center, float width, float base, float height_scale, float seed, float strength, float softness, float shape, float growth) {
	if (growth <= 0.001) {
		return 0.0;
	}
	float grown = smoothstep(0.0, 1.0, growth);
	float profile = mountain_profile(uv.x, center, width, seed, shape);
	float height = base - profile * height_scale * (0.18 + grown * 0.82);
	float distance_to_edge = uv.y - height;
	float edge_noise = (fbm(vec2(uv.x * 22.0, uv.y * 13.0 + seed)) - 0.5) * mix(0.008, 0.019, 1.0 - softness);
	float body = smoothstep(-0.008 - softness * 0.012, 0.025 + softness * 0.025 + edge_noise, distance_to_edge) * smoothstep(base + 0.10, base - 0.03, uv.y);
	float wet_edge = exp(-abs(distance_to_edge + edge_noise) * mix(145.0, 72.0, softness)) * mix(0.86, 0.34, softness);
	float dry_brush = smoothstep(0.28, 0.82, fbm(vec2(uv.x * 54.0, uv.y * 18.0 + seed * 3.0)));
	float local_distance = abs(uv.x - center) / max(width * mix(3.8, 5.3, softness), 0.001);
	float bloom = smoothstep(grown + 0.14, grown - 0.10, local_distance);
	return (body * mix(0.40 + dry_brush * 0.16, 0.48 + dry_brush * 0.32, 1.0 - softness) + wet_edge) * strength * bloom * grown;
}

void fragment() {
	vec2 uv = UV;
	float paper = fbm(uv * vec2(180.0, 95.0));
	float ink = 0.0;
	// One independent mountain is activated per turn: distant and pale first,
	// then progressively taller, darker foreground peaks.
	// max() preserves aerial perspective; additive ink made every overlap glow white.
	ink = max(ink, mountain_layer(uv, 0.18, 0.18, 0.43, 0.14, 1.1, 0.13, 0.92, 0.0, mountain_0));
	ink = max(ink, mountain_layer(uv, 0.76, 0.16, 0.51, 0.20, 2.0, 0.17, 0.86, 1.0, mountain_1));
	ink = max(ink, mountain_layer(uv, 0.39, 0.13, 0.62, 0.27, 3.1, 0.24, 0.72, 2.0, mountain_2));
	ink = max(ink, mountain_layer(uv, 0.68, 0.12, 0.70, 0.35, 4.0, 0.31, 0.58, 3.0, mountain_3));
	ink = max(ink, mountain_layer(uv, 0.17, 0.14, 0.82, 0.43, 5.2, 0.40, 0.48, 1.0, mountain_4));
	ink = max(ink, mountain_layer(uv, 0.84, 0.105, 0.89, 0.52, 6.3, 0.49, 0.34, 4.0, mountain_5));
	ink = max(ink, mountain_layer(uv, 0.46, 0.15, 0.98, 0.55, 7.1, 0.58, 0.25, 0.0, mountain_6));
	ink = max(ink, mountain_layer(uv, 0.67, 0.13, 1.02, 0.58, 8.4, 0.64, 0.18, 3.0, mountain_7));

	// Two translucent valleys cut through every layer as genuine negative-space fog.
	float fog_y1 = 0.57 + sin(uv.x * 7.5 + elapsed * 0.045) * 0.022 + sin(uv.x * 20.0) * 0.007;
	float fog_y2 = 0.74 + sin(uv.x * 5.3 - elapsed * 0.032 + 1.4) * 0.018;
	float fog = exp(-abs(uv.y - fog_y1) * 34.0) * 0.92 + exp(-abs(uv.y - fog_y2) * 45.0) * 0.72;
	ink *= 1.0 - clamp(fog, 0.0, 0.76);

	// Reasoning makes the wet edges breathe without moving completed mountains.
	ink *= 0.88 + reasoning * 0.18 * noise(vec2(uv.x * 15.0 + elapsed * 0.08, uv.y * 11.0));
	ink *= 0.90 + (paper - 0.5) * 0.20;

	// A restrained cinnabar glow appears only as the run resolves.
	float sunset = peak(uv.x, 0.88, 0.045, 1.0) * peak(uv.y, 0.30, 0.07, 1.0) * completion;
	vec3 color = mix(ink_color.rgb, accent_color.rgb, sunset * 0.45);
	float alpha = clamp(pow(max(ink, 0.0), 0.82) * 1.12, 0.0, 0.88) + sunset * 0.10;
	COLOR = vec4(color, alpha);
}
