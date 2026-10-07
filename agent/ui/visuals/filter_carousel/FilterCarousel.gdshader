shader_type canvas_item;

// Full-screen single-pass filter catalog. `mode` selects one algorithm while FilterCarousel.gd
// supplies palette and strength parameters. SCREEN_UV is required: UV would sample the ColorRect
// itself instead of the already-rendered application below it.
//
// Mode map:
//   1-9   monochrome, ink, halftone, sepia, negative, poster, pixel and CRT/terminal
//   10-18 night vision, thermal, RGB/glitch, blueprint, pencil, neon, handheld and dream
//   19-30 solarize, emboss, duotone, hue, comic, optical distortion, mirrors, mosaic and VHS
//   31-42 painting, watercolor, glass, blur, dither, X-ray, surveillance and corruption
//   43-52 ASCII/display simulation, print textures, anaglyph, tunnel, radar and hologram
//   53-63 physical media, exposure, prism, crystal, metal, JPEG and pseudo-Datamosh
//   64-75 sci-fi scanners, reconstructed maps, targeting overlays, recording and low light
//   76-87 polygonal, cubist, procedural material, polar, recursive and pop-art effects
//
// Datamosh and infinity-mirror modes are spatial approximations. True temporal feedback requires
// a history texture or ping-pong SubViewports and should not be hidden inside this single pass.
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

// Deterministic screen-space hash. Quantizing the input before calling it prevents sub-pixel noise
// from shimmering excessively, while TIME is added explicitly by modes that need animated grain.
float random_noise(vec2 position) {
	return fract(sin(dot(floor(position), vec2(12.9898, 78.233))) * 43758.5453);
}

// A 4x4 Bayer matrix gives stable ordered dithering for print and e-ink modes. Unlike random noise,
// it stays fixed while UI elements move and therefore keeps text more legible.
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
	// Four taps approximate a compact Sobel-like edge response without a full 3x3 convolution.
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

