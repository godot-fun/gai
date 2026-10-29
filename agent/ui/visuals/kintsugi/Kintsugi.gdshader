shader_type canvas_item;

// Kintsugi: each crack splits the live interface into radial shards around one point. While open,
// shards slide outward over dark seams; once healed, lacquer flows from the center along the seams.
// crack_count == 0 and crackle == 0 = identity sample.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform int crack_count = 0;
// xy = center UV, z = radius in viewport-height units, w = seed.
uniform vec4 crack_shape[8];
// x = open spring (may overshoot), y = lacquer flow 0..1, z = vermilion mix, w = shard count.
uniform vec4 crack_state[8];
uniform float crackle : hint_range(0.0, 1.0) = 0.0;
uniform float crackle_seed = 0.0;
uniform float shard_shift_px = 18.0;
uniform float gap_px = 5.0;
uniform float seam_px = 1.8;
uniform float toolbar_height_px = 48.0;
uniform vec4 gap_color : source_color = vec4(0.03, 0.025, 0.02, 1.0);
uniform vec4 gold_color : source_color = vec4(0.92, 0.72, 0.30, 1.0);
uniform vec4 gold_highlight : source_color = vec4(1.0, 0.93, 0.64, 1.0);
uniform vec4 vermilion_color : source_color = vec4(0.89, 0.26, 0.17, 1.0);
uniform vec4 crackle_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform float crackle_gain : hint_range(0.0, 1.0) = 0.10;

float hash11(float n) {
	return fract(sin(n * 127.1 + 11.7) * 43758.5453);
}

// Piecewise-linear noise: straight segments with sharp corners read as fractures.
float value_noise(float x) {
	return mix(hash11(floor(x)), hash11(floor(x) + 1.0), fract(x));
}

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float voronoi_edge(vec2 x) {
	vec2 cell = floor(x);
	vec2 local = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(cell + g + vec2(crackle_seed));
			float d = length(g + o - local);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void fragment() {
	float fade = COLOR.a;
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 result = source;
	if (crack_count > 0 || crackle > 0.001) {
		float px = SCREEN_PIXEL_SIZE.y;
		float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 1e-6);
		vec2 to_uv = vec2(1.0 / aspect, 1.0);
		vec2 p = SCREEN_UV * vec2(aspect, 1.0);
		vec2 offset = vec2(0.0);
		float gap = 0.0;
		float shade = 1.0;
		vec3 lacquer = vec3(0.0);
		float lacquer_amount = 0.0;

		for (int index = 0; index < 8; index++) {
			if (index >= crack_count) {
				break;
			}
			vec4 shape = crack_shape[index];
			vec4 state = crack_state[index];
			float radius = max(shape.z, 0.01);
			float seed = shape.w;
			float open = state.x;
			float open_pos = max(open, 0.0);
			float flow = state.y;
			float shards = max(state.w, 2.0);
			vec2 q = p - shape.xy * vec2(aspect, 1.0);
			float r = length(q);
			if (r > radius * 1.3 + shard_shift_px * px) {
				continue;
			}
			float a = atan(q.y, q.x);
			float rn = r / radius;
			// Each seam takes its own jagged path; wander stays under a third of a shard so
			// re-picking the nearest seam mid-shard never changes the shard index.
			float s0 = ((a + 0.22 * sin(a * 2.0 + seed * 5.0)) + PI) / TAU * shards + seed;
			float seam = mod(floor(s0 + 0.5), shards);
			float seam_hash = hash11(seam * 7.31 + seed * 53.0);
			float jag = (value_noise(rn * 5.0 + seam_hash * 37.0) - 0.5) * 0.75 + (value_noise(rn * 16.0 + seam_hash * 91.0) - 0.5) * 0.25;
			float s = s0 + jag * 0.6;
			float sector = mod(floor(s), shards);
			float f = fract(s);
			float seam_dist = min(f, 1.0 - f) * TAU / shards * r;
			float shard_hash = hash11(sector + seed * 31.0);
			bool hairline = shards < 2.5;
			float mid = (sector + 0.5 - seed) / shards * TAU - PI;
			vec2 dir = vec2(cos(mid), sin(mid));

			float dist = seam_dist;
			float inner = 1.0;
			if (!hairline) {
				// Straight chords per shard make the inner pieces polygonal.
				float ring = radius * (0.26 + 0.16 * shard_hash);
				float along = dot(q, dir);
				dist = min(dist, abs(along - ring));
				inner = along < ring ? 0.45 : 1.0;
			}
			float seam_reach = radius * (0.62 + 0.38 * seam_hash);
			float reach_mask = 1.0 - smoothstep(seam_reach * 0.7, seam_reach, r);

			if (open_pos > 0.0005 || open < -0.0005) {
				float falloff = 1.0 - smoothstep(radius * 0.55, radius * 1.2, r);
				float shift = open * shard_shift_px * px * (0.6 + 0.4 * shard_hash) * inner * falloff;
				float tilt = open * 0.035 * (shard_hash - 0.5) * falloff;
				offset += dir * shift + vec2(-q.y, q.x) * tilt;
				shade *= 1.0 + (shard_hash - 0.5) * 0.14 * open_pos * falloff;
				float gap_half = open_pos * gap_px * px * (0.5 + 0.5 * rn) * reach_mask;
				float dark = 1.0 - smoothstep(gap_half, gap_half + px, dist);
				gap = max(gap, dark * smoothstep(0.0, 0.08, open_pos) * reach_mask);
			}

			if (flow > 0.0005) {
				float width = seam_px * px * (hairline ? 0.7 : 1.0) * (1.0 - 0.35 * rn);
				float line = 1.0 - smoothstep(width * 0.5, width * 0.5 + px * 1.1, dist);
				float halo = exp(-dist / (px * 4.0)) * 0.22;
				float front = flow * radius * 1.06;
				float reached = 1.0 - smoothstep(front - px * 6.0, front, r);
				float glow = exp(-abs(r - front) / (px * 14.0)) * (1.0 - flow);
				float shimmer = 0.88 + 0.12 * sin(r / px * 0.12 + seed * 9.0);
				float settled = 1.0 - smoothstep(0.1, 0.5, open_pos);
				float amount = max(line * shimmer, halo) * reached * reach_mask * settled;
				vec3 base = mix(gold_color.rgb, vermilion_color.rgb, state.z);
				vec3 tint = mix(base, gold_highlight.rgb, clamp(glow * (1.0 - 0.6 * state.z) + line * 0.18, 0.0, 1.0));
				if (amount > lacquer_amount) {
					lacquer_amount = amount;
					lacquer = tint;
				}
			}
		}

		vec2 sample_uv = clamp(SCREEN_UV - offset * to_uv, vec2(0.0), vec2(1.0));
		vec3 cracked = texture(screen_texture, sample_uv).rgb * shade;
		cracked = mix(cracked, gap_color.rgb, gap);
		cracked = mix(cracked, lacquer, clamp(lacquer_amount, 0.0, 1.0));
		if (crackle > 0.001) {
			float edge = 1.0 - smoothstep(0.0, 0.04, voronoi_edge(p * 7.0));
			cracked = mix(cracked, crackle_color.rgb, edge * crackle * crackle_gain);
		}
		float toolbar_uv = toolbar_height_px * SCREEN_PIXEL_SIZE.y;
		float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
		result = mix(source, cracked, body_mask);
	}
	COLOR = vec4(result, fade);
}
