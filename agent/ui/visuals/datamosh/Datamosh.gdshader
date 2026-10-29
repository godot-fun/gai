shader_type canvas_item;

// Datamosh display: stuck macroblocks show the dragged field instead of the live interface, with
// chroma bleeding off the luma like a starved decoder. Corruption swaps some blocks for flat DCT
// ringing. A keyframe sweeps down the screen and every row it has passed is clean again.
// Zero activity is an identity pass.

const int MAX_SOURCES = 4;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D field_tex : repeat_disable, filter_nearest;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform float mosh : hint_range(0.0, 1.0) = 0.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
// Sweep line in screen UV; values past 1.1 mean no keyframe is landing.
uniform float keyframe = 1.2;
uniform float block_px = 16.0;
uniform float block_seed = 0.0;
uniform float bleed_px = 3.0;
uniform int source_count = 0;
uniform vec4 source_shapes[4];
uniform vec4 keyframe_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform vec4 corrupt_tint : source_color = vec4(1.0, 0.2, 0.8, 1.0);

float block_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 to_ycc(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	return vec3(y, (c.b - y) * 0.564, (c.r - y) * 0.713);
}

vec3 to_rgb(vec3 ycc) {
	return vec3(ycc.x + 1.403 * ycc.z, ycc.x - 0.344 * ycc.y - 0.714 * ycc.z, ycc.x + 1.773 * ycc.y);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec2 block = floor(SCREEN_UV * viewport_px / block_px);
		vec2 block_center = (block + 0.5) * block_px / viewport_px;
		float view_aspect = viewport_px.x / max(viewport_px.y, 1.0);
		float local = mosh;
		for (int index = 0; index < MAX_SOURCES; index++) {
			if (index >= source_count) {
				break;
			}
			vec2 delta = (block_center - source_shapes[index].xy) * vec2(view_aspect, 1.0);
			float radius = max(source_shapes[index].z, 0.001);
			local += source_shapes[index].w * exp(-dot(delta, delta) / (radius * radius));
		}
		// Blocks re-roll on staggered beats so the stuck pattern crawls instead of flashing.
		float stagger = block_hash(block * 0.37 + vec2(3.1, 7.7));
		float pick = block_hash(block + vec2(floor(block_seed + stagger) * 17.0, 3.0));
		float hold = step(pick, clamp(local, 0.0, 0.95));
		if (keyframe < 1.1 && block.y * block_px / viewport_px.y < keyframe) {
			hold = 0.0;
		}

		vec3 dragged = texture(field_tex, SCREEN_UV).rgb;
		// The field is fed back from this output, so nothing here may scale colors per frame.
		vec2 bleed = vec2(bleed_px, bleed_px * 0.35) * SCREEN_PIXEL_SIZE;
		vec3 smeared = texture(field_tex, SCREEN_UV + bleed).rgb;
		vec3 moshed = to_rgb(vec3(to_ycc(dragged).x, to_ycc(smeared).yz));

		float corrupt_pick = block_hash(block + vec2(41.0, floor(block_seed) * 3.0));
		if (corrupt_pick < corruption * 0.3 * clamp(local, 0.0, 1.0)) {
			// A lost block decodes to its average color plus one ringing DCT basis.
			vec2 cell = fract(SCREEN_UV * viewport_px / (block_px * 0.5));
			float freq_x = 1.0 + floor(block_hash(block + vec2(9.0, 1.0)) * 4.0);
			float freq_y = 1.0 + floor(block_hash(block + vec2(2.0, 8.0)) * 4.0);
			float basis = cos(cell.x * PI * freq_x) * cos(cell.y * PI * freq_y);
			vec3 average = textureLod(screen_texture, block_center, 0.0).rgb;
			vec3 tinted = mix(average, corrupt_tint.rgb * (0.35 + dot(average, vec3(0.333))), 0.5 * failure_tint);
			moshed = clamp(tinted + basis * 0.14, 0.0, 1.0);
			hold = 1.0;
		}
		result = mix(source, clamp(moshed, 0.0, 1.0), hold);

		if (keyframe < 1.1) {
			float line = exp(-abs(SCREEN_UV.y - keyframe) * viewport_px.y / 4.0);
			result = mix(result, keyframe_color.rgb, line * 0.55);
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
