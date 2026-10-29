shader_type canvas_item;

// E-paper panel over the live interface: luminance is quantized to 16 gray levels with ordered
// dither on paper-grain stock, a little of the source color survives like a color filter layer,
// and partial refreshes leave a faint ghost one text line up. Refresh regions run the panel's
// waveforms: partial (inverted, black, white, settle), fast 1-bit, a pulsing busy region, and
// stuck pixels after a failure.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform float ghost : hint_range(0.0, 1.0) = 0.0;
uniform float panel_time = 0.0;
uniform int refresh_count = 0;
// (x0, y0, x1, y1) in screen UV
uniform vec4 refresh_rect[16];
// (progress 0..1, mode, error, seed)
uniform vec4 refresh_state[16];
uniform vec4 paper_color : source_color = vec4(0.93, 0.92, 0.88, 1.0);
uniform vec4 ink_color : source_color = vec4(0.13, 0.13, 0.14, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

const float LEVELS = 15.0;
const float GHOST_SHIFT = 0.042;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bayer4(vec2 px) {
	ivec2 c = ivec2(mod(px, 4.0));
	int index = c.x + c.y * 4;
	int table[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(table[index]) + 0.5) / 16.0 - 0.5;
}

float panel_level(vec3 color, vec2 px) {
	float lum = dot(color, LUMA);
	return clamp(floor(lum * LEVELS + 0.5 + bayer4(px)) / LEVELS, 0.0, 1.0);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 px = floor(SCREEN_UV * viewport_px);
	vec3 result = source;
	if (presence > 0.001) {
		vec3 paper = paper_color.rgb;
		vec3 ink = ink_color.rgb;
		float grain = (hash12(px * 0.5) - 0.5) * 0.035 + (hash12(floor(px / 3.0) + 17.0) - 0.5) * 0.02;
		paper += grain;
		float level = panel_level(source, px);
		float lum = dot(source, LUMA);
		vec3 tone = mix(ink, paper, level);
		vec3 image = clamp(tone + (source - vec3(lum)) * 0.22, 0.0, 1.0);
		vec3 inverted = mix(paper, ink, level);

		vec3 ghost_source = texture(screen_texture, SCREEN_UV + vec2(0.0, GHOST_SHIFT)).rgb;
		vec3 ghost_tone = mix(ink, paper, panel_level(ghost_source, px));
		vec3 panel = mix(image, min(image, mix(paper, ghost_tone, 0.55)), ghost);

		for (int index = 0; index < refresh_count; index++) {
			vec4 r = refresh_rect[index];
			if (SCREEN_UV.x < r.x || SCREEN_UV.y < r.y || SCREEN_UV.x > r.z || SCREEN_UV.y > r.w) {
				continue;
			}
			vec4 state = refresh_state[index];
			vec2 local = (SCREEN_UV - r.xy) / max(r.zw - r.xy, vec2(0.0001));
			float mode = state.y;
			vec3 flash_ink = mix(ink, error_color.rgb * 0.7, state.z * 0.6);
			if (mode < 0.5) {
				// Partial waveform; rows are driven top to bottom.
				float t = clamp(state.x * 1.25 - local.y * 0.25, 0.0, 1.0);
				if (t < 0.18) {
					panel = inverted;
				} else if (t < 0.36) {
					panel = flash_ink;
				} else if (t < 0.54) {
					panel = paper;
				} else {
					float settle = 1.0 - smoothstep(0.54, 1.0, t);
					panel = mix(panel, inverted, settle * 0.3);
				}
			} else if (mode < 1.5) {
				// Fast 1-bit update with flipped-pixel sparkle while it lasts.
				float t = state.x;
				if (t < 0.65) {
					float bit = step(0.5, lum + bayer4(px) * 0.4);
					float flip = step(1.0 - (1.0 - t / 0.65) * 0.35, hash12(floor(px / 2.0) + floor(panel_time * 30.0)));
					bit = abs(bit - flip);
					panel = mix(ink, paper, bit);
				}
			} else if (mode < 2.5) {
				// Busy: marching dashed border and an inner checker that blinks twice a second.
				vec2 rect_px = (r.zw - r.xy) * viewport_px;
				vec2 from_edge = min(local, 1.0 - local) * rect_px;
				float border = step(min(from_edge.x, from_edge.y), 3.0);
				float along = (local.x + local.y) * (rect_px.x + rect_px.y) * 0.5;
				float dash = step(0.5, fract((along - panel_time * 40.0) / 16.0));
				float checker = mod(floor(px.x / 3.0) + floor(px.y / 3.0), 2.0);
				float blink = step(0.5, state.x);
				panel = mix(panel, mix(panel, inverted, checker), 0.35 * blink);
				panel = mix(panel, ink, border * dash);
			} else {
				// Stuck pixels: the inverted ghost and dead rows freeze in place, then slowly let go.
				float fade = 1.0 - smoothstep(0.65, 1.0, state.x);
				float dead_row = step(0.82, hash12(vec2(floor(px.y / 2.0), state.w * 97.0)));
				float dead_px = step(0.93, hash12(floor(px / 3.0) + state.w * 31.0));
				vec3 stuck = mix(panel, inverted, 0.35);
				stuck = mix(stuck, flash_ink, max(dead_row * 0.7, dead_px));
				panel = mix(panel, stuck, fade);
			}
		}
		result = mix(source, panel, presence);
	}
	COLOR = vec4(result, 1.0);
}
