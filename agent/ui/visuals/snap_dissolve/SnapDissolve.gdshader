shader_type canvas_item;

// The live interface crumbles into grains of ash that blow away on the wind. Every grain has a
// dissolve threshold from its zone; once a zone's progress passes it, the grain leaves its place
// and flies along the wind for travel = age^2 * reach. Dust is gathered per output pixel: walk
// back upwind, find where the travel distance matches the walked distance, and draw the source
// grain found there. Reversing a zone's progress plays the flight backwards, so grains fly home.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float toolbar_height_px = 48.0;
uniform int zone_count = 0;
// (uv.x, uv.y, radius in viewport-height units, progress)
uniform vec4 zones[8];
// (red, noise seed, 0, 0)
uniform vec4 zone_fx[8];
uniform float end_progress = 0.0;
uniform float end_red = 0.0;
uniform float flake_rate : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform vec4 bg_color : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform vec4 ash_color : source_color = vec4(0.55, 0.5, 0.45, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);

const float GRAIN_PX = 3.0;
const int SEARCH_STEPS = 12;
const int REFINE_STEPS = 4;
const vec2 WIND = vec2(0.87, -0.49);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Largest zone age at a pixel position; negative while every grain there is still in place.
float zone_age(vec2 px, vec2 viewport_px, out float red) {
	vec2 uv = px / viewport_px;
	float aspect = viewport_px.x / viewport_px.y;
	float best = -1.0;
	red = 0.0;
	for (int index = 0; index < zone_count; index++) {
		vec4 zone = zones[index];
		float dist = length((uv - zone.xy) * vec2(aspect, 1.0)) / max(zone.z, 0.0001);
		if (dist > 1.4) {
			continue;
		}
		vec2 q = uv * vec2(aspect, 1.0) + zone_fx[index].y * 37.0;
		float noise = value_noise(q * 22.0) * 0.6 + value_noise(q * 70.0) * 0.4;
		float age = zone.w - (dist * 0.8 + noise * 0.2);
		if (age > best) {
			best = age;
			red = zone_fx[index].x;
		}
	}
	return best;
}

float end_age(vec2 px, vec2 viewport_px) {
	if (end_progress <= 0.0) {
		return -1.0;
	}
	vec2 uv = px / viewport_px;
	float aspect = viewport_px.x / viewport_px.y;
	vec2 q = uv * vec2(aspect, 1.0);
	float noise = value_noise(q * 9.0) * 0.6 + value_noise(q * 38.0) * 0.4;
	return end_progress - (0.72 * (1.0 - uv.x) + 0.28 * noise);
}

float age_at(vec2 px, vec2 viewport_px, bool end_layer, out float red) {
	if (end_layer) {
		red = end_red;
		return end_age(px, viewport_px);
	}
	return zone_age(px, viewport_px, red);
}

// Walked distance minus flight distance of the grain found at that distance upwind.
float residual(vec2 p, float walked, float reach, vec2 viewport_px, bool end_layer) {
	float red;
	float age = age_at(p - WIND * walked, viewport_px, end_layer, red);
	return max(age, 0.0) * max(age, 0.0) * reach - walked;
}

