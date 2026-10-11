shader_type canvas_item;

uniform vec4 accent_color : source_color = vec4(0.0, 0.84, 0.68, 1.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float launch_progress : hint_range(0.0, 1.0) = 0.0;

float segment_mask(vec2 point, vec2 start, vec2 end, float width) {
	vec2 segment = end - start;
	float progress = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	float distance_to_segment = length(point - (start + segment * progress));
	float edge = fwidth(distance_to_segment);
	return 1.0 - smoothstep(width - edge, width + edge, distance_to_segment);
}

void fragment() {
	vec2 point = UV - vec2(0.5);
	float distance_to_center = length(point);
	float edge_width = fwidth(distance_to_center);
	float circle = 1.0 - smoothstep(0.47 - edge_width, 0.47 + edge_width, distance_to_center);

	vec3 accent = accent_color.rgb;
	float center_light = 1.0 - smoothstep(0.0, 0.47, distance_to_center);
	vec3 vivid_accent = mix(accent, vec3(1.0), 0.09);
	vec3 color = mix(accent * 0.92, vivid_accent, center_light * 0.72 + 0.18);
	float idle_breathe = sin(TIME * 0.9) * 0.5 + 0.5;
	color *= 1.0 + idle_breathe * 0.015 * (1.0 - hover_strength);

	float rim = 1.0 - smoothstep(0.007, 0.02, abs(distance_to_center - 0.445));
	color += mix(accent, vec3(1.0), 0.48) * rim * mix(0.1, 0.18, hover_strength);
	float lower_shade = smoothstep(0.0, 0.46, point.y) * smoothstep(0.08, 0.47, distance_to_center);
	color *= 1.0 - lower_shade * 0.035;
	vec2 arrow_point = point + vec2(0.0, 0.045) * hover_strength;
	vec2 left = vec2(-0.145, -0.015);
	vec2 tip = vec2(0.0, -0.175);
	vec2 right = vec2(0.145, -0.015);
	vec2 stem_bottom = vec2(0.0, 0.19);
	float arrow = max(segment_mask(arrow_point, left, tip, 0.032), max(
		segment_mask(arrow_point, tip, right, 0.032),
		segment_mask(arrow_point, tip, stem_bottom, 0.032)));
	vec2 shadow_point = arrow_point - vec2(0.0, 0.022);
	float arrow_shadow = max(segment_mask(shadow_point, left, tip, 0.032), max(
		segment_mask(shadow_point, tip, right, 0.032),
		segment_mask(shadow_point, tip, stem_bottom, 0.032)));
	color = mix(color, vec3(0.0), arrow_shadow * 0.1);
	color = mix(color, vec3(1.0), arrow);

	vec3 energy_color = mix(accent, vec3(1.0), 0.82);
	vec2 visual_tip = tip - vec2(0.0, hover_strength * 0.045);
	float ripple_distance = abs(length(point - visual_tip) - launch_progress * 0.29);
	float ripple_edge = fwidth(ripple_distance);
	float ripple = (1.0 - smoothstep(0.012, 0.012 + ripple_edge, ripple_distance))
		* smoothstep(0.0, 0.12, launch_progress) * (1.0 - launch_progress);
	color += energy_color * ripple * 0.48;

	COLOR = vec4(color, circle * accent_color.a);
}
