shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform int mode = 1;
uniform float strength : hint_range(0.0, 1.0) = 0.82;
uniform float contrast : hint_range(0.5, 2.5) = 1.0;
uniform float levels : hint_range(2.0, 16.0) = 6.0;
uniform float effect_scale : hint_range(1.0, 16.0) = 3.0;
uniform float grain_strength : hint_range(0.0, 0.4) = 0.0;
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.08;
uniform vec4 ink_color : source_color = vec4(0.08, 0.08, 0.08, 1.0);
uniform vec4 paper_color : source_color = vec4(0.93, 0.93, 0.91, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float random_noise(vec2 position) {
	return fract(sin(dot(floor(position), vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer4(vec2 pixel) {
	vec2 p = mod(floor(pixel), 4.0);
	float x = p.x;
	float y = p.y;
	float value = 0.0;
	if (y < 1.0) value = x < 1.0 ? 0.0 : (x < 2.0 ? 8.0 : (x < 3.0 ? 2.0 : 10.0));
	else if (y < 2.0) value = x < 1.0 ? 12.0 : (x < 2.0 ? 4.0 : (x < 3.0 ? 14.0 : 6.0));
	else if (y < 3.0) value = x < 1.0 ? 3.0 : (x < 2.0 ? 11.0 : (x < 3.0 ? 1.0 : 9.0));
	else value = x < 1.0 ? 15.0 : (x < 2.0 ? 7.0 : (x < 3.0 ? 13.0 : 5.0));
	return (value + 0.5) / 16.0;
}

vec3 adjusted(vec3 color) {
	return clamp((color - 0.5) * contrast + 0.5, 0.0, 1.0);
}

float edge_at(vec2 uv, vec2 texel) {
	float left = luminance(texture(screen_texture, uv - vec2(texel.x, 0.0)).rgb);
	float right = luminance(texture(screen_texture, uv + vec2(texel.x, 0.0)).rgb);
	float up = luminance(texture(screen_texture, uv - vec2(0.0, texel.y)).rgb);
	float down = luminance(texture(screen_texture, uv + vec2(0.0, texel.y)).rgb);
	return clamp(abs(right - left) + abs(down - up), 0.0, 1.0);
}

vec3 thermal(float value) {
	vec3 cold = vec3(0.02, 0.02, 0.25);
	vec3 blue = vec3(0.0, 0.35, 1.0);
	vec3 red = vec3(1.0, 0.06, 0.0);
	vec3 yellow = vec3(1.0, 0.95, 0.1);
	return value < 0.33 ? mix(cold, blue, value / 0.33) : (value < 0.66 ? mix(blue, red, (value - 0.33) / 0.33) : mix(red, yellow, (value - 0.66) / 0.34));
}

vec3 rotate_hue(vec3 color, float angle) {
	vec3 axis = normalize(vec3(1.0));
	return color * cos(angle) + cross(axis, color) * sin(angle) + axis * dot(axis, color) * (1.0 - cos(angle));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 texel = 1.0 / screen_size;
	vec2 pixel = uv * screen_size;
	vec3 source = texture(screen_texture, uv).rgb;
	vec3 base = adjusted(source);
	float gray = luminance(base);
	float edge = edge_at(uv, texel * max(effect_scale, 1.0));
	vec3 filtered = base;

	if (mode == 1) {
		filtered = vec3(floor(gray * levels + 0.5) / levels);
	} else if (mode == 2) {
		float ink = smoothstep(0.18, 0.82, gray + (random_noise(pixel) - 0.5) * 0.16);
		filtered = mix(ink_color.rgb, paper_color.rgb, floor(ink * levels) / max(levels - 1.0, 1.0));
	} else if (mode == 3) {
		float threshold = bayer4(pixel / max(effect_scale, 1.0));
		filtered = mix(ink_color.rgb, paper_color.rgb, step(threshold, gray));
	} else if (mode == 4) {
		filtered = vec3(dot(base, vec3(0.393, 0.769, 0.189)), dot(base, vec3(0.349, 0.686, 0.168)), dot(base, vec3(0.272, 0.534, 0.131)));
	} else if (mode == 5) {
		filtered = 1.0 - base;
	} else if (mode == 6) {
		filtered = floor(base * levels + 0.5) / levels * tint_color.rgb;
	} else if (mode == 7) {
		vec2 block_uv = (floor(pixel / effect_scale) * effect_scale + effect_scale * 0.5) / screen_size;
		filtered = floor(adjusted(texture(screen_texture, block_uv).rgb) * levels + 0.5) / levels;
	} else if (mode == 8) {
		float scan = 0.82 + 0.18 * sin(pixel.y * 3.14159265 / max(effect_scale, 1.0));
		float mask = 0.88 + 0.12 * step(1.0, mod(pixel.x, 3.0));
		filtered = base * scan * mask;
	} else if (mode == 9) {
		float scan = 0.78 + 0.22 * sin(pixel.y * 3.14159265 / max(effect_scale, 1.0));
		filtered = mix(paper_color.rgb, ink_color.rgb, gray) * scan;
	} else if (mode == 10) {
		filtered = mix(paper_color.rgb, ink_color.rgb, smoothstep(0.08, 0.9, gray));
	} else if (mode == 11) {
		filtered = thermal(gray);
	} else if (mode == 12) {
		vec2 shift = vec2(effect_scale, 0.0) * texel;
		filtered = vec3(texture(screen_texture, uv + shift).r, source.g, texture(screen_texture, uv - shift).b);
	} else if (mode == 13) {
		float band = step(0.72, random_noise(vec2(floor(pixel.y / 18.0), floor(TIME * 5.0))));
		float offset = (random_noise(vec2(floor(pixel.y / 18.0), floor(TIME * 7.0))) - 0.5) * effect_scale * 6.0 * band;
		vec2 glitch_uv = uv + vec2(offset * texel.x, 0.0);
		filtered = vec3(texture(screen_texture, glitch_uv + vec2(effect_scale * texel.x, 0.0)).r, texture(screen_texture, glitch_uv).g, texture(screen_texture, glitch_uv - vec2(effect_scale * texel.x, 0.0)).b);
	} else if (mode == 14) {
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(gray * 0.45 + edge * 1.8, 0.0, 1.0));
	} else if (mode == 15) {
		float pencil = clamp(1.0 - edge * 3.2 - (1.0 - gray) * 0.22, 0.0, 1.0);
		filtered = mix(ink_color.rgb, paper_color.rgb, pencil);
	} else if (mode == 16) {
		filtered = paper_color.rgb + ink_color.rgb * edge * 3.5;
	} else if (mode == 17) {
		vec2 block_uv = (floor(pixel / effect_scale) * effect_scale + effect_scale * 0.5) / screen_size;
		float block_gray = luminance(texture(screen_texture, block_uv).rgb);
		float quantized = floor(block_gray * (levels - 1.0) + 0.5) / max(levels - 1.0, 1.0);
		filtered = mix(ink_color.rgb, paper_color.rgb, quantized);
	} else if (mode == 18) {
		vec3 bloom = textureLod(screen_texture, uv, 3.0).rgb;
		filtered = mix(base, bloom * tint_color.rgb, 0.5) + max(bloom - 0.62, 0.0) * 0.45;
	} else if (mode == 19) {
		vec3 solarized = abs(base * 2.0 - 1.0);
		filtered = mix(1.0 - solarized, solarized, step(0.5, gray)) * tint_color.rgb;
	} else if (mode == 20) {
		vec2 diagonal = texel * max(effect_scale, 1.0);
		vec3 dark_sample = texture(screen_texture, uv - diagonal).rgb;
		vec3 light_sample = texture(screen_texture, uv + diagonal).rgb;
		filtered = (vec3(0.5) + (light_sample - dark_sample) * 2.4) * tint_color.rgb;
	} else if (mode == 21) {
		filtered = mix(ink_color.rgb, paper_color.rgb, smoothstep(0.12, 0.88, gray));
	} else if (mode == 22) {
		float angle = TIME * 0.22 + effect_scale * 0.55;
		filtered = clamp(rotate_hue(base, angle), 0.0, 1.0);
	} else if (mode == 23) {
		vec3 poster = floor(base * levels + 0.5) / levels;
		float dots = step(bayer4(pixel / max(effect_scale, 1.0)), gray);
		filtered = mix(poster * tint_color.rgb, vec3(0.015), smoothstep(0.08, 0.3, edge));
		filtered *= mix(0.82, 1.08, dots);
	} else if (mode == 24) {
		float wave = sin(uv.y * 70.0 + TIME * 2.3) + sin(uv.y * 31.0 - TIME * 1.7);
		vec2 wave_uv = uv + vec2(wave * effect_scale * texel.x, sin(uv.x * 24.0 + TIME) * effect_scale * texel.y);
		filtered = texture(screen_texture, wave_uv).rgb * tint_color.rgb;
	} else if (mode == 25) {
		vec2 center_uv = uv * 2.0 - 1.0;
		float radius = length(center_uv);
		float bend = 1.0 + radius * radius * effect_scale * 0.035;
		vec2 lens_uv = center_uv / bend * 0.5 + 0.5;
		filtered = texture(screen_texture, lens_uv).rgb;
	} else if (mode == 26) {
		vec2 mirror_uv = vec2(abs(uv.x - 0.5) * 2.0, uv.y);
		filtered = texture(screen_texture, mirror_uv).rgb;
	} else if (mode == 27) {
		vec2 mirror_uv = abs(uv - 0.5) * 2.0;
		filtered = texture(screen_texture, mirror_uv).rgb;
	} else if (mode == 28) {
		vec2 centered_uv = uv - 0.5;
		float radius = length(centered_uv);
		float angle = atan(centered_uv.y, centered_uv.x);
		float segments = max(floor(effect_scale), 3.0);
		float wedge = 6.2831853 / segments;
		angle = abs(mod(angle + wedge * 0.5, wedge) - wedge * 0.5);
		vec2 kaleido_uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
		filtered = texture(screen_texture, kaleido_uv).rgb;
	} else if (mode == 29) {
		vec2 cell = floor(pixel / effect_scale);
		vec2 cell_uv = (cell * effect_scale + effect_scale * 0.5) / screen_size;
		vec3 cell_color = texture(screen_texture, cell_uv).rgb;
		vec2 local = fract(pixel / effect_scale) - 0.5;
		float bevel = smoothstep(0.5, 0.34, max(abs(local.x), abs(local.y)));
		filtered = cell_color * mix(0.62, 1.08, bevel);
	} else if (mode == 30) {
		float line = floor(pixel.y / max(effect_scale, 1.0));
		float jitter = (random_noise(vec2(line, floor(TIME * 12.0))) - 0.5) * effect_scale * 2.0;
		float tear = step(0.88, random_noise(vec2(line, floor(TIME * 3.0))));
		vec2 tape_uv = uv + vec2(jitter * tear * texel.x, sin(pixel.y * 0.035 + TIME * 7.0) * texel.x * effect_scale);
		vec2 chroma = vec2(effect_scale * 0.65 * texel.x, 0.0);
		filtered = vec3(texture(screen_texture, tape_uv + chroma).r, texture(screen_texture, tape_uv).g, texture(screen_texture, tape_uv - chroma).b);
		filtered *= 0.9 + 0.1 * sin(pixel.y * 3.14159265);
	} else if (mode == 31) {
		vec3 paint_sum = vec3(0.0);
		float paint_radius = max(effect_scale, 1.0);
		paint_sum += texture(screen_texture, uv + vec2(-paint_radius, -paint_radius) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(0.0, -paint_radius) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(paint_radius, -paint_radius) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(-paint_radius, 0.0) * texel).rgb;
		paint_sum += source * 2.0;
		paint_sum += texture(screen_texture, uv + vec2(paint_radius, 0.0) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(-paint_radius, paint_radius) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(0.0, paint_radius) * texel).rgb;
		paint_sum += texture(screen_texture, uv + vec2(paint_radius, paint_radius) * texel).rgb;
		filtered = floor(adjusted(paint_sum / 10.0) * levels + 0.5) / levels;
	} else if (mode == 32) {
		float wash_radius = max(effect_scale, 1.0);
		vec3 wash = source * 0.32;
		wash += texture(screen_texture, uv + vec2(wash_radius, 0.0) * texel).rgb * 0.17;
		wash += texture(screen_texture, uv - vec2(wash_radius, 0.0) * texel).rgb * 0.17;
		wash += texture(screen_texture, uv + vec2(0.0, wash_radius) * texel).rgb * 0.17;
		wash += texture(screen_texture, uv - vec2(0.0, wash_radius) * texel).rgb * 0.17;
		filtered = mix(floor(adjusted(wash) * levels + 0.5) / levels, tint_color.rgb, 0.12) - edge * 0.18;
	} else if (mode == 33) {
		vec2 glass_cell = floor(pixel / max(effect_scale, 1.0));
		vec2 glass_offset = vec2(random_noise(glass_cell), random_noise(glass_cell + 31.7)) - 0.5;
		vec2 glass_uv = uv + glass_offset * effect_scale * 1.7 * texel;
		filtered = texture(screen_texture, glass_uv).rgb;
	} else if (mode == 34) {
		vec2 direction = uv - 0.5;
		float rush = effect_scale * 0.0025;
		filtered = source * 0.24;
		filtered += texture(screen_texture, uv - direction * rush).rgb * 0.19;
		filtered += texture(screen_texture, uv - direction * rush * 2.0).rgb * 0.17;
		filtered += texture(screen_texture, uv - direction * rush * 3.0).rgb * 0.15;
		filtered += texture(screen_texture, uv - direction * rush * 4.0).rgb * 0.13;
		filtered += texture(screen_texture, uv - direction * rush * 5.0).rgb * 0.12;
		filtered *= tint_color.rgb;
	} else if (mode == 35) {
		vec2 trail = vec2(effect_scale, effect_scale * 0.28) * texel;
		filtered = source * 0.28;
		filtered += texture(screen_texture, uv - trail).rgb * 0.22;
		filtered += texture(screen_texture, uv - trail * 2.0).rgb * 0.18;
		filtered += texture(screen_texture, uv - trail * 3.0).rgb * 0.14;
		filtered += texture(screen_texture, uv - trail * 4.0).rgb * 0.1;
		filtered += texture(screen_texture, uv - trail * 5.0).rgb * 0.08;
		filtered *= tint_color.rgb;
	} else if (mode == 36) {
		float threshold = bayer4(pixel / max(effect_scale, 1.0)) - 0.5;
		filtered = floor(clamp(base + threshold / max(levels, 2.0), 0.0, 1.0) * levels) / max(levels - 1.0, 1.0);
	} else if (mode == 37) {
		float density = pow(1.0 - gray, 0.72);
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(density + edge * 1.4, 0.0, 1.0));
	} else if (mode == 38) {
		float surveillance_scan = 0.72 + 0.28 * step(0.5, fract(pixel.y * 0.5));
		float surveillance_noise = (random_noise(pixel + floor(TIME * 12.0)) - 0.5) * 0.12;
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(gray + surveillance_noise, 0.0, 1.0)) * surveillance_scan;
	} else if (mode == 39) {
		float grid = max(floor(effect_scale), 2.0);
		vec2 tile_uv = fract(uv * grid);
		float border = step(0.015, tile_uv.x) * step(0.015, tile_uv.y) * step(tile_uv.x, 0.985) * step(tile_uv.y, 0.985);
		filtered = texture(screen_texture, tile_uv).rgb * border;
	} else if (mode == 40) {
		vec2 swirl_center = uv - 0.5;
		float swirl_radius = length(swirl_center);
		float swirl_angle = atan(swirl_center.y, swirl_center.x) + (1.0 - smoothstep(0.0, 0.72, swirl_radius)) * effect_scale * 0.34;
		vec2 swirl_uv = vec2(cos(swirl_angle), sin(swirl_angle)) * swirl_radius + 0.5;
		filtered = texture(screen_texture, swirl_uv).rgb;
	} else if (mode == 41) {
		float sort_band = floor(pixel.x / max(effect_scale, 1.0));
		float gate = step(0.48, random_noise(vec2(sort_band, floor(pixel.y / 80.0))));
		float sort_offset = (gray - 0.5) * effect_scale * 9.0 * gate;
		vec2 sort_uv = uv + vec2(0.0, sort_offset * texel.y);
		filtered = texture(screen_texture, sort_uv).rgb;
	} else if (mode == 42) {
		float block_size = max(effect_scale, 2.0);
		vec2 block_id = floor(pixel / block_size);
		float broken = step(0.68, random_noise(block_id + floor(TIME * 4.0)));
		vec2 block_shift = vec2(random_noise(block_id + 8.1) - 0.5, random_noise(block_id + 19.4) - 0.5) * block_size * 2.5 * broken;
		vec2 corrupt_uv = uv + block_shift * texel;
		vec3 corrupt = texture(screen_texture, corrupt_uv).rgb;
		filtered = mix(corrupt, corrupt.brg * tint_color.rgb, broken * 0.55);
	}

	float grain = (random_noise(pixel + floor(TIME * 8.0)) - 0.5) * grain_strength;
	filtered += grain;
	vec2 centered = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength;
	filtered *= clamp(vignette, 0.25, 1.0);
	COLOR = vec4(mix(source, clamp(filtered, 0.0, 1.0), strength), 1.0);
}
