shader_type canvas_item;

// Disintegrate: burns eat ragged holes into the interface with an ember edge, and the content
// they consume blows away as ash on the wind. Each pixel looks upwind for grains that dissolved
// exactly long enough ago to have drifted here, so running a burn's progress backwards plays the
// ash flying home and the content reassembling. Embers rise faintly from below while text streams.
// No burns and no embers is an identity pass.

const int MAX_BURNS = 4;
const int ASH_STEPS = 12;
const float ASH_STEP_SECONDS = 0.11;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float field_time = 0.0;
uniform int burn_count = 0;
// xy = center UV, z = radius in viewport-height units, w = seed.
uniform vec4 burn_shapes[4];
// x = progress (dissolve threshold), y = burn speed in progress per second.
uniform vec4 burn_state[4];
// Viewport heights per second.
uniform vec2 wind = vec2(0.16, -0.22);
uniform float ember_level : hint_range(0.0, 1.0) = 0.0;
uniform float grain_px = 2.0;
uniform float ash_density : hint_range(0.0, 1.0) = 0.55;
uniform vec4 char_color : source_color = vec4(0.06, 0.05, 0.05, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 ember_core : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform vec4 ash_color : source_color = vec4(0.42, 0.40, 0.38, 1.0);
uniform float glow_gain : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 s = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), s.x), mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0, 1.0)), s.x), s.y);
}

// Dissolve order around a burn: near the center and in low-noise patches first.
float dissolve_order(vec2 p, vec2 center, float radius, float seed) {
	vec2 q = (p - center) / radius;
	float noise = value_noise(p * 9.0 + seed * 17.0) * 0.6 + value_noise(p * 31.0 + seed * 5.0) * 0.4;
	return length(q) + (noise - 0.5) * 0.7;
}

vec2 ash_drift(float tau, vec2 p) {
	vec2 sway = vec2(sin(tau * 4.0 + p.y * 9.0), cos(tau * 3.1 + p.x * 8.0)) * 0.02 * tau;
	return wind * tau * (1.0 + 0.6 * tau) + sway;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float view_aspect = viewport_px.x / max(viewport_px.y, 1.0);
	vec2 to_uv = vec2(1.0 / view_aspect, 1.0);
	vec2 p = SCREEN_UV * vec2(view_aspect, 1.0);
	vec3 result = source;
	if (burn_count > 0 || ember_level > 0.001) {
		vec3 burned = source;
		vec3 glow = vec3(0.0);
		float ash_alpha = 0.0;
		vec3 ash = vec3(0.0);
		float max_tau = ASH_STEP_SECONDS * float(ASH_STEPS);
		vec2 max_drift = ash_drift(max_tau, p);

		for (int index = 0; index < MAX_BURNS; index++) {
			if (index >= burn_count) {
				break;
			}
			vec4 shape = burn_shapes[index];
			float progress = burn_state[index].x;
			float speed = max(burn_state[index].y, 0.01);
			vec2 center = shape.xy * vec2(view_aspect, 1.0);
			float radius = max(shape.z, 0.01);
			float seed = shape.w;
			if (progress <= 0.0) {
				continue;
			}

			float order = dissolve_order(p, center, radius, seed);
			float inside = progress - order;
			if (inside > 0.0) {
				float soot = value_noise(p * 40.0 + seed) * 0.5 + 0.5;
				burned = char_color.rgb * soot;
				float rim = exp(-inside / 0.035);
				glow += mix(ember_core.rgb, ember_color.rgb, clamp(inside / 0.05, 0.0, 1.0)) * rim * 1.4;
			} else {
				float scorch = exp(inside / 0.05);
				burned *= 1.0 - scorch * 0.65;
				glow += ember_color.rgb * exp(inside / 0.018) * 0.6;
			}

			// Skip the ash search when this pixel is beyond any grain's reach.
			vec2 to_pixel = p - center;
			vec2 trail = max_drift;
			float along = clamp(dot(to_pixel, trail) / max(dot(trail, trail), 1e-5), 0.0, 1.0);
			if (length(to_pixel - trail * along) > radius * 1.5 + 0.08) {
				continue;
			}
			for (int step_index = 0; step_index < ASH_STEPS; step_index++) {
				float tau = (float(step_index) + 0.5) * ASH_STEP_SECONDS;
				vec2 origin = p - ash_drift(tau, p);
				float dissolved_for = (progress - dissolve_order(origin, center, radius, seed)) / speed;
				// Windows overlap: the wind shifts each step's ring, and exact tiling would leave contour gaps.
				if (abs(dissolved_for - tau) > ASH_STEP_SECONDS * 0.85) {
					continue;
				}
				vec2 grain_cell = floor(origin * viewport_px.y / grain_px);
				if (hash12(grain_cell + vec2(seed * 13.0)) > ash_density) {
					continue;
				}
				float life = exp(-tau / 0.38) * (1.0 - tau / max_tau);
				vec3 content = texture(screen_texture, clamp(origin * to_uv, vec2(0.0), vec2(1.0))).rgb;
				float heat = exp(-tau / 0.18);
				vec3 grain_color = mix(mix(content, ash_color.rgb, 0.45), ember_core.rgb, heat * 0.8);
				float alpha = life * (0.6 + 0.4 * hash12(grain_cell + vec2(3.0, 9.0)));
				if (alpha > ash_alpha) {
					ash_alpha = alpha;
					ash = grain_color;
				}
				glow += ember_color.rgb * heat * 0.25;
			}
		}

		if (ember_level > 0.001) {
			for (int layer = 0; layer < 2; layer++) {
				float cell_px = 70.0 + float(layer) * 40.0;
				float rise = field_time * (0.09 + 0.05 * float(layer)) * viewport_px.y;
				vec2 world = vec2(p.x * viewport_px.y, p.y * viewport_px.y + rise);
				vec2 cell = floor(world / cell_px);
				vec2 spot = (cell + vec2(hash12(cell + float(layer)), hash12(cell.yx + 7.0))) * cell_px;
				spot.x += sin(field_time * 1.7 + cell.y) * 8.0;
				float flicker = 0.5 + 0.5 * sin(field_time * 9.0 + hash12(cell) * 40.0);
				float height_fade = smoothstep(0.3, 1.0, SCREEN_UV.y);
				float spark = exp(-length(world - spot) / 1.6) * flicker * height_fade;
				glow += ember_color.rgb * spark * ember_level * step(0.45, hash12(cell + 2.0));
			}
		}

		vec3 composed = mix(burned, ash, ash_alpha);
		composed += glow * glow_gain;
		result = clamp(composed, 0.0, 1.0);
	}
	COLOR = vec4(result, 1.0);
}
