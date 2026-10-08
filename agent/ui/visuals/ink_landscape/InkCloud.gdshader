shader_type canvas_item;
render_mode unshaded;

uniform vec4 cloud_color : source_color = vec4(0.94, 0.945, 0.925, 1.0);
uniform vec4 ink_color : source_color = vec4(0.10, 0.12, 0.105, 1.0);
uniform float elapsed = 0.0;
uniform float presence : hint_range(0.0, 1.0) = 0.6;
uniform float layer_index : hint_range(0.0, 2.0) = 0.0;
// Shared across three passes. Modulo-3 depth assignment makes each cloud run in
// exactly one pass instead of being shaded three times.
uniform float cloud_reveal : hint_range(0.0, 16.0) = 0.0;
// Multiply final alpha explicitly because this shader overwrites COLOR.
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

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
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.04 + vec2(13.7, 8.3);
		amplitude *= 0.48;
	}
	return value;
}

float cloud_wisp(vec2 uv, vec2 center, vec2 size, float seed, float speed) {
	// Ink-wash cloud: a long eroded stroke with no closed cartoon silhouette.
	float drift = sin(elapsed * speed + seed) * 0.010;
	vec2 p = (uv - center - vec2(drift, 0.0)) / size;
	float bend = (noise(vec2(p.x * 1.7 + seed, seed * 2.3)) - 0.5) * 0.72;
	float vertical = abs(p.y - bend);
	float taper = smoothstep(1.18, 0.34, abs(p.x));
	float coarse = fbm(vec2(p.x * 2.8 + seed * 4.1, p.y * 2.1 - seed));
	float fibers = fbm(vec2(p.x * 8.5 - seed, p.y * 5.4 + seed * 3.0));
	float stroke = exp(-vertical * mix(2.0, 3.8, coarse)) * taper;
	float eroded = stroke * mix(0.50, 1.08, coarse) + (fibers - 0.52) * 0.30;
	float body = smoothstep(0.16, 0.68, eroded);
	// Sparse lower filaments make the bank dissolve like wet ink on paper.
	float filament = exp(-abs(p.y - bend - 0.42) * 8.0) * taper * smoothstep(0.48, 0.76, fibers) * 0.38;
	return clamp(body + filament, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	// Clouds are revealed one by one. Their procedural depth assignment lets each
	// new wash sit behind, among, or in front of different mountain ranges.
	float cloud = 0.0;
	for (int index = 0; index < 16; index++) {
		float serial = float(index);
		float depth_layer = mod(serial, 3.0);
		float growth = smoothstep(0.0, 1.0, clamp(cloud_reveal - serial, 0.0, 1.0));
		if (growth <= 0.001 || abs(depth_layer - layer_index) > 0.25) {
			continue;
		}
		float random_x = hash21(vec2(serial + 1.7, 4.3));
		float random_size = hash21(vec2(serial + 8.1, 9.7));
		float y = mix(0.34, 0.46, hash21(vec2(serial, 2.1)));
		float width = mix(0.15, 0.22, random_size);
		float height = mix(0.040, 0.058, random_size);
		float strength = mix(0.38, 0.52, random_size);
		if (depth_layer > 0.5) {
			y = mix(0.53, 0.70, hash21(vec2(serial, 5.4)));
			width = mix(0.20, 0.30, random_size);
			height = mix(0.062, 0.088, random_size);
			strength = mix(0.58, 0.76, random_size);
		}
		if (depth_layer > 1.5) {
			y = mix(0.72, 0.88, hash21(vec2(serial, 7.8)));
			width = mix(0.26, 0.38, random_size);
			height = mix(0.086, 0.118, random_size);
			strength = mix(0.76, 0.94, random_size);
		}
		vec2 center = vec2(mix(0.08, 0.92, random_x), y);
		// Reject pixels outside this cloud before any FBM work. Without this guard,
		// every transparent pixel evaluated two noise stacks for every visible cloud.
		if (abs(uv.x - center.x) > width * 1.35 || abs(uv.y - center.y) > height * 1.65) {
			continue;
		}
		// A new cloud begins as a pale short stroke, then spreads sideways like
		// diluted ink soaking into paper instead of popping into existence.
		vec2 grown_size = vec2(width * mix(0.30, 1.0, growth), height * mix(0.62, 1.0, growth));
		float grown_cloud = cloud_wisp(uv, center, grown_size, serial * 1.73 + 1.2, 0.25 + depth_layer * 0.06);
		cloud = max(cloud, grown_cloud * strength * growth);
	}
	cloud = clamp(cloud * presence, 0.0, 1.0);
	if (cloud <= 0.001) {
		discard;
	}
	float fibers = fbm(uv * vec2(34.0, 18.0) + vec2(elapsed * 0.004, 0.0));
	float depth_alpha = mix(0.62, 1.0, layer_index * 0.5);
	float alpha = cloud * mix(0.48, 0.82, smoothstep(0.12, 0.78, cloud)) * depth_alpha;
	alpha *= 0.90 + (fibers - 0.5) * 0.20;
	// A faint grey underside makes the white/black cloud mass readable in either theme.
	float underside = smoothstep(0.36, 0.92, cloud) * (0.035 + fibers * 0.025);
	vec3 color = mix(cloud_color.rgb, ink_color.rgb, underside);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.84) * fade_alpha);
}
