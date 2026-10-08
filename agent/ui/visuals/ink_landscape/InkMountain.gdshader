shader_type canvas_item;
render_mode unshaded;

uniform vec4 ink_color : source_color = vec4(0.10, 0.12, 0.105, 1.0);
uniform vec4 background_color : source_color = vec4(0.96, 0.96, 0.95, 1.0);
uniform float center : hint_range(0.0, 1.0) = 0.5;
uniform float mountain_width : hint_range(0.01, 0.25) = 0.08;
uniform float mountain_height : hint_range(0.02, 0.6) = 0.2;
uniform float base : hint_range(0.0, 1.2) = 0.7;
uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float depth : hint_range(0.0, 1.0) = 0.5;
uniform float shape : hint_range(0.0, 4.0) = 0.0;
uniform float seed = 1.0;
uniform float growth : hint_range(0.0, 1.0) = 0.0;
// The ColorRect is cropped to mountain_bounds(); reconstruct full-viewport UV
// so all mountain parameters remain normalized to the complete screen.
uniform vec2 uv_origin = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
// Multiply final alpha explicitly because this shader overwrites COLOR.
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float dark_theme : hint_range(0.0, 1.0) = 0.0;

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
	for (int i = 0; i < 3; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.48;
	}
	return value;
}

float rounded_peak(float x, float peak_center, float width, float height) {
	float q = (x - peak_center) / width;
	return exp(-q * q * 0.72) * height;
}

float profile(float x) {
	float q = (x - center) / mountain_width;
	float result = 0.0;
	if (shape < 0.5) {
		result = rounded_peak(x, center, mountain_width * 1.7, 0.72);
		result += rounded_peak(x, center - mountain_width * 1.7, mountain_width * 1.15, 0.20);
		result += rounded_peak(x, center + mountain_width * 1.9, mountain_width * 1.35, 0.17);
	} else if (shape < 1.5) {
		result = rounded_peak(x, center - mountain_width * 1.4, mountain_width * 1.2, 0.34);
		result += rounded_peak(x, center, mountain_width, 0.60);
		result += rounded_peak(x, center + mountain_width * 1.5, mountain_width * 1.45, 0.29);
	} else if (shape < 2.5) {
		result = rounded_peak(x, center - mountain_width * 0.62, mountain_width * 0.7, 0.84);
		result += rounded_peak(x, center + mountain_width * 0.68, mountain_width * 0.8, 0.68);
	} else if (shape < 3.5) {
		// An asymmetric but differentiable summit: both sides meet with a rounded cap.
		float left_slope = exp(-q * q * 0.52);
		float right_slope = exp(-q * q * 1.55);
		result = mix(left_slope, right_slope, step(0.0, q));
		result += rounded_peak(x, center - mountain_width * 1.3, mountain_width * 0.9, 0.22);
	} else {
		// Principal peaks may be steep, but never mathematically pointed.
		result = rounded_peak(x, center, mountain_width * 0.72, 0.88);
		result += rounded_peak(x, center - mountain_width * 1.2, mountain_width * 0.9, 0.25);
		result += rounded_peak(x, center + mountain_width * 1.3, mountain_width, 0.20);
	}
	float rock = (noise(vec2(x * 45.0, seed * 9.0)) - 0.5) * mix(0.02, 0.065, depth);
	return max(result + rock, 0.0);
}