// Returns (alpha, red) of the dust grain landing on [param p] and writes its color.
vec2 gather_dust(vec2 p, float reach, vec2 viewport_px, vec2 pixel, bool end_layer, out vec3 dust) {
	dust = vec3(0.0);
	vec2 perp = vec2(-WIND.y, WIND.x);
	vec2 seek = p - perp * (value_noise(p * 0.012 + time * 0.25) - 0.5) * reach * 0.18;
	float prev_s = 0.5;
	float prev_r = residual(seek, prev_s, reach, viewport_px, end_layer);
	float lo = -1.0;
	float hi = -1.0;
	float lo_r = 0.0;
	for (int step_index = 1; step_index <= SEARCH_STEPS; step_index++) {
		float s = reach * pow(float(step_index) / float(SEARCH_STEPS), 1.35) + 0.5;
		float r = residual(seek, s, reach, viewport_px, end_layer);
		if ((prev_r > 0.0) != (r > 0.0)) {
			lo = prev_s;
			hi = s;
			lo_r = prev_r;
			break;
		}
		prev_s = s;
		prev_r = r;
	}
	if (lo < 0.0) {
		return vec2(0.0);
	}
	for (int refine = 0; refine < REFINE_STEPS; refine++) {
		float mid = (lo + hi) * 0.5;
		float r = residual(seek, mid, reach, viewport_px, end_layer);
		if ((r > 0.0) == (lo_r > 0.0)) {
			lo = mid;
			lo_r = r;
		} else {
			hi = mid;
		}
	}
	vec2 source = seek - WIND * ((lo + hi) * 0.5);
	float red;
	float age = age_at(source, viewport_px, end_layer, red);
	if (age <= 0.0) {
		return vec2(0.0);
	}
	vec2 grain = floor(source / GRAIN_PX);
	vec3 src = texture(screen_texture, clamp((grain + 0.5) * GRAIN_PX * pixel, vec2(0.0), vec2(1.0))).rgb;
	// Ink grains (text, icons, borders) carry most of the dust; flat background barely sheds.
	float ink = clamp(length(src - bg_color.rgb) * 3.0, 0.0, 1.0);
	float pick = hash12(grain + 17.0);
	if (pick > mix(0.18, 0.72, ink)) {
		return vec2(0.0);
	}
	vec2 jitter = vec2(hash12(grain + 3.1), hash12(grain + 7.9)) - 0.5;
	vec2 local = fract(source / GRAIN_PX) - 0.5 - jitter * 0.3;
	float radius = 0.48 - age * 0.16;
	float dot_mask = 1.0 - smoothstep(radius - 0.12, radius, length(local));
	float fade = 1.0 - smoothstep(0.55, 1.15, age);
	vec3 ash = mix(ash_color.rgb, error_color.rgb, red);
	dust = mix(src, ash, clamp(age * 0.6, 0.0, 0.6));
	return vec2(dot_mask * fade * (0.12 + 0.88 * ink), red);
}

// Ambient flakes: copies of ink grains that peel off and drift a short way while text streams.
float gather_flake(vec2 p, vec2 pixel, out vec3 flake) {
	flake = vec3(0.0);
	if (flake_rate <= 0.001) {
		return 0.0;
	}
	const float FLAKE_REACH = 70.0;
	for (int step_index = 0; step_index < 6; step_index++) {
		float s = FLAKE_REACH * (float(step_index) + 0.5) / 6.0;
		vec2 source = p - WIND * s;
		vec2 grain = floor(source / GRAIN_PX);
		float pick = hash12(grain + 41.0);
		if (pick > flake_rate * 0.05) {
			continue;
		}
		float phase = fract(time * (0.35 + pick * 6.0) + hash12(grain + 5.0));
		vec2 landed = (grain + 0.5) * GRAIN_PX + WIND * phase * FLAKE_REACH;
		if (length(landed - p) > GRAIN_PX * 0.6) {
			continue;
		}
		vec3 src = texture(screen_texture, clamp((grain + 0.5) * GRAIN_PX * pixel, vec2(0.0), vec2(1.0))).rgb;
		float ink = length(src - bg_color.rgb);
		if (ink < 0.12) {
			continue;
		}
		flake = mix(src, ash_color.rgb, phase * 0.6);
		return sin(phase * PI) * 0.9;
	}
	return 0.0;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * viewport_px;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 4.0, SCREEN_UV.y);
	vec3 result = source;
	if (body_mask > 0.001) {
		float zone_red;
		float own_zone = zone_age(p, viewport_px, zone_red);
		float own_end = end_age(p, viewport_px);
		float own = max(own_zone, own_end);
		float own_red = own_end >= own_zone ? end_red : zone_red;
		vec3 ember = mix(ember_color.rgb, error_color.rgb, own_red);
		if (own > 0.0) {
			result = bg_color.rgb;
		} else if (own > -0.02) {
			float edge = 1.0 - smoothstep(0.0, 0.02, -own);
			float flicker = 0.75 + 0.25 * hash12(floor(p / GRAIN_PX) + floor(time * 18.0));
			result = mix(result, light_mode > 0.5 ? result * ember : ember, edge * 0.6 * flicker);
		}
		if (zone_count > 0) {
			vec3 dust;
			vec2 hit = gather_dust(p, viewport_px.y * 0.2, viewport_px, SCREEN_PIXEL_SIZE, false, dust);
			result = mix(result, dust, hit.x);
		}
		if (end_progress > 0.0) {
			vec3 dust;
			vec2 hit = gather_dust(p, viewport_px.x * 0.55, viewport_px, SCREEN_PIXEL_SIZE, true, dust);
			result = mix(result, dust, hit.x);
		}
		vec3 flake;
		float flake_alpha = gather_flake(p, SCREEN_PIXEL_SIZE, flake);
		result = mix(result, flake, flake_alpha);
		result = mix(source, result, body_mask);
	}
	COLOR = vec4(result, 1.0);
}
