shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float elapsed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.4, 0.7, 1.0);
uniform int effect_mode = 0;
uniform float seed = 1.0;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 345.45));
	point += dot(point, point + 34.345 + seed);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), local.x), local.y);
}


float fbm(vec2 point) {
	float result = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(point) * weight;
		point = point * 2.03 + vec2(7.1, 3.7);
		weight *= 0.5;
	}
	return result;
}


float cloud_effect(vec2 uv, vec2 point) {
	vec2 drift = vec2(elapsed * 0.025, sin(elapsed * 0.08) * 0.08);
	float broad = fbm(uv * 3.0 + drift + seed);
	float detail = fbm(uv * 7.0 - drift * 1.7 + seed * 0.31);
	return smoothstep(0.38, 0.82, broad * 0.72 + detail * 0.38) * (1.0 - length(point) * 0.22);
}


float ripple_effect(vec2 uv, vec2 point) {
	vec2 origin = vec2(0.5 + sin(seed) * 0.12, 0.54 + cos(seed) * 0.08);
	float distance_to_origin = length((uv - origin) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0));
	float waves = 0.5 + 0.5 * sin(distance_to_origin * 42.0 - elapsed * 2.0);
	float rings = smoothstep(0.62, 0.98, waves) * exp(-distance_to_origin * 1.25);
	float water = fbm(vec2(uv.x * 5.0 + elapsed * 0.025, uv.y * 8.0));
	return rings * 0.72 + water * 0.22 + max(0.0, -point.y) * 0.08;
}


float energy_effect(vec2 uv, vec2 point) {
	float path = sin(point.y * 8.0 + seed) * 0.08 + sin(point.y * 21.0 - elapsed * 2.4) * 0.025;
	float bolt_distance = abs(point.x - path - sin(seed * 2.0) * 0.16);
	float flash = pow(max(0.0, sin(elapsed * 3.7 + seed)), 12.0);
	float bolt = (1.0 - smoothstep(0.002, 0.026, bolt_distance)) * (0.18 + flash * 0.82);
	vec2 spark_grid = uv * vec2(34.0, 20.0);
	vec2 spark_cell = floor(spark_grid);
	vec2 spark_center = vec2(hash21(spark_cell), hash21(spark_cell + 6.7));
	float spark_shape = 1.0 - smoothstep(0.025, 0.1, length(fract(spark_grid) - spark_center));
	float spark = spark_shape * step(0.94, hash21(spark_cell + floor(elapsed * 1.4)));
	return bolt + spark * 0.7 + fbm(uv * 4.0 + elapsed * 0.02) * 0.18;
}


float lightning_effect(vec2 uv, vec2 point) {
	float bolts = 0.0;
	for (int index = 0; index < 6; index++) {
		float bolt_index = float(index);
		float random_a = hash21(vec2(bolt_index + 2.3, seed));
		float random_b = hash21(vec2(seed + 7.1, bolt_index));
		float offset = mix(-0.72, 0.72, (bolt_index + random_a) / 6.0);
		float crooked = sin(point.y * mix(8.0, 14.0, random_a) + random_b * 9.0) * mix(0.025, 0.065, random_b);
		crooked += sin(point.y * mix(25.0, 39.0, random_b) - elapsed * 1.7) * 0.012;
		float distance_to_bolt = abs(point.x - offset - crooked);
		float core = 1.0 - smoothstep(0.0012, 0.0055, distance_to_bolt);
		float glow = (1.0 - smoothstep(0.005, 0.019, distance_to_bolt)) * 0.24;
		float flash = pow(max(0.0, sin(elapsed * mix(2.1, 3.4, random_a) + random_b * 11.0)), 10.0);
		float visibility = 0.16 + flash * 0.84;
		bolts += (core + glow) * visibility;
	}
	float storm_haze = fbm(uv * 4.5 + vec2(elapsed * 0.012, seed)) * 0.1;
	return clamp(bolts + storm_haze, 0.0, 1.0);
}


float mountain_ridge(float x, float layer_seed, float base_y, float highest_peak, float lowest_peak) {
	float ridge = base_y;
	for (int index = 0; index < 7; index++) {
		float peak_index = float(index);
		float random_x = hash21(vec2(peak_index + 1.7, seed + layer_seed));
		float random_width = hash21(vec2(seed + layer_seed * 2.3, peak_index + 5.1));
		float random_height = hash21(vec2(peak_index + 9.4, seed * 0.37 + layer_seed));
		float center = (peak_index + 0.5 + (random_x - 0.5) * 0.72) / 7.0;
		float half_width = mix(0.105, 0.205, random_width);
		float peak_y = mix(highest_peak, lowest_peak, random_height);
		float distance_from_peak = abs(x - center) / half_width;
		float candidate = mix(peak_y, base_y, clamp(distance_from_peak, 0.0, 1.0));
		if (distance_from_peak <= 1.0) {
			ridge = min(ridge, candidate);
		}
	}
	float rock_detail = (value_noise(vec2(x * 38.0 + layer_seed, seed * 0.61)) - 0.5) * 0.026;
	return ridge + rock_detail;
}


