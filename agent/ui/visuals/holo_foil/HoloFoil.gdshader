shader_type canvas_item;

// Holographic foil laminated over the live interface. A mosaic of diffraction-grating cells
// splits light into spectra that shift as the card tilts; glitter flakes flash when their facet
// faces the light, and a bright band rolls across on sweeps. Seals are stamped guilloche
// holograms. Dark themes add the spectrum like light; light themes tint it in like foil ink.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.3;
uniform vec2 tilt = vec2(0.0);
uniform float sweep = -1.0;
uniform float foil_time = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float base_gain : hint_range(0.0, 1.0) = 0.16;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform int seal_count = 0;
// (uv.x, uv.y, radius in viewport heights, seed)
uniform vec4 seal_shape[8];
// (stamp 0..1, glow, error, age seconds)
uniform vec4 seal_state[8];
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

const float CELL = 0.022;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 spectrum(float t) {
	return 0.5 + 0.5 * cos(TAU * (t + vec3(0.0, 0.33, 0.67)));
}

// Hexagonal cell id and local offset for the grating mosaic.
vec4 hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	// Centers sit on a half-lattice; snapping them keeps the id hash stable across a cell.
	return vec4(g, round((p - g) / h));
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float aspect = viewport_px.x / max(viewport_px.y, 1.0);
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float live = presence * body_mask;
	vec3 result = source;
	if (live > 0.001) {
		vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
		vec4 cell = hex_cell(p / CELL);
		float cell_hash = hash12(cell.zw);
		float grating_angle = cell_hash * TAU;
		vec2 grating = vec2(cos(grating_angle), sin(grating_angle));
		// Each cell diffracts a different order: its hue depends on how the tilt meets its grating.
		float phase = dot(p, vec2(0.62, 0.78)) * 0.9 + tilt.x * 0.55 - tilt.y * 0.35 + dot(tilt, grating) * 0.04;
		vec3 foil = spectrum(phase);
		float facet = 0.5 + 0.5 * cos(TAU * (dot(tilt, grating) * 0.5 + cell_hash));
		float edge = smoothstep(0.38, 0.5, length(cell.xy));

		float tilt_band = dot(p, vec2(0.8, 0.6)) - dot(tilt, vec2(0.8, 0.6)) * 0.9;
		float band = pow(0.5 + 0.5 * cos(tilt_band * 2.6), 14.0);
		float sweep_offset = (dot(p, normalize(vec2(1.0, 0.45))) / (aspect * 0.5 + 0.3) - (sweep * 2.6 - 1.3)) * 6.0;
		float sweep_band = exp(-sweep_offset * sweep_offset);
		float relief = 0.82 + facet * 0.18;
		float strength = (base_gain * sheen + band * 0.24 * sheen + sweep_band * 0.42) * relief;

		vec2 flake_grid = SCREEN_UV * viewport_px / 6.0;
		vec2 flake_id = floor(flake_grid);
		float flake_angle = hash12(flake_id) * TAU;
		float flake = step(0.94, hash12(flake_id + 7.1));
		float flake_face = pow(max(cos(flake_angle - atan(tilt.y, tilt.x) - foil_time * 0.2), 0.0), 60.0);
		float flake_shape = smoothstep(0.45, 0.0, length(fract(flake_grid) - 0.5));
		float glitter = flake * flake_face * flake_shape * (0.25 + sheen * 0.75) * (0.4 + band + sweep_band);

		vec3 seal_color = vec3(0.0);
		float seal_mask = 0.0;
		float seal_outline = 0.0;
		for (int index = 0; index < seal_count; index++) {
			vec4 shape = seal_shape[index];
			vec4 state = seal_state[index];
			float stamp = state.x;
			float scale = mix(1.6, 1.0, 1.0 - pow(1.0 - stamp, 3.0));
			vec2 d = (SCREEN_UV - shape.xy) * vec2(aspect, 1.0) / (shape.z * scale);
			float r = length(d);
			if (r > 1.08) {
				continue;
			}
			float angle = atan(d.y, d.x);
			float guilloche = pow(0.5 + 0.5 * sin(r * 54.0 + sin(angle * 9.0 + shape.w * 6.0) * 1.6), 4.0);
			float rays = pow(0.5 + 0.5 * cos(angle * 24.0), 8.0) * smoothstep(0.2, 0.5, r);
			float disc = smoothstep(1.0, 0.97, r);
			float ring = smoothstep(0.8, 0.83, r) * smoothstep(0.9, 0.87, r);
			float crack = state.z * step(0.94, fract(sin(floor(angle * 5.0 + shape.w * 9.0) * 91.7) * 437.0 + r * 2.0));
			float pattern = clamp(guilloche * 0.7 + rays * 0.5 + ring, 0.0, 1.0);
			vec3 c = spectrum(r * 0.9 + dot(tilt, d) * 0.7 + phase * 0.5 + shape.w);
			c = mix(c, error_color.rgb, state.z * 0.75);
			float alpha = disc * stamp * (0.3 + 0.7 * pattern) * (0.6 + 0.4 * state.y) * (1.0 - crack);
			seal_color = mix(seal_color, c, alpha);
			seal_mask = max(seal_mask, alpha);
			seal_outline = max(seal_outline, (smoothstep(0.95, 0.98, r) * smoothstep(1.03, 1.0, r)) * stamp);
		}

		vec3 tint = mix(foil, error_color.rgb, failure_tint * 0.6);
		strength = clamp(strength + failure_tint * 0.2, 0.0, 1.0) * (1.0 - edge * 0.3);
		if (light_mode > 0.5) {
			vec3 ink = mix(vec3(1.0), tint * 0.75 + 0.12, strength);
			result = source * ink;
			result = mix(result, result * (seal_color * 0.8 + 0.1), seal_mask * 0.75);
			result *= 1.0 - seal_outline * 0.35;
			result = mix(result, vec3(1.0), glitter * 0.8);
			result = mix(result, mix(result, tint * 0.6, 0.5), glitter * 0.4);
		} else {
			result = vec3(1.0) - (vec3(1.0) - source) * (vec3(1.0) - tint * strength);
			result = mix(result, max(result, seal_color), seal_mask * 0.85);
			result += seal_color * seal_outline * 0.4;
			result += mix(vec3(1.0), tint, 0.4) * glitter;
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