void fragment() {
	vec2 uv = uv_origin + UV * uv_scale;
	float grown = smoothstep(0.0, 1.0, growth);
	float height = base - profile(uv.x) * mountain_height * (0.16 + grown * 0.84);
	float texture = fbm(vec2(uv.x * 31.0 + seed, uv.y * 17.0 + seed * 0.7));
	float edge_noise = (texture - 0.5) * mix(0.007, 0.019, depth);
	float edge_distance = uv.y - height;
	float body = smoothstep(-0.01 - softness * 0.014, 0.022 + softness * 0.03 + edge_noise, edge_distance);
	body *= smoothstep(base + 0.065, base - 0.025, uv.y);
	float wet_edge = exp(-abs(edge_distance + edge_noise) * mix(150.0, 76.0, softness)) * mix(0.20, 0.58, depth);
	// Light paper supports a concentrated wet rim. On a dark canvas that same
	// value reads as neon, so retain only a restrained broken highlight.
	wet_edge *= mix(1.0, 0.28 + texture * 0.16, dark_theme);
	float grain = clamp(texture * 0.78 + noise(vec2(uv.x * 67.0, uv.y * 29.0 + seed * 2.7)) * 0.22, 0.0, 1.0);
	float local_distance = abs(uv.x - center) / max(mountain_width * mix(4.8, 3.5, depth), 0.001);
	float bloom = smoothstep(grown + 0.14, grown - 0.10, local_distance);
	float coverage = body * bloom * grown;
	float ink = (body * (0.39 + grain * mix(0.14, 0.31, depth)) + wet_edge) * strength * bloom * grown;

	// Interior structure: sparse diagonal creases descend from the summit while
	// broken contour strokes suggest traditional cun texture. Keep distant ranges
	// restrained; foreground mountains carry most of the brush information.
	float mountain_span = max(base - height, 0.001);
	float down_slope = clamp((uv.y - height) / mountain_span, 0.0, 1.0);
	float normalized_x = (uv.x - center) / max(mountain_width, 0.001);
	float structure_noise = fbm(vec2(normalized_x * 1.7 + seed * 2.1, down_slope * 3.4 - seed));
	float crease_wave = abs(sin(normalized_x * 4.4 + down_slope * 7.2 + seed + (structure_noise - 0.5) * 5.2));
	float crease_breaks = smoothstep(0.45, 0.72, noise(vec2(normalized_x * 3.1 + seed, down_slope * 9.0)));
	float creases = pow(1.0 - crease_wave, 22.0) * crease_breaks;
	float contour_wave = abs(sin(down_slope * 25.0 + normalized_x * 1.3 + seed * 0.7 + structure_noise * 4.0));
	float contour_breaks = smoothstep(0.52, 0.76, noise(vec2(normalized_x * 5.2 - seed, down_slope * 12.0)));
	float contours = pow(1.0 - contour_wave, 26.0) * contour_breaks * smoothstep(0.44, 0.82, grain);
	// Keep texture away from the silhouette and the opaque foot so the mountain's
	// principal outline remains visually dominant.
	float interior_mask = smoothstep(0.018, 0.070, edge_distance) * (1.0 - smoothstep(0.82, 1.0, down_slope));
	float texture_detail = (creases * 0.085 + contours * 0.055) * body * bloom * grown * interior_mask * smoothstep(0.25, 0.92, depth);
	ink += texture_detail * strength;

	// More distant layers meet higher, thinner fog; foreground layers retain more body.
	float fog_y = mix(0.48, 0.78, depth) + sin(uv.x * mix(8.0, 4.5, depth) + seed) * 0.015;
	float fog = exp(-abs(uv.y - fog_y) * mix(50.0, 31.0, depth));
	ink *= 1.0 - fog * mix(0.66, 0.38, depth);
	float ink_alpha = clamp(pow(max(ink, 0.0), 0.86) * 1.08, 0.0, mix(0.16, 0.80, depth));
	// Keep enough translucency for layered ink washes, but make nearer mountains
	// substantially more occlusive so a rear silhouette does not read as a line
	// drawn across their body. Full opacity made the composition look like flat
	// grey cutouts and removed the atmospheric overlap between ranges.
	float occlusion_strength = mix(0.78, 0.96, smoothstep(0.08, 0.96, depth));
	float occlusion_alpha = coverage * occlusion_strength;
	// Slightly lighter left slope and darker right slope establish readable volume.
	float slope_shade = smoothstep(-0.65, 0.85, normalized_x) * mix(0.04, 0.18, depth);
	float wash = clamp(strength * (0.34 + grain * 0.34 + slope_shade) + texture_detail * mix(0.28, 0.72, depth), 0.0, 0.72);
	vec3 body_color = mix(background_color.rgb, ink_color.rgb, wash);
	vec3 final_color = mix(body_color, ink_color.rgb, clamp(wet_edge * strength * 1.8, 0.0, 1.0));
	COLOR = vec4(final_color, max(ink_alpha, occlusion_alpha) * fade_alpha);
}
