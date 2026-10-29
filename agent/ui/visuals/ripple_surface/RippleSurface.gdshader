shader_type canvas_item;

// The live interface seen through a water surface: the height gradient refracts the screen,
// converging wavefronts brighten into caustics, and crests catch a specular accent glint.
// Light themes cannot brighten paper, so slopes facing away from the light and caustic crests
// stain with the accent ink instead. Zero activity or a flat field is an identity pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float refraction_px = 190.0;
uniform float max_offset_px = 32.0;
uniform float highlight_gain : hint_range(0.0, 1.0) = 1.0;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec2 cell = vec2(1.0) / vec2(textureSize(field_tex, 0));
		float center = texture(field_tex, SCREEN_UV).r;
		float left = texture(field_tex, SCREEN_UV - vec2(cell.x, 0.0)).r;
		float right = texture(field_tex, SCREEN_UV + vec2(cell.x, 0.0)).r;
		float up = texture(field_tex, SCREEN_UV - vec2(0.0, cell.y)).r;
		float down = texture(field_tex, SCREEN_UV + vec2(0.0, cell.y)).r;
		vec2 slope = vec2(right - left, down - up) * 0.5;
		vec2 offset_px = clamp(slope * refraction_px, vec2(-max_offset_px), vec2(max_offset_px));
		result = texture(screen_texture, clamp(SCREEN_UV + offset_px * SCREEN_PIXEL_SIZE * live, vec2(0.0), vec2(1.0))).rgb;

		vec3 normal = normalize(vec3(-slope * 14.0, 1.0));
		vec3 light_dir = normalize(vec3(-0.45, -0.6, 0.66));
		float caustic = clamp(-(left + right + up + down - 4.0 * center) * 36.0, 0.0, 1.0);
		vec3 tint = mix(accent_color.rgb, error_color.rgb, failure_tint);
		if (light_mode > 0.5) {
			float lambert = dot(normal, light_dir) - light_dir.z;
			float shade = smoothstep(0.0, 0.35, -lambert);
			float stain = clamp(shade * 0.9 + caustic * 0.6, 0.0, 0.9) * live * highlight_gain;
			result = mix(result, result * tint, stain);
			result *= 1.0 - shade * 0.12 * live;
		} else {
			float glint = pow(max(dot(normal, light_dir), 0.0), 28.0) - pow(light_dir.z, 28.0);
			result += tint * (clamp(glint, 0.0, 1.0) * 0.55 + caustic * 0.22) * live * highlight_gain;
		}
	}
	COLOR = vec4(result, 1.0);
}