float mountain_effect(vec2 uv) {
	float back_ridge = mountain_ridge(uv.x, 2.4, 0.67, 0.2, 0.4);
	float front_ridge = mountain_ridge(uv.x, 8.7, 0.83, 0.34, 0.56);
	float back_fill = smoothstep(back_ridge - 0.015, back_ridge + 0.11, uv.y) * 0.26;
	float front_fill = smoothstep(front_ridge - 0.02, front_ridge + 0.13, uv.y) * 0.38;
	float back_edge = 1.0 - smoothstep(0.004, 0.024, abs(uv.y - back_ridge));
	float front_edge = 1.0 - smoothstep(0.004, 0.027, abs(uv.y - front_ridge));
	float mist = fbm(vec2(uv.x * 3.2 - elapsed * 0.012, uv.y * 7.0 + seed)) * 0.1;
	return clamp(back_fill + front_fill + back_edge * 0.48 + front_edge * 0.68 + mist, 0.0, 1.0);
}


float earth_effect(vec2 uv) {
	float strata = 0.5 + 0.5 * sin(uv.y * 34.0 + value_noise(vec2(uv.x * 5.0, seed)) * 3.0);
	strata = smoothstep(0.72, 0.98, strata) * smoothstep(0.36, 0.92, uv.y) * 0.34;
	vec2 dust_grid = vec2(uv.x * 38.0, uv.y * 22.0 + elapsed * 0.32);
	vec2 dust_cell = floor(dust_grid);
	vec2 dust_center = vec2(hash21(dust_cell), hash21(dust_cell + 9.17));
	float dust_shape = 1.0 - smoothstep(0.035, 0.13, length(fract(dust_grid) - dust_center));
	float dust = dust_shape * step(0.84, hash21(dust_cell + 3.4)) * smoothstep(0.28, 0.95, uv.y);
	return strata + dust * 0.62 + fbm(uv * 3.2 + vec2(0.0, elapsed * 0.012)) * 0.12;
}


float wind_effect(vec2 uv) {
	float streams = 0.0;
	for (int index = 0; index < 20; index++) {
		float line_index = float(index);
		float random_a = hash21(vec2(line_index, seed + 2.7));
		float random_b = hash21(vec2(seed + 5.3, line_index));
		float base_y = mix(-0.06, 1.06, (line_index + random_a * 0.7) / 20.0);
		float frequency = mix(2.2, 5.6, random_b);
		float amplitude = mix(0.012, 0.048, random_a);
		float curve = base_y + sin(uv.x * frequency + line_index * 1.73 + elapsed * 0.22) * amplitude;
		curve += sin(uv.x * 11.0 - elapsed * 0.13 + random_b * 8.0) * 0.008;
		float thickness = mix(0.0007, 0.0017, random_b);
		float stroke = 1.0 - smoothstep(thickness, thickness * 3.2, abs(uv.y - curve));
		float travel = fract(uv.x * mix(0.72, 1.08, random_a) - elapsed * mix(0.055, 0.11, random_b) + random_a);
		float segment = smoothstep(0.015, 0.11, travel) * (1.0 - smoothstep(0.68, 0.96, travel));
		streams += stroke * segment * mix(0.42, 0.9, random_a);
	}
	float breeze_haze = fbm(vec2(uv.x * 2.4 - elapsed * 0.045, uv.y * 8.0 + seed)) * 0.12;
	return clamp(streams * 0.48 + breeze_haze, 0.0, 1.0);
}


void fragment() {
	vec2 uv = UV;
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 point = (uv - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;
	float effect = 0.0;
	if (effect_mode == 0) {
		effect = cloud_effect(uv, point);
	} else if (effect_mode == 1) {
		effect = ripple_effect(uv, point);
	} else if (effect_mode == 2) {
		effect = energy_effect(uv, point);
	} else if (effect_mode == 3) {
		effect = mountain_effect(uv);
	} else if (effect_mode == 4) {
		effect = wind_effect(uv);
	} else if (effect_mode == 5) {
		effect = earth_effect(uv);
	} else {
		effect = lightning_effect(uv, point);
	}
	float center_haze = exp(-dot(point, point) * 0.42) * 0.055;
	float edge_fade = 1.0 - smoothstep(0.25, 1.35, length(point * vec2(0.68, 1.0)));
	float alpha = clamp((effect * 0.32 + center_haze) * edge_fade * opacity, 0.0, 0.3);
	vec3 luminous_color = mix(accent_color.rgb, vec3(1.0), 0.2);
	COLOR = vec4(luminous_color, alpha);
}
