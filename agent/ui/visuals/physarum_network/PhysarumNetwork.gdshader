shader_type canvas_item;

// Slime-mold veins over the live interface. Trail density becomes tubular veins embossed from
// their own gradient; food sources pulse as halos and spoiled food glows in the error color.
// Dark themes glow (screen blend); light themes stain like pigment. Zero activity is identity.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float field_time = 0.0;
uniform float trail_gain = 0.08;
uniform float vein_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vein_color : source_color = vec4(0.3, 0.8, 0.7, 1.0);
uniform vec4 core_color : source_color = vec4(0.9, 1.0, 0.9, 1.0);
uniform vec4 food_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

float vein(vec2 uv) {
	return 1.0 - exp(-texture(field_tex, uv).r * trail_gain);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec2 cell = vec2(1.0) / vec2(textureSize(field_tex, 0));
		vec4 field = texture(field_tex, SCREEN_UV);
		float v = 1.0 - exp(-field.r * trail_gain);
		vec2 slope = vec2(vein(SCREEN_UV + vec2(cell.x, 0.0)) - vein(SCREEN_UV - vec2(cell.x, 0.0)), vein(SCREEN_UV + vec2(0.0, cell.y)) - vein(SCREEN_UV - vec2(0.0, cell.y)));
		float relief = clamp(dot(slope, vec2(-0.7, -0.7)) * 4.0, -1.0, 1.0);
		float core = smoothstep(0.45, 0.95, v);
		float food = smoothstep(0.02, 0.6, field.g) * (0.75 + 0.25 * sin(field_time * 3.2));
		float spoiled = smoothstep(0.02, 0.6, -field.g);
		vec3 body = mix(vein_color.rgb, error_color.rgb, failure_tint * 0.7);
		vec3 tint = mix(body, core_color.rgb, core);
		float amount = v * vein_opacity * live;
		if (light_mode > 0.5) {
			vec3 ink = tint * (0.85 - relief * 0.25);
			result = mix(source, source * ink, amount);
			result = mix(result, result * food_color.rgb, food * 0.35 * live);
			result = mix(result, result * error_color.rgb, spoiled * 0.45 * live);
		} else {
			vec3 glow = tint * amount * (1.0 + relief * 0.35);
			result = vec3(1.0) - (vec3(1.0) - source) * (vec3(1.0) - glow);
			result += food_color.rgb * food * 0.18 * live;
			result += error_color.rgb * spoiled * 0.22 * live;
		}
	}
	COLOR = vec4(result, 1.0);
}
