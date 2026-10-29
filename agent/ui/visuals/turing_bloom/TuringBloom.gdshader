shader_type canvas_item;

// Living tissue grown from the catalyst field. The membrane is embossed from the catalyst
// gradient and laid over the live interface with capped coverage so text stays legible.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float coverage_gain : hint_range(0.0, 1.0) = 0.5;
uniform float glow_gain : hint_range(0.0, 1.0) = 1.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 tissue_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 membrane_color : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

float catalyst(vec2 uv) {
	return texture(field_tex, uv).g;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float live = smoothstep(0.0, 0.02, activity) * body_mask;
	vec3 result = source;
	if (live > 0.001) {
		vec2 cell = vec2(1.0) / vec2(textureSize(field_tex, 0));
		float b = catalyst(SCREEN_UV);
		vec2 slope = vec2(catalyst(SCREEN_UV + vec2(cell.x, 0.0)) - catalyst(SCREEN_UV - vec2(cell.x, 0.0)),
			catalyst(SCREEN_UV + vec2(0.0, cell.y)) - catalyst(SCREEN_UV - vec2(0.0, cell.y)));
		float tissue = smoothstep(0.1, 0.3, b);
		float membrane = smoothstep(0.08, 0.16, b) - smoothstep(0.2, 0.32, b);
		float relief = clamp(dot(slope, vec2(-0.7, -0.7)) * 6.0, -1.0, 1.0);

		vec3 body = mix(tissue_color.rgb, error_color.rgb * 0.6 + vec3(0.25), failure_tint);
		vec3 rim = mix(membrane_color.rgb, vec3(0.92), failure_tint);
		vec3 tinted = mix(source, body * (0.78 + relief * 0.28), tissue * coverage_gain);
		tinted += rim * membrane * 0.36 * glow_gain;
		result = mix(source, tinted, live);
	}
	COLOR = vec4(result, 1.0);
}
