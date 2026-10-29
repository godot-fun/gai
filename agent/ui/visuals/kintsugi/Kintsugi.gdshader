shader_type canvas_item;

// Kintsugi: each crack splits the live interface into radial shards around one point. A fresh
// break flashes and sends a shockwave; open shards slide outward as bevelled porcelain over dark
// seams; once healed, molten lacquer flows from the center and stays as glinting metal.
// crack_count == 0, crackle == 0 and zero shake = identity sample.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform int crack_count = 0;
// xy = center UV, z = radius in viewport-height units, w = seed.
uniform vec4 crack_shape[8];
// x = open spring (may overshoot), y = lacquer flow 0..1, z = vermilion mix, w = shard count.
uniform vec4 crack_state[8];
// x = impact 1..0 right after the break.
uniform vec4 crack_fx[8];
uniform float crackle : hint_range(0.0, 1.0) = 0.0;
uniform float crackle_seed = 0.0;
uniform vec2 shake_px = vec2(0.0);
uniform float shard_shift_px = 26.0;
uniform float gap_px = 7.0;
uniform float seam_px = 4.4;
uniform float aberration_px = 2.5;
uniform float shockwave_px = 14.0;
uniform vec4 gap_color : source_color = vec4(0.02, 0.016, 0.012, 1.0);
uniform vec4 gold_shadow : source_color = vec4(0.45, 0.28, 0.06, 1.0);
uniform vec4 gold_color : source_color = vec4(0.93, 0.71, 0.27, 1.0);
uniform vec4 gold_highlight : source_color = vec4(1.0, 0.95, 0.74, 1.0);
uniform vec4 vermilion_color : source_color = vec4(0.89, 0.24, 0.14, 1.0);
uniform vec4 crackle_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform float crackle_gain : hint_range(0.0, 1.0) = 0.10;
// Additive bloom strength: full on dark surfaces, reduced on light ones where it washes out.
uniform float bloom_gain : hint_range(0.0, 1.0) = 1.0;

