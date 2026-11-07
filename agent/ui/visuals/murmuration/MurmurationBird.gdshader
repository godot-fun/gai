shader_type canvas_item;
render_mode unshaded;

uniform float flap_frequency = 6.4;
uniform float glow_strength = 0.08;

varying flat float phase_offset;
varying flat float speed_share;
varying flat float state_energy;
varying flat float bank;

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float share = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return length(point - (start + segment * share));
}

void vertex() {
	phase_offset = INSTANCE_CUSTOM.x;
	speed_share = INSTANCE_CUSTOM.y;
	state_energy = INSTANCE_CUSTOM.z;
	bank = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float cycle = TIME * mix(flap_frequency * 0.74, flap_frequency * 1.08, clamp(speed_share, 0.0, 1.0)) + phase_offset * TAU;
	float flap = sin(cycle);
	float downstroke = smoothstep(-0.15, 0.85, flap);
	float upstroke = 1.0 - smoothstep(-0.9, 0.15, flap);
	float projected_span = mix(0.46, 0.86, 1.0 - upstroke) * mix(1.0, 0.82, speed_share);
	float sweep = mix(-0.26, -0.5, downstroke) - speed_share * 0.08;
	float wing_width = mix(0.105, 0.075, upstroke) * mix(1.0, 0.82, speed_share);

	vec2 root = vec2(0.08, 0.0);
	vec2 upper_elbow = vec2(-0.06, -projected_span * 0.48);
	vec2 lower_elbow = vec2(-0.06, projected_span * 0.48);
	vec2 upper_tip = vec2(sweep - bank * 0.07, -projected_span * (1.0 - bank * 0.16));
	vec2 lower_tip = vec2(sweep - bank * 0.07, projected_span * (1.0 + bank * 0.16));
	float upper_wing = min(segment_distance(point, root, upper_elbow), segment_distance(point, upper_elbow, upper_tip));
	float lower_wing = min(segment_distance(point, root, lower_elbow), segment_distance(point, lower_elbow, lower_tip));
	float upper_shape = upper_wing - wing_width * (1.0 + bank * 0.16);
	float lower_shape = lower_wing - wing_width * (1.0 - bank * 0.16);
	float wings = min(upper_shape, lower_shape);

	vec2 body_point = vec2((point.x - 0.08) / 0.58, point.y / mix(0.12, 0.085, speed_share));
	float body = length(body_point) - 1.0;
	float distance_to_bird = min(body, wings);
	float edge_softness = fwidth(distance_to_bird) * 1.15 + 0.003;
	float body_alpha = 1.0 - smoothstep(-edge_softness, edge_softness, distance_to_bird);
	float glow_alpha = (1.0 - smoothstep(0.0, 0.12, distance_to_bird)) * (1.0 - body_alpha);

	float head_to_tail = smoothstep(-0.48, 0.66, point.x);
	float is_upper = 1.0 - step(0.0, point.y);
	float bank_light = mix(1.0 - bank * 0.22, 1.0 + bank * 0.22, is_upper);
	float upstroke_fade = mix(1.0, 0.68, upstroke * smoothstep(0.16, 0.8, abs(point.y)));
	float breath = 0.96 + 0.04 * sin(TIME * 1.8 + phase_offset * TAU * 1.7);
	float brightness = mix(0.76, 1.14, head_to_tail) * bank_light * upstroke_fade * breath;
	brightness *= 1.0 + state_energy * 0.18;

	vec3 bird_color = COLOR.rgb * brightness;
	vec3 glow_color = COLOR.rgb * (1.06 + state_energy * 0.25);
	float alpha = COLOR.a * clamp(body_alpha * mix(0.82, 1.0, head_to_tail) * upstroke_fade + glow_alpha * glow_strength * (1.0 + state_energy), 0.0, 1.0);
	vec3 final_color = mix(glow_color, bird_color, body_alpha);
	COLOR = vec4(final_color, alpha);
}
