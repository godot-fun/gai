shader_type canvas_item;

uniform vec4 accent_color : source_color = vec4(0.0, 0.85, 0.72, 1.0);
uniform vec2 canvas_size = vec2(1.0);
uniform vec2 anchor_position = vec2(0.0);
uniform vec2 cursor_position = vec2(0.0);
uniform float pointer_visible = 0.0;
uniform float speed_factor : hint_range(0.0, 1.0) = 0.0;
uniform float boundary_factor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * canvas_size;
	vec2 delta = cursor_position - anchor_position;
	float distance_to_cursor = max(length(delta), 0.001);
	vec2 direction = delta / distance_to_cursor;
	vec2 normal = vec2(-direction.y, direction.x);

	// The tether stops at the arrow base, so it is also the arrow's perfectly matched tail.
	// Distance changes the aspect ratio: nearby pointers are compact, distant pointers
	// grow longer while their base narrows, producing a visibly sharper tip.
	float distance_factor = clamp((distance_to_cursor - 20.0) / 300.0, 0.0, 1.0);
	float movement_factor = smoothstep(0.18, 0.82, speed_factor);
	float head_length = min(16.0 + distance_factor * 16.0 + speed_factor * 4.0, distance_to_cursor * 0.45) * mix(1.0, 0.72, boundary_factor);
	vec2 head_base = cursor_position - direction * head_length;
	vec2 line_segment = head_base - anchor_position;
	float line_length_squared = max(dot(line_segment, line_segment), 0.0001);
	float line_projection = clamp(dot(p - anchor_position, line_segment) / line_length_squared, 0.0, 1.0);
	float line_wave_envelope = sin(line_projection * 3.1415926);
	float line_wave = sin(line_projection * 34.0 - TIME * 10.0) * movement_factor * 0.85 * line_wave_envelope;
	vec2 line_point = anchor_position + line_segment * line_projection + normal * line_wave;
	float line_distance = length(p - line_point);
	float line_field = line_distance - 1.25;

	vec2 head_delta = p - cursor_position;
	float head_x = dot(head_delta, direction);
	float head_y = dot(head_delta, normal);
	float head_half_width = mix(9.0, 6.0, distance_factor);
	float head_field = max(max(head_x, -head_x - head_length), abs(head_y) - (-head_x / max(head_length, 0.001)) * head_half_width);

	// Four short marks pass the pointer on alternating sides. Staggered phases
	// keep only a few visible at once and make them slide toward the anchor.
	float streak_phase_1 = fract(TIME * 1.75);
	float streak_phase_2 = fract(TIME * 1.75 + 0.27);
	float streak_phase_3 = fract(TIME * 1.75 + 0.54);
	float streak_phase_4 = fract(TIME * 1.75 + 0.81);
	float streak_x_1 = -8.0 - streak_phase_1 * 88.0;
	float streak_x_2 = -10.0 - streak_phase_2 * 100.0;
	float streak_x_3 = -7.0 - streak_phase_3 * 76.0;
	float streak_x_4 = -12.0 - streak_phase_4 * 92.0;
	float streak_1 = (1.0 - smoothstep(-0.15, 0.75, max(abs(head_y - head_half_width - 4.0) - 0.35, abs(head_x - streak_x_1) - 5.0))) * (1.0 - smoothstep(0.58, 0.92, streak_phase_1));
	float streak_2 = (1.0 - smoothstep(-0.15, 0.75, max(abs(head_y + head_half_width + 5.0) - 0.35, abs(head_x - streak_x_2) - 4.0))) * (1.0 - smoothstep(0.52, 0.88, streak_phase_2));
	float streak_3 = (1.0 - smoothstep(-0.15, 0.75, max(abs(head_y - head_half_width - 8.0) - 0.35, abs(head_x - streak_x_3) - 3.5))) * (1.0 - smoothstep(0.46, 0.80, streak_phase_3));
	float streak_4 = (1.0 - smoothstep(-0.15, 0.75, max(abs(head_y + head_half_width + 9.0) - 0.35, abs(head_x - streak_x_4) - 4.5))) * (1.0 - smoothstep(0.42, 0.76, streak_phase_4));
	float speed_streaks = max(max(streak_1, streak_2), max(streak_3, streak_4)) * movement_factor * pointer_visible;

	vec2 center_delta = p - anchor_position;
	float center_field = length(center_delta) - 8.0;
	float center_body = 1.0 - smoothstep(-0.75, 0.75, center_field);
	float line_body = (1.0 - smoothstep(-0.75, 0.75, line_field)) * pointer_visible;
	float head_body = (1.0 - smoothstep(-0.75, 0.75, head_field)) * pointer_visible;
	float body = max(center_body, max(line_body, head_body));
	float pointer_field = min(line_field, head_field);
	float field = min(center_field, mix(10000.0, pointer_field, pointer_visible));
	float near_glow = (1.0 - smoothstep(0.0, 5.0, max(field, 0.0))) * (1.0 - body);
	float far_glow = (1.0 - smoothstep(3.0, 12.0, max(field, 0.0))) * (1.0 - body);

	// The center ring charges clockwise with distance and rotates slightly at high speed.
	float center_angle = atan(center_delta.y, center_delta.x) / 6.2831853 + 0.5;
	float ring_progress = fract(center_angle + 0.25 - TIME * speed_factor * 0.08);
	float charge = clamp((distance_to_cursor - 10.0) / 260.0, 0.0, 1.0) * pointer_visible;
	float charge_arc = 1.0 - smoothstep(charge, charge + 0.025, ring_progress);
	float charge_ring = (1.0 - smoothstep(0.7, 1.8, abs(length(center_delta) - 12.5))) * charge_arc;

	// At either scroll boundary the center emits a calm pulse while the tether loses energy.
	float boundary_phase = fract(TIME * 1.35);
	float boundary_radius = 11.0 + boundary_phase * 17.0;
	float boundary_ring = (1.0 - smoothstep(0.8, 2.0, abs(length(center_delta) - boundary_radius))) * (1.0 - boundary_phase) * boundary_factor;

	float segment_length = max(length(head_base - anchor_position), 0.001);
	float pulse = 0.9 + sin(TIME * 3.0) * 0.06;
	float along = dot(p - anchor_position, direction);
	float line_progress = clamp(along / segment_length, 0.0, 1.0);
	float scan_position = fract(TIME * (0.16 + speed_factor * 0.10));
	float scan = (1.0 - smoothstep(0.0, 0.15, abs(line_progress - scan_position))) * line_body;
	float line_energy = line_body * (0.48 + line_progress * 0.42) * mix(1.0, 0.58, boundary_factor);
	float head_energy = head_body * (0.92 + speed_factor * 0.18);
	float center_energy = center_body * 0.82;
	float core_energy = max(center_energy, max(line_energy, head_energy));
	// Higher speed shifts gently toward a cooler white without changing semantic color.
	vec3 energy_color = mix(accent_color.rgb, vec3(0.86, 0.95, 1.0), speed_factor * 0.22);
	vec3 core = mix(energy_color, vec3(1.0), 0.10 + scan * 0.12);
	float alpha = core_energy * pulse + near_glow * (0.30 + speed_factor * 0.12) + far_glow * 0.09 + charge_ring * 0.48 + boundary_ring * 0.48 + speed_streaks * 0.56;
	vec3 final_color = mix(accent_color.rgb, core, body);
	final_color = mix(final_color, energy_color, clamp(speed_streaks * 0.72, 0.0, 1.0));
	COLOR = vec4(final_color, min(alpha, 1.0) * accent_color.a);
}