const vec2 TO_LIGHT = vec2(-0.6, -0.8);

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
	bool shaking = abs(shake_px.x) + abs(shake_px.y) > 0.01;
	if (crack_count > 0 || crackle > 0.001 || shaking) {
		float px = SCREEN_PIXEL_SIZE.y;
		float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 1e-6);
		vec2 to_uv = vec2(1.0 / aspect, 1.0);
		vec2 to_light = normalize(TO_LIGHT);
		vec2 p = SCREEN_UV * vec2(aspect, 1.0);
		vec2 offset = shake_px * px;
		vec2 aberration = vec2(0.0);
		float gap = 0.0;
		float gap_depth = 0.0;
		float shade = 1.0;
		float bevel = 0.0;
		vec3 lacquer = vec3(0.0);
		float lacquer_amount = 0.0;
		vec3 bloom = vec3(0.0);

		for (int index = 0; index < 8; index++) {
			if (index >= crack_count) {
				break;
			}
			vec4 shape = crack_shape[index];
			vec4 state = crack_state[index];
			float impact = crack_fx[index].x;
			float radius = max(shape.z, 0.01);
			float seed = shape.w;
			float open = state.x;
			float open_pos = max(open, 0.0);
			float flow = state.y;
			float vermilion = state.z;
			float shards = max(state.w, 2.0);
			vec2 q = p - shape.xy * vec2(aspect, 1.0);
			float r = length(q);
			vec2 radial = q / max(r, 1e-5);

			if (impact > 0.001) {
				// White-hot flash at the point of failure plus a refracting shockwave beyond the shards.
				float wave_r = (1.0 - impact) * radius * 2.2;
				float wave = exp(-pow((r - wave_r) / (px * 11.0), 2.0)) * impact * impact;
				offset += radial * wave * shockwave_px * px;
				bloom += vec3(1.0, 0.92, 0.78) * (exp(-r / (radius * 0.07)) * impact * impact * impact * 1.3 + wave * 0.05);
			}
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
			// Normal from the nearest seam into this pixel's shard.
			vec2 tangent = vec2(-radial.y, radial.x);
			vec2 normal = f < 0.5 ? tangent : -tangent;

			float dist = seam_dist;
			float inner = 1.0;
			if (!hairline) {
				// Straight chords per shard make the inner pieces polygonal.
				float ring = radius * (0.26 + 0.16 * shard_hash);
				float along = dot(q, dir);
				float ring_dist = abs(along - ring);
				if (ring_dist < dist) {
					dist = ring_dist;
					normal = along < ring ? -dir : dir;
				}
				inner = along < ring ? 0.45 : 1.0;
			}
			float seam_reach = radius * (0.62 + 0.38 * seam_hash);
			float reach_mask = 1.0 - smoothstep(seam_reach * 0.7, seam_reach, r);
			float light_side = dot(-normal, to_light);

			if (open_pos > 0.0005 || open < -0.0005) {
				float falloff = 1.0 - smoothstep(radius * 0.55, radius * 1.2, r);
				float shift = open * shard_shift_px * px * (0.6 + 0.4 * shard_hash) * inner * falloff;
				float tilt = open * 0.035 * (shard_hash - 0.5) * falloff;
				offset += dir * shift + vec2(-q.y, q.x) * tilt;
				aberration += dir * open_pos * aberration_px * px * falloff;
				shade *= 1.0 + (shard_hash - 0.5) * 0.18 * open_pos * falloff;
				float gap_half = open_pos * gap_px * px * (0.5 + 0.5 * rn) * reach_mask;
				float visible_open = smoothstep(0.0, 0.08, open_pos) * reach_mask;
				float dark = (1.0 - smoothstep(gap_half, gap_half + px, dist)) * visible_open;
				if (dark > gap) {
					gap = dark;
					gap_depth = clamp(1.0 - dist / max(gap_half, px), 0.0, 1.0);
				}
				// Porcelain thickness: the lit rim faces the light, the far rim falls into shadow.
				float rim_width = px * (1.5 + 3.0 * open_pos);
				float rim = (1.0 - smoothstep(gap_half, gap_half + rim_width, dist)) * (1.0 - dark) * visible_open;
				bevel += rim * light_side * 0.9;
			}

			if (flow > 0.0005) {
				float vein = seam_px * px * (hairline ? 0.55 : 1.0) * (1.25 - 0.55 * rn) * (0.7 + 0.6 * value_noise(rn * 7.0 + seam_hash * 13.0));
				float half_width = vein * 0.5;
				float front = flow * radius * 1.06;
				float molten = exp(-abs(r - front) / (px * 9.0)) * (1.0 - flow);
				half_width += molten * px * 1.6;
				float coverage = 1.0 - smoothstep(half_width, half_width + px * 1.1, dist);
				float reached = 1.0 - smoothstep(front - px * 4.0, front, r);
				float settled = 1.0 - smoothstep(0.1, 0.5, open_pos);
				float presence = reached * reach_mask * settled;

				// Tube profile across the vein: dark rolled edges, bright crest offset toward the light.
				float across = clamp(dist / max(half_width, px * 0.5), 0.0, 1.0);
				float crest = 1.0 - across * across;
				float lit = clamp(0.55 + 0.45 * light_side * across, 0.0, 1.0);
				vec3 shadow_tone = mix(gold_shadow.rgb, vermilion_color.rgb * 0.45, vermilion);
				vec3 body_tone = mix(gold_color.rgb, vermilion_color.rgb, vermilion);
				vec3 metal = mix(shadow_tone, body_tone, crest * lit);
				float specular = pow(crest, 6.0) * lit;
				// Glints sweep outward along each vein, staggered so the scar keeps shimmering.
				float sweep = fract(TIME * 0.22 + seam_hash * 3.7 + seed);
				float glint = exp(-pow((rn - sweep * 1.3) * 9.0, 2.0));
				vec2 cell = floor(FRAGCOORD.xy / 2.0);
				float sparkle_seed = hash11(dot(cell, vec2(1.0, 157.0)));
				float sparkle = step(0.965, sparkle_seed) * pow(max(sin(TIME * 3.0 + sparkle_seed * 60.0), 0.0), 12.0);
				float shine = clamp(specular * 0.55 + glint * 0.8 + sparkle + molten * 1.4, 0.0, 1.0) * (1.0 - 0.55 * vermilion);
				metal = mix(metal, gold_highlight.rgb, shine);
				float amount = coverage * presence;
				if (amount > lacquer_amount) {
					lacquer_amount = amount;
					lacquer = metal;
				}
				float halo = exp(-dist / (px * 5.0)) * 0.14 + exp(-dist / (px * 18.0)) * 0.04;
				bloom += body_tone * halo * presence * (1.0 + glint * 2.0);
				bloom += gold_highlight.rgb * molten * exp(-dist / (px * 6.0)) * reach_mask * 0.8;
			}
		}

		vec2 sample_uv = SCREEN_UV - offset * to_uv;
		vec2 split = aberration * to_uv;
		vec3 cracked = vec3(
			texture(screen_texture, clamp(sample_uv - split, vec2(0.0), vec2(1.0))).r,
			texture(screen_texture, clamp(sample_uv, vec2(0.0), vec2(1.0))).g,
			texture(screen_texture, clamp(sample_uv + split, vec2(0.0), vec2(1.0))).b
		) * shade;
		cracked = clamp(cracked + vec3(max(bevel, 0.0)) * 0.55, 0.0, 1.0) * (1.0 + min(bevel, 0.0) * 0.6);
		vec3 gap_tone = mix(gap_color.rgb * 2.2, gap_color.rgb * 0.4, gap_depth);
		cracked = mix(cracked, gap_tone, gap);
		cracked = mix(cracked, lacquer, clamp(lacquer_amount, 0.0, 1.0));
		cracked += bloom * bloom_gain;
		if (crackle > 0.001) {
			float edge = 1.0 - smoothstep(0.0, 0.04, voronoi_edge(p * 7.0));
			cracked = mix(cracked, crackle_color.rgb, edge * crackle * crackle_gain);
		}
		result = clamp(cracked, 0.0, 1.0);
	}
	COLOR = vec4(result, fade);
}
