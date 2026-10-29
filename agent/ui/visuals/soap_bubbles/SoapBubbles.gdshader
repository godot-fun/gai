shader_type canvas_item;

// Soap bubbles floating over the live interface. Each film's color is thin-film interference
// computed per wavelength from a thickness that drains toward the bottom, swirls with the flow,
// and thins at the top into a black film before the bubble pops. Fresnel weights the film toward
// the rim and two window reflections give the glossy highlight. A pop tears the film open from
// one point and throws a ring of droplets. Dark themes add the reflected light; light themes show
// the transmitted complement as a stain with a refraction rim.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float bubble_time = 0.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.3;
uniform float film_gain : hint_range(0.0, 2.0) = 1.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform int bubble_count = 0;
// (uv.x, uv.y, radius in viewport heights, seed)
uniform vec4 bubble_shape[8];
// (thinning 0..1, pop progress or -1, pop angle, error tint)
uniform vec4 bubble_state[8];
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

const float FILM_INDEX = 1.33;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		sum += value_noise(p) * amplitude;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		amplitude *= 0.5;
	}
	return sum;
}

// Reflectance of a soap film of thickness nm for red, green and blue wavelengths.
vec3 film_color(float thickness, float cos_t) {
	vec3 wavelength = vec3(650.0, 532.0, 450.0);
	vec3 phase = 6.2831853 * FILM_INDEX * thickness * cos_t / wavelength;
	vec3 s = sin(phase);
	return s * s;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float aspect = viewport_px.x / max(viewport_px.y, 1.0);
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	vec3 result = source;
	vec2 refract_offset = vec2(0.0);
	vec3 reflected = vec3(0.0);
	float stain = 0.0;
	vec3 transmitted = vec3(1.0);
	float rim_line = 0.0;
	float highlight = 0.0;
	float droplets = 0.0;
	for (int index = 0; index < bubble_count; index++) {
		vec4 shape = bubble_shape[index];
		vec4 state = bubble_state[index];
		vec2 q = (SCREEN_UV - shape.xy) * vec2(aspect, 1.0) / shape.z;
		float rr = dot(q, q);
		float pop = state.y;
		if (pop >= 0.0) {
			vec2 dir = vec2(cos(state.z), sin(state.z));
			for (int drop = 0; drop < 10; drop++) {
				float a = state.z + (float(drop) - 4.5) * 0.32 + hash12(vec2(float(drop), shape.w)) * 0.2;
				vec2 drop_dir = vec2(cos(a), sin(a));
				vec2 center = drop_dir * (1.0 + pop * (0.6 + hash12(vec2(shape.w, float(drop))) * 0.7)) + vec2(0.0, pop * pop * 0.5);
				float size = 0.035 * (1.0 - pop);
				droplets = max(droplets, smoothstep(size, size * 0.3, length(q - center)) * (1.0 - pop));
			}
		}
		if (rr > 1.0) {
			continue;
		}
		float hole = 0.0;
		float tear = 0.0;
		if (pop >= 0.0) {
			vec2 origin = vec2(cos(state.z), sin(state.z)) * 0.95;
			float reach = pop * 2.4;
			float distance_to_origin = length(q - origin);
			hole = step(distance_to_origin, reach);
			tear = smoothstep(0.12, 0.0, abs(distance_to_origin - reach)) * (1.0 - hole) * (1.0 - pop);
			if (hole > 0.5) {
				continue;
			}
		}
		float z = sqrt(1.0 - rr);
		float r = sqrt(rr);
		vec2 flow = vec2(bubble_time * 0.05, -bubble_time * 0.09) * (0.5 + turbulence);
		float swirl = fbm(q * 2.2 + shape.w * 17.0 + flow + vec2(fbm(q * 1.7 - flow), 0.0) * (1.2 + turbulence * 2.0));
		float drain = 0.35 + 0.65 * pow(clamp(q.y * 0.5 + 0.5, 0.0, 1.0), 1.4);
		float thinning = state.x;
		float thickness = mix(820.0, 240.0, thinning) * drain + (swirl - 0.5) * (260.0 + turbulence * 260.0);
		float top_black = smoothstep(0.55 - thinning * 0.9, -0.4 - thinning * 0.6, q.y) * thinning;
		thickness = max(thickness * (1.0 - top_black), 4.0);
		float sin_t = r / FILM_INDEX;
		vec3 film = film_color(thickness, sqrt(1.0 - sin_t * sin_t));
		film = mix(film, error_color.rgb * dot(film, vec3(0.33)) * 1.6, state.w * 0.6);
		float fresnel = 0.1 + 0.9 * pow(1.0 - z, 1.8);
		vec2 highlight_q = q - vec2(-0.4, -0.42);
		highlight_q.x += highlight_q.y * 0.35;
		float window_distance = length(max(abs(highlight_q) - vec2(0.13, 0.07), vec2(0.0))) - 0.04;
		float window = smoothstep(0.07, -0.03, window_distance) * (0.75 + 0.25 * smoothstep(0.1, -0.1, highlight_q.y));
		float window_small = smoothstep(0.09, 0.0, length(q - vec2(0.45, 0.5)));
		float bubble_alpha = smoothstep(1.0, 0.985, r);
		reflected += film * fresnel * film_gain * bubble_alpha + vec3(tear * 0.6);
		transmitted *= mix(vec3(1.0), vec3(1.0) - film * 0.55, fresnel * film_gain * bubble_alpha);
		stain = max(stain, fresnel * bubble_alpha);
		rim_line = max(rim_line, smoothstep(0.93, 0.99, r) * bubble_alpha + tear * 0.5);
		highlight = max(highlight, (window * 0.9 + window_small * 0.7) * bubble_alpha);
		refract_offset += q * (1.0 - z) * shape.z * 0.06 * bubble_alpha;
	}
	if (bubble_count > 0) {
		vec3 seen = texture(screen_texture, clamp(SCREEN_UV - refract_offset / vec2(aspect, 1.0), vec2(0.0), vec2(1.0))).rgb;
		if (light_mode > 0.5) {
			result = seen * transmitted;
			result *= 1.0 - rim_line * 0.22;
			result = mix(result, vec3(1.0), highlight);
			result = mix(result, result * vec3(0.55, 0.62, 0.72), droplets * 0.8);
		} else {
			result = seen + reflected * 0.9;
			result += vec3(0.85, 0.92, 1.0) * rim_line * 0.06;
			result += vec3(0.92, 0.96, 1.0) * highlight * 0.8;
			result += vec3(0.75, 0.85, 1.0) * droplets * 0.7;
		}
		result = mix(source, result, body_mask);
	}
	COLOR = vec4(result, 1.0);
}
