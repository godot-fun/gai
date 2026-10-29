shader_type canvas_item;

// Ink carried by the fluid field over the live interface. The flow also refracts the screen a
// little, as if the UI sits under moving liquid. Dark themes glow (screen blend); light themes
// absorb like watercolor: density deepens the pigment and it pools darker along plume edges.
// Zero activity or an empty field is an identity pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float ink_gain : hint_range(0.0, 1.0) = 0.7;
uniform float glow_blend : hint_range(0.0, 1.0) = 1.0;
uniform float refraction_px = 5.0;
uniform vec4 warm_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 cool_color : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float live = smoothstep(0.0, 0.02, activity);
	vec3 result = source;
	if (live > 0.001) {
		vec4 field = texture(field_tex, SCREEN_UV);
		vec2 offset = clamp(field.rg, vec2(-4.0), vec2(4.0)) * refraction_px * SCREEN_PIXEL_SIZE * live;
		vec3 carried = texture(screen_texture, clamp(SCREEN_UV - offset, vec2(0.0), vec2(1.0))).rgb;
		float amount = smoothstep(0.0, 0.85, abs(field.a)) * ink_gain * live;
		vec3 ink = field.a >= 0.0 ? warm_color.rgb : cool_color.rgb;
		ink = mix(ink, error_color.rgb, failure_tint * 0.8);
		if (glow_blend > 0.5) {
			result = vec3(1.0) - (vec3(1.0) - carried) * (vec3(1.0) - ink * amount);
		} else {
			vec2 cell = vec2(1.0) / vec2(textureSize(field_tex, 0));
			vec2 grad = vec2(abs(texture(field_tex, SCREEN_UV + vec2(cell.x, 0.0)).a) - abs(texture(field_tex, SCREEN_UV - vec2(cell.x, 0.0)).a),
				abs(texture(field_tex, SCREEN_UV + vec2(0.0, cell.y)).a) - abs(texture(field_tex, SCREEN_UV - vec2(0.0, cell.y)).a));
			float edge = smoothstep(0.04, 0.3, length(grad)) * smoothstep(0.0, 0.3, abs(field.a));
			float depth = amount * 1.7 + edge * 0.9 * ink_gain * live;
			result = carried * pow(max(ink, vec3(0.04)), vec3(depth));
		}
		result = mix(source, result, live);
	}
	COLOR = vec4(result, 1.0);
}
