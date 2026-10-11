shader_type canvas_item;

uniform vec4 error_color : source_color = vec4(0.85, 0.3, 0.3, 1.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float containment_progress : hint_range(0.0, 1.0) = 0.0;

float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 offset = abs(point) - half_size + vec2(radius);
	return length(max(offset, vec2(0.0))) + min(max(offset.x, offset.y), 0.0) - radius;
}

void fragment() {
	vec2 point = UV - vec2(0.5);
	float distance_to_center = length(point);
	float circle_edge = fwidth(distance_to_center);
	float circle = 1.0 - smoothstep(0.47 - circle_edge, 0.47 + circle_edge, distance_to_center);

	vec3 error = error_color.rgb;
	float center_light = 1.0 - smoothstep(0.0, 0.47, distance_to_center);
	float breathe = sin(TIME * 1.25) * 0.5 + 0.5;
	vec3 color = mix(error * 0.86, mix(error, vec3(1.0), 0.08), center_light * 0.7);
	color *= 1.0 + breathe * 0.018 * (1.0 - hover_strength);

	float containment_radius = mix(0.43, 0.15, containment_progress);
	float containment_distance = abs(distance_to_center - containment_radius);
	float containment_edge = fwidth(containment_distance);
	float containment_ring = 1.0 - smoothstep(0.012, 0.012 + containment_edge, containment_distance);
	float containment_fade = sin(containment_progress * 3.14159265359) * hover_strength;
	color += mix(error, vec3(1.0), 0.72) * containment_ring * containment_fade * 0.52;

	float stop_scale = mix(1.0, 1.05, hover_strength);
	float stop_distance = rounded_box_distance(point / stop_scale, vec2(0.125), 0.032);
	float stop_edge = fwidth(stop_distance);
	float stop_square = 1.0 - smoothstep(-stop_edge, stop_edge, stop_distance);
	float shadow_distance = rounded_box_distance((point - vec2(0.0, 0.02)) / stop_scale,
		vec2(0.125), 0.032);
	float stop_shadow = 1.0 - smoothstep(-stop_edge, stop_edge, shadow_distance);
	color = mix(color, vec3(0.0), stop_shadow * 0.1);
	color = mix(color, vec3(1.0), stop_square);

	COLOR = vec4(color, circle * error_color.a);
}
