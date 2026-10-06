shader_type canvas_item;
render_mode unshaded;

// Runtime contract with NeuralAurora.gd. Event parameters are normalized to 0..1 except
// `direction` (-1..1), `tool_angle` (radians), and `aspect` (viewport width / height).
uniform vec4 accent_color : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform vec4 success_color : source_color = vec4(0.25, 0.9, 0.55, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.25, 0.32, 1.0);
uniform float energy = 0.0;
uniform float detail = 0.0;
uniform float output_pulse = 0.0;
uniform float tool_pulse = 0.0;
uniform float tool_angle = 0.0;
uniform float success_pulse = 0.0;
uniform float failure_pulse = 0.0;
uniform float failure_progress = 0.0;
uniform float direction = 1.0;
uniform float completion = 0.0;
uniform float aspect = 1.777;

float hash21(vec2 p) {
	// Cheap deterministic hash: sufficient for an animated atmospheric texture and avoids a
	// sampled noise texture, keeping the effect self-contained and theme-independent.
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	// Five octaves are the main GPU cost. Reduce this loop first for a low-quality mode; adding
	// octaves beyond five gives little visible benefit at typical desktop resolutions.
	float value = 0.0;
	float weight = 0.52;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * weight;
		p = mat2(vec2(1.62, 1.18), vec2(-1.18, 1.62)) * p + 0.17;
		weight *= 0.48;
	}
	return value;
}

void fragment() {
	// Work in aspect-correct centered coordinates so circles stay circular on wide windows.
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float t = TIME * direction;
	// Domain-warped FBM forms broad cloud masses. `detail` tightens the sampling scale during
	// reasoning, while signed time makes a turn change visibly reverse the whole field.
	vec2 flow = p * (2.1 + detail * 1.8);
	flow += vec2(fbm(flow * 0.75 + vec2(t * 0.055, -t * 0.04)), fbm(flow * 0.8 + vec2(-t * 0.045, t * 0.06))) * 1.25;
	float cloud = fbm(flow + vec2(0.0, t * 0.12));
	float curtain = pow(clamp(1.0 - abs(sin(flow.x * 2.0 + cloud * 5.4 + t * 0.22)), 0.0, 1.0), 3.2);
	float horizon = smoothstep(0.66, 0.02, abs(p.y + 0.03 + (cloud - 0.5) * 0.34));
	float wake = smoothstep(0.72, 0.08, radius) * smoothstep(0.0, 0.85, energy);
	vec3 cool = mix(accent_color.rgb * 0.32, accent_color.rgb * 1.25 + vec3(0.04, 0.12, 0.18), cloud);
	vec3 color = cool * curtain * horizon * (0.1 + wake * 0.9);
	color += accent_color.rgb * exp(-radius * (11.0 - energy * 3.0)) * (0.38 + energy * 1.35);

	// Thin thresholded ridges read as neural impulses without introducing individual particles.
	float neural_cells = smoothstep(0.91, 0.985, sin((flow.x + flow.y) * 26.0 + cloud * 17.0) * 0.5 + 0.5);
	color += accent_color.rgb * neural_cells * detail * horizon * 0.42;

	// Content output: a warm ring repeatedly expands from the core while its CPU envelope lives.
	float wave_radius = fract(TIME * 0.34) * 0.9;
	float wave = exp(-abs(radius - wave_radius) * 80.0) * output_pulse;
	color += mix(accent_color.rgb, vec3(1.0, 0.56, 0.25), 0.7) * wave * (1.0 - wave_radius) * 1.4;

	// Tool execution: a narrow radial arc. `tool_pulse` doubles as the travelling head distance.
	float angle_delta = abs(atan(sin(angle - tool_angle), cos(angle - tool_angle)));
	float arc = exp(-angle_delta * 130.0) * smoothstep(0.02, 0.16, radius) * smoothstep(0.95, 0.22, radius);
	float arc_head = exp(-abs(radius - tool_pulse * 0.9) * 55.0);
	color += vec3(0.72, 0.92, 1.0) * arc * (0.28 + arc_head * 2.6) * smoothstep(0.0, 0.08, tool_pulse);

	// Tool result: success contracts inward. Failure is a one-way explosion: moving streak
	// segments launch at the core, carry their own fading tails, and continue beyond the viewport.
	float return_ring = exp(-abs(radius - (0.82 - success_pulse * 0.72)) * 38.0) * success_pulse;
	color += success_color.rgb * return_ring * 1.25;
	float ray_index = floor((angle + PI) / TAU * 38.0);
	float ray_seed = hash21(vec2(ray_index, 17.0));
	float ray_shape = abs(sin(angle * (17.0 + floor(ray_seed * 5.0)) + ray_seed * 8.0));
	float ray_body = 1.0 - smoothstep(0.0, mix(0.018, 0.034, ray_seed), ray_shape);
	float ray_core = 1.0 - smoothstep(0.0, mix(0.004, 0.009, ray_seed), ray_shape);
	float ray_brightness = mix(0.38, 1.0, ray_seed);
	// A fast ease-out launch reads as an explosion; 1.45 carries every ray beyond the short edge.
	float burst_front = mix(0.015, 1.45, pow(failure_progress, 0.58));
	float tail_length = mix(0.18, 0.42, ray_seed);
	float tail_start = burst_front - tail_length;
	float moving_tail = smoothstep(tail_start, tail_start + 0.08, radius) * (1.0 - smoothstep(burst_front - 0.025, burst_front + 0.035, radius));
	float hot_head = exp(-abs(radius - burst_front) * mix(55.0, 90.0, ray_seed));
	float rays = (ray_body * 0.48 + ray_core * 1.05) * ray_brightness;
	float core_flash = exp(-radius / 0.055) * (1.0 - smoothstep(0.0, 0.16, failure_progress));
	float shock = exp(-abs(radius - burst_front * 0.62) * 48.0) * (1.0 - smoothstep(0.12, 0.82, failure_progress));
	color += error_color.rgb * failure_pulse * (core_flash * 2.0 + shock * 0.62 + rays * moving_tail * 1.5 + rays * hot_head * 1.4);

	// Completion owns the final composition: compress the field into a luminous ring, break its
	// edge into quantized noise "dust", then reach zero alpha before the Control fades out.
	float final_ring = exp(-abs(radius - mix(0.08, 0.33, smoothstep(0.0, 0.55, completion))) * 65.0);
	float dissolve = smoothstep(0.56, 1.0, completion);
	float dust = smoothstep(0.82, 1.0, noise(floor(p * 180.0) + floor(TIME * 5.0))) * dissolve;
	color = mix(color, accent_color.rgb * final_ring * 2.2, smoothstep(0.0, 0.75, completion));
	color += accent_color.rgb * dust * smoothstep(0.52, 0.1, abs(radius - 0.34 - dissolve * 0.22));
	float alpha = clamp(length(color) * 0.78, 0.0, 0.86) * (1.0 - smoothstep(0.88, 1.0, completion));
	COLOR = vec4(color, alpha);
}