float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);
	float a = random_noise(cell);
	float b = random_noise(cell + vec2(1.0, 0.0));
	float c = random_noise(cell + vec2(0.0, 1.0));
	float d = random_noise(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fractal_noise(vec2 position) {
	// Four octaves are a deliberate ceiling: this shader runs over the entire application viewport.
	float result = 0.0;
	result += value_noise(position) * 0.5;
	result += value_noise(position * 2.03 + 7.1) * 0.25;
	result += value_noise(position * 4.07 + 13.7) * 0.125;
	result += value_noise(position * 8.11 + 29.3) * 0.0625;
	return result / 0.9375;
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

	// Foundational color, print and display effects (1-18).
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
	// Optical, palette and analog-video effects (19-30).
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
	// Painterly sampling, spatial distortion and digital corruption (31-42).
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
	// Character/display simulations and scanning devices (43-52).
	} else if (mode == 43) {
		float char_size = max(effect_scale, 5.0);
		vec2 char_cell = floor(pixel / vec2(char_size * 0.7, char_size));
		vec2 char_local = fract(pixel / vec2(char_size * 0.7, char_size)) - 0.5;
		vec2 char_uv = (char_cell * vec2(char_size * 0.7, char_size) + vec2(char_size * 0.35, char_size * 0.5)) / screen_size;
		float char_gray = luminance(texture(screen_texture, char_uv).rgb);
		float bar = step(abs(char_local.x), 0.08 + char_gray * 0.12) * step(abs(char_local.y), 0.42);
		float cross_bar = step(abs(char_local.y), 0.055) * step(abs(char_local.x), 0.34) * step(0.3, char_gray);
		float dot = step(length(char_local), 0.09) * step(0.08, char_gray);
		float glyph = clamp(bar + cross_bar + dot, 0.0, 1.0) * step(0.04, char_gray);
		filtered = mix(paper_color.rgb, ink_color.rgb, glyph);
	} else if (mode == 44) {
		float led_size = max(effect_scale, 3.0);
		vec2 led_cell = floor(pixel / led_size);
		vec2 led_local = fract(pixel / led_size) - 0.5;
		vec2 led_uv = (led_cell * led_size + led_size * 0.5) / screen_size;
		vec3 led_color = texture(screen_texture, led_uv).rgb;
		float led_dot = 1.0 - smoothstep(0.31, 0.48, length(led_local));
		filtered = led_color * led_dot * 1.28 + led_color * 0.035;
	} else if (mode == 45) {
		float lcd_size = max(effect_scale, 2.0);
		vec2 lcd_uv = (floor(pixel / lcd_size) * lcd_size + lcd_size * 0.5) / screen_size;
		vec3 lcd_color = texture(screen_texture, lcd_uv).rgb;
		float subpixel = mod(floor(pixel.x), 3.0);
		vec3 lcd_mask = subpixel < 1.0 ? vec3(1.0, 0.32, 0.32) : (subpixel < 2.0 ? vec3(0.32, 1.0, 0.32) : vec3(0.32, 0.32, 1.0));
		float lcd_grid = step(0.12, fract(pixel.y / lcd_size)) * step(fract(pixel.y / lcd_size), 0.9);
		filtered = lcd_color * lcd_mask * lcd_grid * 1.42;
	} else if (mode == 46) {
		float ink_threshold = bayer4(pixel / max(effect_scale, 1.0));
		float ink_level = floor(gray * levels + ink_threshold) / max(levels - 1.0, 1.0);
		filtered = vec3(clamp(ink_level, 0.04, 0.94));
	} else if (mode == 47) {
		float hatch_scale = max(effect_scale, 2.0);
		float diagonal_a = step(0.72, fract((pixel.x + pixel.y) / hatch_scale));
		float diagonal_b = step(0.72, fract((pixel.x - pixel.y) / hatch_scale));
		float horizontal = step(0.78, fract(pixel.y / hatch_scale));
		float hatch = diagonal_a * step(gray, 0.78) + diagonal_b * step(gray, 0.52) + horizontal * step(gray, 0.28);
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(hatch + edge * 1.8, 0.0, 1.0));
	} else if (mode == 48) {
		float stipple_scale = max(effect_scale, 2.0);
		vec2 stipple_cell = floor(pixel / stipple_scale);
		vec2 stipple_local = fract(pixel / stipple_scale) - 0.5;
		float stipple_radius = (1.0 - gray) * 0.48;
		vec2 stipple_jitter = (vec2(random_noise(stipple_cell), random_noise(stipple_cell + 17.0)) - 0.5) * 0.35;
		float stipple_dot = 1.0 - step(stipple_radius, length(stipple_local - stipple_jitter));
		filtered = mix(paper_color.rgb, ink_color.rgb, max(stipple_dot, edge));
	} else if (mode == 49) {
		vec2 stereo_shift = vec2(effect_scale, 0.0) * texel;
		float red_eye = luminance(texture(screen_texture, uv + stereo_shift).rgb);
		float cyan_eye = luminance(texture(screen_texture, uv - stereo_shift).rgb);
		filtered = vec3(red_eye, cyan_eye, cyan_eye);
	} else if (mode == 50) {
		vec2 tunnel_center = uv - 0.5;
		float tunnel_radius = max(length(tunnel_center), 0.025);
		float tunnel_angle = atan(tunnel_center.y, tunnel_center.x) / 6.2831853 + 0.5;
		float tunnel_depth = fract(effect_scale * 0.08 / tunnel_radius - TIME * 0.12);
		vec2 tunnel_uv = vec2(tunnel_angle, tunnel_depth);
		filtered = texture(screen_texture, tunnel_uv).rgb;
	} else if (mode == 51) {
		vec2 radar_position = uv - 0.5;
		float radar_radius = length(radar_position);
		float radar_angle = atan(radar_position.y, radar_position.x);
		float radar_sweep_angle = mod(TIME * (0.7 + effect_scale * 0.04), 6.2831853) - 3.14159265;
		float radar_delta = abs(atan(sin(radar_angle - radar_sweep_angle), cos(radar_angle - radar_sweep_angle)));
		float radar_sweep = exp(-radar_delta * 8.0) * step(radar_radius, 0.7);
		float radar_rings = smoothstep(0.045, 0.0, abs(fract(radar_radius * 10.0) - 0.5));
		float radar_signal = clamp(gray * 0.58 + radar_sweep + radar_rings * 0.22 + edge, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, radar_signal);
	} else if (mode == 52) {
		float holo_line = sin(pixel.y * 1.7 + TIME * 7.0);
		float holo_jump = step(0.96, random_noise(vec2(floor(pixel.y / 12.0), floor(TIME * 8.0))));
		vec2 holo_uv = uv + vec2(holo_jump * sin(TIME * 31.0) * effect_scale * texel.x, holo_line * effect_scale * 0.08 * texel.y);
		float holo_gray = luminance(texture(screen_texture, holo_uv).rgb);
		float holo_alpha = clamp(holo_gray * 0.66 + edge * 1.3 + holo_line * 0.06, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, holo_alpha);
	// Physical media, optical compositing and compression artifacts (53-63).
	} else if (mode == 53) {
		float cut_scale = max(effect_scale, 2.0);
		float cut_a = step(0.66, fract((pixel.x * 0.33 + pixel.y) / cut_scale));
		float cut_b = step(0.78, fract((pixel.x * -0.22 + pixel.y) / (cut_scale * 0.72)));
		float carved = cut_a * step(gray, 0.82) + cut_b * step(gray, 0.48);
		float wood_edge = smoothstep(0.07, 0.24, edge);
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(carved + wood_edge, 0.0, 1.0));
	} else if (mode == 54) {
		float chalk_noise = random_noise(pixel / max(effect_scale, 1.0));
		float chalk_line = smoothstep(0.035 + chalk_noise * 0.08, 0.28, edge);
		float chalk_dust = step(0.965 - gray * 0.08, random_noise(pixel * 0.37 + 11.0)) * 0.42;
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(chalk_line + chalk_dust + gray * 0.1, 0.0, 1.0));
	} else if (mode == 55) {
		float ink_scale = max(effect_scale, 2.0);
		vec2 ink_flow = vec2(random_noise(floor(pixel / ink_scale)), random_noise(floor(pixel / ink_scale) + 23.0)) - 0.5;
		float wet_a = luminance(texture(screen_texture, uv + ink_flow * ink_scale * texel).rgb);
		float wet_b = luminance(texture(screen_texture, uv - ink_flow.yx * ink_scale * 1.5 * texel).rgb);
		float wet_density = 1.0 - min(gray, min(wet_a, wet_b));
		wet_density = smoothstep(0.16, 0.76, wet_density + random_noise(pixel / 3.0) * 0.1);
		filtered = mix(paper_color.rgb, ink_color.rgb, wet_density);
	} else if (mode == 56) {
		float pencil_scale = max(effect_scale, 2.0);
		float pencil_a = step(0.76, fract((pixel.x + pixel.y * 0.42) / pencil_scale));
		float pencil_b = step(0.84, fract((pixel.x - pixel.y * 0.58) / (pencil_scale * 0.8)));
		float pencil_texture = (pencil_a + pencil_b) * (1.0 - gray) * 0.2;
		vec3 pencil_color = floor(base * 10.0 + 0.5) / 10.0;
		filtered = pencil_color * (1.0 - pencil_texture) - edge * 0.3;
	} else if (mode == 57) {
		vec2 burn_center = vec2(0.5 + sin(TIME * 0.31) * 0.18, 0.5 + cos(TIME * 0.23) * 0.14);
		float burn_distance = length((uv - burn_center) * vec2(1.0, 0.78));
		float burn_noise = random_noise(floor(pixel / max(effect_scale, 2.0))) * 0.15;
		float burn_phase = 0.18 + 0.34 * (0.5 + 0.5 * sin(TIME * 0.7));
		float burn_core = 1.0 - smoothstep(burn_phase - 0.08, burn_phase + 0.03, burn_distance + burn_noise);
		float burn_ring = smoothstep(0.055, 0.0, abs(burn_distance + burn_noise - burn_phase));
		filtered = mix(base, vec3(1.0, 0.24, 0.015), burn_ring * 0.9);
		filtered = mix(filtered, vec3(1.0, 0.92, 0.54), burn_core * 0.78);
	} else if (mode == 58) {
		vec2 exposure_centered = uv - 0.5;
		vec2 exposure_uv = exposure_centered * (0.94 - effect_scale * 0.004) + 0.5 + vec2(effect_scale, -effect_scale * 0.55) * texel;
		vec3 exposure = texture(screen_texture, exposure_uv).rgb;
		float exposure_mask = smoothstep(0.18, 0.82, luminance(exposure));
		filtered = mix(base, max(base, exposure * tint_color.rgb), exposure_mask * 0.58);
	} else if (mode == 59) {
		float prism_size = max(effect_scale * 5.0, 18.0);
		vec2 prism_cell = floor(pixel / prism_size);
		vec2 prism_local = fract(pixel / prism_size);
		float prism_side = step(prism_local.x, prism_local.y);
		vec2 prism_direction = normalize(vec2(random_noise(prism_cell) - 0.5, random_noise(prism_cell + 9.0) - 0.5) + vec2(0.001));
		vec2 prism_shift = prism_direction * effect_scale * (0.65 + prism_side) * texel;
		filtered = vec3(texture(screen_texture, uv + prism_shift).r, texture(screen_texture, uv - prism_shift * 0.3).g, texture(screen_texture, uv - prism_shift).b);
	} else if (mode == 60) {
		vec2 ball = uv - 0.5;
		float ball_radius = length(ball);
		float inside_ball = 1.0 - step(0.46, ball_radius);
		float sphere_z = sqrt(max(1.0 - pow(ball_radius / 0.46, 2.0), 0.0));
		float magnify = mix(1.0, 0.52 + effect_scale * 0.008, inside_ball);
		vec2 ball_uv = ball * magnify + 0.5;
		vec3 ball_color = texture(screen_texture, ball_uv).rgb;
		float ball_highlight = pow(max(dot(normalize(vec3(ball / 0.46, sphere_z)), normalize(vec3(-0.45, -0.55, 1.0))), 0.0), 18.0);
		filtered = mix(base * 0.62, ball_color + ball_highlight * 0.7, inside_ball);
	} else if (mode == 61) {
		float metal_wave = sin(gray * 18.0 + edge * effect_scale * 12.0 + TIME * 0.35);
		float metal_band = smoothstep(-0.35, 0.72, metal_wave);
		vec3 dark_metal = vec3(0.025, 0.04, 0.055);
		vec3 light_metal = vec3(0.72, 0.82, 0.92) * tint_color.rgb;
		filtered = mix(dark_metal, light_metal, metal_band);
		filtered += pow(edge, 0.55) * vec3(0.65, 0.82, 1.0);
	} else if (mode == 62) {
		float jpeg_size = max(effect_scale, 8.0);
		vec2 jpeg_cell = floor(pixel / jpeg_size);
		vec2 jpeg_uv = (jpeg_cell * jpeg_size + jpeg_size * 0.5) / screen_size;
		vec3 jpeg_color = texture(screen_texture, jpeg_uv).rgb;
		float jpeg_luma = luminance(jpeg_color);
		vec2 chroma_shift = vec2(jpeg_size * 0.42, 0.0) * texel;
		vec3 jpeg_chroma = texture(screen_texture, jpeg_uv + chroma_shift).rgb;
		jpeg_color = mix(vec3(jpeg_luma), vec3(jpeg_chroma.r, jpeg_color.g, jpeg_chroma.b), 0.68);
		filtered = floor(jpeg_color * levels + 0.5) / levels;
	} else if (mode == 63) {
		float mosh_size = max(effect_scale, 6.0);
		vec2 mosh_block = floor(pixel / vec2(mosh_size * 1.8, mosh_size));
		float mosh_gate = step(0.48, random_noise(mosh_block + floor(TIME * 1.6)));
		float mosh_age = fract(TIME * 0.21 + random_noise(mosh_block));
		vec2 mosh_vector = vec2(random_noise(mosh_block + 3.0) - 0.5, random_noise(mosh_block + 15.0) - 0.5);
		vec2 mosh_uv = uv - mosh_vector * mosh_size * (1.0 + mosh_age * 4.0) * texel * mosh_gate;
		vec3 mosh_color = texture(screen_texture, mosh_uv).rgb;
		filtered = mix(base, mosh_color.gbr, mosh_gate * (0.38 + mosh_age * 0.45));
	// Sci-fi analysis and targeting overlays (64-75).
	} else if (mode == 64) {
		float laser_y = fract(TIME * (0.16 + effect_scale * 0.008));
		float laser_line = exp(-abs(uv.y - laser_y) * screen_size.y * 0.12);
		float laser_afterglow = exp(-max(laser_y - uv.y, 0.0) * 18.0) * step(uv.y, laser_y);
		float laser_grid = max(step(0.97, fract(pixel.x / 48.0)), step(0.97, fract(pixel.y / 48.0))) * 0.18;
		float laser_signal = clamp(gray * 0.32 + edge * 1.35 + laser_line + laser_afterglow * 0.3 + laser_grid, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, laser_signal);
	} else if (mode == 65) {
		float depth_blur = luminance(textureLod(screen_texture, uv, clamp(effect_scale * 0.16, 0.0, 3.0)).rgb);
		float depth_value = clamp(depth_blur * 0.82 + (1.0 - length(uv - 0.5) * 1.2) * 0.18, 0.0, 1.0);
		filtered = thermal(depth_value);
	} else if (mode == 66) {
		float normal_step = max(effect_scale, 1.0);
		float normal_left = luminance(texture(screen_texture, uv - vec2(texel.x * normal_step, 0.0)).rgb);
		float normal_right = luminance(texture(screen_texture, uv + vec2(texel.x * normal_step, 0.0)).rgb);
		float normal_up = luminance(texture(screen_texture, uv - vec2(0.0, texel.y * normal_step)).rgb);
		float normal_down = luminance(texture(screen_texture, uv + vec2(0.0, texel.y * normal_step)).rgb);
		vec3 normal_color = normalize(vec3((normal_left - normal_right) * contrast * 3.0, (normal_up - normal_down) * contrast * 3.0, 1.0));
		filtered = normal_color * 0.5 + 0.5;
	} else if (mode == 67) {
		vec2 bio = (uv - 0.5) * vec2(1.0, 0.72);
		float bio_radius = length(bio);
		float bio_angle = atan(bio.y, bio.x);
		float bio_ridges = smoothstep(0.58, 0.82, sin(bio_radius * (90.0 + effect_scale * 2.0) + sin(bio_angle * 5.0) * 2.0));
		float bio_mask = 1.0 - smoothstep(0.27, 0.42, bio_radius);
		float bio_scan_y = fract(TIME * 0.24);
		float bio_scan = exp(-abs(uv.y - bio_scan_y) * screen_size.y * 0.08);
		float bio_signal = clamp(edge * 1.3 + bio_ridges * bio_mask * 0.65 + bio_scan, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, bio_signal);
	} else if (mode == 68) {
		vec3 satellite_base = mix(vec3(gray), base, 0.18);
		float satellite_grid = max(step(0.985, fract(uv.x * 12.0)), step(0.985, fract(uv.y * 8.0))) * 0.35;
		float satellite_cross = step(abs(uv.x - 0.5), 0.0015) + step(abs(uv.y - 0.5), 0.0015);
		float satellite_noise = (random_noise(pixel / max(effect_scale, 1.0) + floor(TIME * 2.0)) - 0.5) * 0.12;
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(luminance(satellite_base) + satellite_noise + satellite_grid + satellite_cross, 0.0, 1.0));
	} else if (mode == 69) {
		float drone_scan = 0.82 + 0.18 * step(0.5, fract(pixel.y * 0.5));
		vec2 drone_center = abs(uv - 0.5);
		float drone_bracket_x = step(0.16, drone_center.x) * step(drone_center.x, 0.18) * step(drone_center.y, 0.12);
		float drone_bracket_y = step(0.1, drone_center.y) * step(drone_center.y, 0.12) * step(drone_center.x, 0.18);
		float drone_horizon = step(abs(uv.y - 0.5), 0.0015) * step(0.1, drone_center.x);
		float drone_signal = clamp(gray * 0.55 + edge + drone_bracket_x + drone_bracket_y + drone_horizon, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, drone_signal) * drone_scan;
	} else if (mode == 70) {
		vec2 hud_center = abs(uv - 0.5);
		float hud_size = 0.11 + 0.025 * sin(TIME * 2.2);
		float hud_corner_x = step(hud_size, hud_center.x) * step(hud_center.x, hud_size + 0.012) * step(hud_center.y, hud_size * 0.62);
		float hud_corner_y = step(hud_size, hud_center.y) * step(hud_center.y, hud_size + 0.012) * step(hud_center.x, hud_size * 0.62);
		float hud_circle = smoothstep(0.005, 0.0, abs(length(uv - 0.5) - hud_size * 0.72));
		float hud_pulse = 0.75 + 0.25 * sin(TIME * (4.0 + effect_scale * 0.1));
		float hud_signal = clamp(gray * 0.28 + edge * 1.15 + (hud_corner_x + hud_corner_y + hud_circle) * hud_pulse, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, hud_signal);
	} else if (mode == 71) {
		vec2 scope_position = uv - 0.5;
		float scope_radius = length(scope_position);
		float scope_mask = 1.0 - smoothstep(0.43, 0.47, scope_radius);
		float scope_cross = step(abs(scope_position.x), 0.0015) + step(abs(scope_position.y), 0.0015);
		float scope_ring = smoothstep(0.004, 0.0, abs(scope_radius - 0.22));
		float scope_ticks = step(0.48, sin(atan(scope_position.y, scope_position.x) * 24.0)) * smoothstep(0.34, 0.36, scope_radius) * step(scope_radius, 0.39);
		float scope_signal = clamp(gray * 0.62 + edge * 0.85 + scope_cross + scope_ring + scope_ticks * 0.35, 0.0, 1.0);
		filtered = mix(vec3(0.0), mix(paper_color.rgb, ink_color.rgb, scope_signal), scope_mask);
	} else if (mode == 72) {
		float sonar_radius = length(uv - 0.5);
		float sonar_phase = fract(TIME * (0.22 + effect_scale * 0.006));
		float sonar_wave = exp(-abs(sonar_radius - sonar_phase * 0.68) * screen_size.y * 0.045);
		float sonar_echo = exp(-abs(sonar_radius - fract(sonar_phase + 0.55) * 0.68) * screen_size.y * 0.025) * 0.35;
		float sonar_rings = smoothstep(0.018, 0.0, abs(fract(sonar_radius * 8.0) - 0.5)) * 0.15;
		float sonar_signal = clamp(gray * 0.22 + edge * 1.3 + sonar_wave + sonar_echo + sonar_rings, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, sonar_signal);
	} else if (mode == 73) {
		float fault_band = floor(pixel.y / max(effect_scale, 2.0));
		float fault_gate = step(0.7, random_noise(vec2(fault_band, floor(TIME * 9.0))));
		float fault_shift = (random_noise(vec2(fault_band, floor(TIME * 13.0))) - 0.5) * effect_scale * 5.0 * fault_gate;
		vec2 fault_uv = uv + vec2(fault_shift * texel.x, sin(pixel.x * 0.04 + TIME * 5.0) * texel.y * effect_scale * 0.2);
		float fault_gray = luminance(texture(screen_texture, fault_uv).rgb);
		float fault_lines = 0.78 + 0.22 * sin(pixel.y * 2.2 + TIME * 8.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, clamp(fault_gray * 0.5 + edge * 1.2 + fault_gate * 0.3, 0.0, 1.0)) * fault_lines;
	} else if (mode == 74) {
		float tape_scan = 0.84 + 0.16 * step(0.5, fract(pixel.y * 0.5));
		float tape_border = step(uv.y, 0.055) + step(0.945, uv.y);
		vec2 code_uv = vec2(fract(uv.x * 42.0), fract((uv.y - 0.055) * 150.0));
		float code_seed = random_noise(vec2(floor(uv.x * 42.0), floor(TIME * 8.0)));
		float code_bar = step(code_uv.x, 0.64) * step(code_uv.y, 0.42) * step(0.38, code_seed) * step(uv.y, 0.105);
		float rec_dot = 1.0 - step(0.012, length(uv - vec2(0.035, 0.035)));
		float tape_signal = clamp(gray * 0.58 + edge * 0.65 + tape_border * 0.22 + code_bar + rec_dot, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, tape_signal) * tape_scan;
	} else if (mode == 75) {
		float gain_noise = random_noise(pixel + floor(TIME * 18.0));
		float hot_pixel = step(0.997 - effect_scale * 0.0002, gain_noise);
		float amplified = pow(clamp(gray * (2.2 + effect_scale * 0.12), 0.0, 1.0), 0.72);
		float gain_signal = clamp(amplified + (gain_noise - 0.5) * 0.35 + hot_pixel, 0.0, 1.0);
		filtered = mix(paper_color.rgb, ink_color.rgb, gain_signal);
	// Abstract geometry, procedural materials and coordinate remapping (76-87).
	} else if (mode == 76) {
		float poly_size = max(effect_scale, 6.0);
		vec2 poly_grid = pixel / poly_size;
		vec2 poly_cell = floor(poly_grid);
		vec2 poly_local = fract(poly_grid);
		float poly_triangle = step(poly_local.x + poly_local.y, 1.0);
		vec2 poly_center = poly_cell + (poly_triangle > 0.5 ? vec2(0.333, 0.333) : vec2(0.667, 0.667));
		vec2 poly_uv = poly_center * poly_size / screen_size;
		filtered = floor(adjusted(texture(screen_texture, poly_uv).rgb) * levels + 0.5) / levels;
	} else if (mode == 77) {
		float cubist_size = max(effect_scale * 3.0, 18.0);
		vec2 cubist_cell = floor(pixel / cubist_size);
		vec2 cubist_local = fract(pixel / cubist_size) - 0.5;
		float cubist_seed = random_noise(cubist_cell);
		float cubist_angle = (cubist_seed - 0.5) * 1.8;
		mat2 cubist_rotation = mat2(vec2(cos(cubist_angle), sin(cubist_angle)), vec2(-sin(cubist_angle), cos(cubist_angle)));
		vec2 cubist_rotated = cubist_rotation * cubist_local;
		vec2 cubist_uv = (cubist_cell + cubist_rotated + 0.5) * cubist_size / screen_size;
		filtered = texture(screen_texture, cubist_uv).rgb * tint_color.rgb;
	} else if (mode == 78) {
		float glass_size = max(effect_scale, 8.0);
		vec2 glass_grid = pixel / glass_size;
		vec2 glass_id = floor(glass_grid);
		vec2 glass_local = fract(glass_grid);
		vec2 glass_point = vec2(random_noise(glass_id), random_noise(glass_id + 17.3)) * 0.55 + 0.225;
		float glass_distance = length(glass_local - glass_point);
		vec2 glass_sample_uv = (glass_id + glass_point) * glass_size / screen_size;
		vec3 glass_color = floor(texture(screen_texture, glass_sample_uv).rgb * 6.0 + 0.5) / 6.0 * tint_color.rgb;
		float glass_lead = smoothstep(0.48, 0.4, glass_distance) * smoothstep(0.04, 0.11, glass_distance);
		filtered = glass_color * glass_lead;
	} else if (mode == 79) {
		float film_flow = fractal_noise(uv * (4.0 + effect_scale * 0.35) + vec2(TIME * 0.05, -TIME * 0.035));
		float film_phase = gray * 8.0 + film_flow * 10.0;
		vec3 iridescence = 0.5 + 0.5 * cos(film_phase + vec3(0.0, 2.094, 4.188));
		filtered = mix(base, iridescence, 0.58 + edge * 0.2);
	} else if (mode == 80) {
		vec2 marble_position = uv * (3.0 + effect_scale * 0.32);
		float marble_noise = fractal_noise(marble_position + vec2(TIME * 0.015, 0.0));
		float marble_vein = abs(sin((marble_position.x + marble_noise * 2.8) * 3.14159265));
		marble_vein = smoothstep(0.72, 0.96, marble_vein);
		filtered = mix(paper_color.rgb, ink_color.rgb, marble_vein * 0.82 + edge * 0.12);
	} else if (mode == 81) {
		vec2 lava_position = uv * (3.0 + effect_scale * 0.18);
		lava_position.y -= TIME * 0.12;
		float lava_a = fractal_noise(lava_position + vec2(sin(TIME * 0.2), 0.0));
		float lava_b = fractal_noise(lava_position * 1.7 - vec2(0.0, TIME * 0.08));
		float lava_blob = smoothstep(0.48, 0.7, lava_a * 0.72 + lava_b * 0.38);
		filtered = mix(paper_color.rgb, ink_color.rgb, lava_blob);
	} else if (mode == 82) {
		float melt_column = floor(pixel.x / max(effect_scale, 2.0));
		float melt_amount = random_noise(vec2(melt_column, floor(TIME * 0.7))) * effect_scale * 5.0;
		float melt_wave = sin(pixel.x * 0.025 + TIME * 1.7) * effect_scale;
		vec2 melt_uv = uv - vec2(0.0, (melt_amount + melt_wave) * texel.y * (0.3 + (1.0 - gray)));
		filtered = texture(screen_texture, melt_uv).rgb * tint_color.rgb;
	} else if (mode == 83) {
		float fractal = fractal_noise(uv * (4.0 + effect_scale * 0.42) + vec2(TIME * 0.04, -TIME * 0.03));
		vec3 fractal_color = 0.5 + 0.5 * cos(fractal * 9.0 + TIME * 0.15 + vec3(0.0, 2.0, 4.0));
		filtered = mix(base, fractal_color * tint_color.rgb, 0.52);
	} else if (mode == 84) {
		vec2 planet = uv - 0.5;
		float planet_radius = length(planet);
		float planet_angle = atan(planet.y, planet.x) / 6.2831853 + 0.5;
		float planet_latitude = clamp(planet_radius / 0.48, 0.0, 1.0);
		vec2 planet_uv = vec2(fract(planet_angle + TIME * 0.015), planet_latitude);
		vec3 planet_color = texture(screen_texture, planet_uv).rgb;
		float planet_mask = 1.0 - smoothstep(0.455, 0.485, planet_radius);
		float planet_light = clamp(1.15 - planet.x * (1.2 + effect_scale * 0.025), 0.18, 1.0);
		filtered = mix(base * 0.18, planet_color * planet_light, planet_mask);
	} else if (mode == 85) {
		vec2 infinity_center = uv - 0.5;
		vec3 infinity_color = source * 0.38;
		infinity_color += texture(screen_texture, infinity_center * 1.35 + 0.5).rgb * 0.27;
		infinity_color += texture(screen_texture, infinity_center * 1.8 + 0.5).rgb * 0.19;
		infinity_color += texture(screen_texture, infinity_center * 2.45 + 0.5).rgb * 0.11;
		infinity_color += texture(screen_texture, infinity_center * 3.2 + 0.5).rgb * 0.05;
		float infinity_ring = smoothstep(0.025, 0.0, abs(fract(length(infinity_center) * (8.0 + effect_scale * 0.3) - TIME * 0.12) - 0.5));
		filtered = infinity_color * tint_color.rgb + infinity_ring * 0.22;
	} else if (mode == 86) {
		float shard_size = max(effect_scale, 7.0);
		vec2 shard_grid = pixel / shard_size;
		vec2 shard_id = floor(shard_grid);
		vec2 shard_local = fract(shard_grid);
		float shard_half = step(shard_local.x, shard_local.y);
		vec2 shard_direction = normalize(vec2(random_noise(shard_id) - 0.5, random_noise(shard_id + 21.0) - 0.5) + vec2(0.001));
		vec2 shard_shift = shard_direction * shard_size * (0.08 + shard_half * 0.14) * texel;
		filtered = vec3(texture(screen_texture, uv + shard_shift).r, texture(screen_texture, uv - shard_shift.yx).g, texture(screen_texture, uv - shard_shift).b);
	} else if (mode == 87) {
		float pop_size = max(effect_scale, 6.0);
		vec2 pop_id = floor(pixel / pop_size);
		vec2 pop_uv = (pop_id * pop_size + pop_size * 0.5) / screen_size;
		vec3 pop_source = texture(screen_texture, pop_uv).rgb;
		float pop_gray = luminance(pop_source);
		vec3 pop_a = vec3(1.0, 0.18, 0.42) * tint_color.rgb;
		vec3 pop_b = vec3(0.05, 0.78, 1.0);
		vec3 pop_c = vec3(1.0, 0.88, 0.12);
		filtered = pop_gray < 0.34 ? pop_a : (pop_gray < 0.67 ? pop_b : pop_c);
		filtered *= 0.82 + 0.18 * step(0.5, random_noise(pop_id));
	}

	// Shared finishing stage. Presets can add subtle animated grain and vignette without duplicating
	// those operations in every branch; strength also guarantees a common path back to the source.
	float grain = (random_noise(pixel + floor(TIME * 8.0)) - 0.5) * grain_strength;
	filtered += grain;
	vec2 centered = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength;
	filtered *= clamp(vignette, 0.25, 1.0);
	COLOR = vec4(mix(source, clamp(filtered, 0.0, 1.0), strength), 1.0);
}
