shader_type canvas_item;

// Stained-glass window over the live interface. A jittered Voronoi tiling is leaded with bevelled
// came; lit panes filter the interface through jewel-toned glass with streaks, seeds, slight
// refraction and darker edges where the glass thickens at the lead. A drifting sun brightens the
// panes near it. Tool panes glow, and failed ones crack into displaced shards. Light themes filter
// the page like colored glass laid on paper; dark themes let the panes emit their color.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float cloud : hint_range(0.0, 1.0) = 0.0;
uniform float flare : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform vec2 sun = vec2(0.5, 0.1);
uniform float glass_time = 0.0;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform int pane_count = 0;
// (uv.x, uv.y, glow, error)
uniform vec4 pane_point[8];
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

const float CELL = 0.095;
const float LEAD_HALF_PX = 2.4;
const float CRACK_RAYS = 7.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0)), u.x), u.y);
}

vec2 site(vec2 cell) {
	return hash22(cell) * 0.76 + 0.12;
}

vec2 nearest_cell(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float best = 8.0;
	vec2 id = n;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + site(n + g) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				id = n + g;
			}
		}
	}
	return id;
}

// Returns (distance to the cell border, cell id) in cell units.
vec3 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + site(n + g) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				mr = r;
				mg = g;
			}
		}
	}
	float border = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + site(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				border = min(border, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(border, n + mg);
}

vec3 jewel(float h) {
	int index = int(floor(h * 7.0));
	if (index == 0) return vec3(0.78, 0.12, 0.2);
	if (index == 1) return vec3(0.12, 0.3, 0.82);
	if (index == 2) return vec3(0.1, 0.62, 0.36);
	if (index == 3) return vec3(0.96, 0.66, 0.14);
	if (index == 4) return vec3(0.52, 0.2, 0.74);
	if (index == 5) return vec3(0.08, 0.6, 0.66);
	return accent_color.rgb;
}

void fragment() {
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	vec3 result = original;
	if (presence > 0.001) {
		vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
		float aspect = viewport_px.x / max(viewport_px.y, 1.0);
		float cell_px = CELL * viewport_px.y;
		vec2 p = SCREEN_UV * vec2(aspect, 1.0) / CELL;
		vec3 vor = voronoi(p);
		vec2 id = vor.yz;
		float border_px = vor.x * cell_px;
		float cell_hash = hash12(id);

		float lit = smoothstep(cell_hash - 0.04, cell_hash + 0.04, fill * 1.08 - 0.04);
		float glow = 0.0;
		float error = 0.0;
		vec2 impact = vec2(0.0);
		for (int index = 0; index < pane_count; index++) {
			vec4 pane = pane_point[index];
			if (nearest_cell(pane.xy * vec2(aspect, 1.0) / CELL) == id) {
				lit = 1.0;
				glow = max(glow, pane.z);
				error = max(error, pane.w);
				impact = pane.xy;
			}
		}

		// Cracked shards: each angular sector around the impact shifts on its own.
		vec2 to_impact = (SCREEN_UV - impact) * viewport_px;
		float impact_r = length(to_impact);
		float impact_a = atan(to_impact.y, to_impact.x);
		float sector = floor(impact_a / TAU * CRACK_RAYS + cell_hash * 5.0);
		vec2 shard_shift = (hash22(vec2(sector, cell_hash * 31.0)) - 0.5) * 7.0 * error;

		vec2 wobble = vec2(value_noise(p * 3.1 + 4.0), value_noise(p * 3.1 + 9.0)) - 0.5;
		vec2 offset = (wobble * 3.0 * lit + shard_shift) * SCREEN_PIXEL_SIZE;
		vec3 source = texture(screen_texture, SCREEN_UV + offset).rgb;

		float streak_angle = cell_hash * TAU;
		vec2 streak_dir = vec2(cos(streak_angle), sin(streak_angle));
		float streak = 0.5 + 0.5 * sin(dot(p, streak_dir) * 11.0 + value_noise(p * 2.0 + cell_hash * 13.0) * 4.0);
		vec2 seed_grid = SCREEN_UV * viewport_px / 9.0;
		float seed_dot = step(0.965, hash12(floor(seed_grid) + id * 7.0)) * smoothstep(0.32, 0.12, length(fract(seed_grid) - 0.5));
		float thick = smoothstep(cell_px * 0.18, 0.0, border_px);

		vec3 tint = jewel(hash12(id * 1.7 + 19.3));
		tint = mix(tint, error_color.rgb, max(error * 0.7, failure_tint * 0.3));
		vec2 to_sun = (SCREEN_UV - sun) * vec2(aspect, 1.0);
		float sun_light = exp(-dot(to_sun, to_sun) * 2.2) * (1.0 - cloud * 0.75) + flare * 0.6;

		float crack = 0.0;
		if (error > 0.0) {
			float ray_px = abs(fract(impact_a / TAU * CRACK_RAYS + cell_hash * 5.0) - 0.5) * TAU / CRACK_RAYS * impact_r;
			float ring_px = abs(impact_r - cell_px * (0.28 + cell_hash * 0.12));
			crack = (1.0 - smoothstep(0.4, 1.4, min(ray_px, ring_px))) * error * step(4.0, impact_r);
		}

		vec3 glass;
		if (light_mode > 0.5) {
			float amount = tint_strength * lit * (0.82 + 0.18 * streak) * (1.0 - sun_light * 0.3);
			vec3 filter_color = mix(vec3(1.0), tint, amount) * (1.0 - thick * 0.14 * lit);
			glass = source * filter_color;
			glass = mix(glass, glass * 0.82 + tint * 0.2, glow * 0.5);
			glass *= 1.0 - cloud * 0.05;
			glass = mix(glass, vec3(1.0), seed_dot * 0.5 * lit);
			glass = mix(glass, vec3(0.2, 0.2, 0.22), crack * 0.8);
		} else {
			float amount = tint_strength * lit;
			glass = source * mix(vec3(1.0), tint, amount) * mix(0.94, 1.0, lit);
			glass += tint * lit * (0.05 + 0.2 * sun_light + 0.32 * glow) * (0.75 + 0.25 * streak) * (1.0 - thick * 0.5);
			glass += vec3(seed_dot) * 0.12 * lit;
			glass = mix(glass, vec3(0.92), crack * 0.75);
		}

		float scale = viewport_px.y / 1440.0;
		float half_px = LEAD_HALF_PX * max(scale, 0.5);
		float lead = 1.0 - smoothstep(half_px - 0.7, half_px + 0.7, border_px);
		float bevel = sqrt(max(1.0 - pow(border_px / half_px, 2.0), 0.0));
		vec3 came = (light_mode > 0.5 ? vec3(0.13, 0.13, 0.15) : vec3(0.05, 0.05, 0.06)) + vec3(bevel * bevel * 0.16);
		glass = mix(glass, came, lead * mix(0.4, 0.9, lit));
		result = mix(original, glass, presence);
	}
	COLOR = vec4(result, 1.0);
}
