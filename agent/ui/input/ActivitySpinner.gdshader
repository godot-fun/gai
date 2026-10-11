shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(1.0);
uniform float radius : hint_range(0.1, 0.5) = 0.34;
uniform float thickness : hint_range(0.01, 0.2) = 0.035;
uniform float arc_length : hint_range(0.1, 0.95) = 0.68;
uniform float track_opacity : hint_range(0.0, 1.0) = 0.1;
uniform float tail_opacity : hint_range(0.0, 1.0) = 0.2;
uniform float speed = 1.1;

void fragment() {
	vec2 point = UV - vec2(0.5);
	float raw_angle = atan(point.y, point.x);
	float turn = raw_angle / 6.28318530718;
	float distance_to_ring = abs(length(point) - radius);
	float ring_edge = fwidth(distance_to_ring);
	float ring = 1.0 - smoothstep(thickness, thickness + ring_edge, distance_to_ring);

	float phase = fract(turn - TIME * speed);
	float arc_edge = fwidth(phase);
	float arc_start = smoothstep(0.0, arc_edge * 2.0, phase);
	float arc_end = 1.0 - smoothstep(arc_length - arc_edge * 2.0, arc_length, phase);
	float arc = arc_start * arc_end;
	float trail = mix(tail_opacity, 1.0, smoothstep(0.0, arc_length, phase));
	float active_arc = ring * arc * trail;

	float head_angle = (TIME * speed + arc_length) * 6.28318530718;
	vec2 head_center = vec2(cos(head_angle), sin(head_angle)) * radius;
	float head_distance = length(point - head_center);
	float head_edge = fwidth(head_distance);
	float head = 1.0 - smoothstep(thickness, thickness + head_edge, head_distance);
	float alpha = max(ring * track_opacity, max(active_arc, head));

	COLOR = vec4(ring_color.rgb, ring_color.a * alpha);
}
