shader_type canvas_item;
render_mode unshaded;

// Runtime contract with SemanticBlackHole.gd. Envelopes are normalized to 0..1.
uniform vec4 accent_color : source_color = vec4(0.15, 0.8, 1.0, 1.0);
uniform vec4 success_color : source_color = vec4(0.2, 0.9, 0.5, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.2, 0.25, 1.0);
uniform float gravity = 0.0;
uniform float disk_energy = 0.0;
uniform float reasoning_density = 0.0;
uniform float jet_energy = 0.0;
uniform float wormhole_open = 0.0;
uniform float wormhole_angle = -0.6;
uniform float success_return = 0.0;
uniform float success_return_progress = 0.0;
uniform float failure_shock = 0.0;
uniform float context_density = 0.3;
uniform float rotation_direction = 1.0;
uniform float completion = 0.0;
uniform float error_completion = 0.0;
uniform float aspect = 1.777;

float hash21(vec2 p) {
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

float ring(float radius, float center, float width) {
	return exp(-abs(radius - center) / max(width, 0.0001));
}

float line_segment(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return exp(-length(pa - ba * h) / width);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float t = TIME * rotation_direction;

	// Semantic dust follows logarithmic spiral bands. Faster angular motion near the center
	// suggests differential orbital speed without maintaining real particles on the CPU.
	float spiral_phase = angle * 7.0 + log(max(radius, 0.025)) * 19.0 - t * (2.0 + 1.8 / max(radius * 8.0, 0.8));
	float dust_cells = noise(vec2(floor(angle * 38.0), floor(radius * 92.0 - t * 8.0)));
	float dust = smoothstep(0.82 - context_density * 0.22, 0.98, dust_cells) * smoothstep(0.78, 0.11, radius);
	dust *= 0.3 + 0.7 * pow(abs(sin(spiral_phase)), 9.0);
	vec3 color = accent_color.rgb * dust * (0.24 + gravity * 0.72);

	// The disk is an aspect-correct ellipse. Splitting at local y lets the back half be drawn
	// dimly before the horizon and the front half brightly after it, creating a 3D silhouette.
	float disk_radius = length(vec2(p.x, p.y / 0.27));
	float disk_noise = noise(vec2(angle * 12.0 - t * (2.4 + 1.2 / max(disk_radius, 0.2)), disk_radius * 36.0));
	float disk_band = ring(disk_radius, 0.33, 0.035 + disk_noise * 0.022) * smoothstep(0.05, 0.5, disk_energy);
	float hot_inner = ring(disk_radius, 0.245, 0.018) * disk_energy;
	float back_mask = smoothstep(0.025, -0.045, p.y);
	vec3 disk_color = mix(accent_color.rgb, vec3(1.0, 0.68, 0.28), 0.42 + disk_noise * 0.28);
	color += disk_color * (disk_band + hot_inner * 1.4) * back_mask * 0.48;

	// The photon ring approximates gravitational lensing without sampling the actual chat UI.
	float horizon_radius = mix(0.015, 0.112, smoothstep(0.0, 0.75, gravity));
	float lens = ring(radius, horizon_radius + 0.026, 0.006 + reasoning_density * 0.005);
	float upper_lens = ring(length(vec2(p.x, (p.y + 0.105) / 0.42)), 0.27, 0.013) * smoothstep(-0.02, 0.08, p.y);
	color += disk_color * upper_lens * disk_energy * 0.65;
	color += mix(accent_color.rgb, vec3(1.0), 0.68) * lens * (0.55 + disk_energy * 1.15);

	// The event horizon remains nearly silent and opaque while activity accumulates around it.
	float horizon = 1.0 - smoothstep(horizon_radius - 0.006, horizon_radius + 0.005, radius);
	color = mix(color, vec3(0.0), horizon * 0.98);
	float front_mask = smoothstep(-0.035, 0.035, p.y);
	color += disk_color * (disk_band + hot_inner * 1.55) * front_mask * 0.92;

	// Reasoning broadens a subtle interference halo around the photon ring.
	float reasoning_halo = ring(radius, horizon_radius + 0.055 + sin(TIME * 3.0) * 0.006, 0.012);
	color += accent_color.rgb * reasoning_halo * reasoning_density * 0.34;

	// Content leaves as an asymmetric bipolar jet. The secondary jet is intentionally weaker.
	vec2 jet_dir = normalize(vec2(0.82, -0.57));
	float primary_jet = line_segment(p, jet_dir * horizon_radius, jet_dir * 0.95, 0.012 + jet_energy * 0.018);
	float secondary_jet = line_segment(p, -jet_dir * horizon_radius, -jet_dir * 0.62, 0.01 + jet_energy * 0.012);
	float jet_texture = 0.58 + 0.42 * noise(vec2(dot(p, jet_dir) * 95.0 - TIME * 24.0, dot(p, vec2(-jet_dir.y, jet_dir.x)) * 30.0));
	vec3 jet_color = mix(accent_color.rgb, vec3(1.0, 0.64, 0.28), 0.58);
	color += jet_color * (primary_jet + secondary_jet * 0.48) * jet_texture * jet_energy * 1.25;

	// A tool opens a satellite wormhole at a stable name-derived angle.
	vec2 worm_dir = vec2(cos(wormhole_angle), sin(wormhole_angle));
	vec2 worm_pos = worm_dir * 0.64;
	float worm_radius = length(p - worm_pos);
	float worm_ring = ring(worm_radius, 0.055 * wormhole_open, 0.008);
	float bridge = line_segment(p, worm_dir * (horizon_radius + 0.02), worm_pos, 0.005 + wormhole_open * 0.004);
	float bridge_packets = pow(max(0.0, sin(length(p - worm_pos) * 92.0 + TIME * 12.0)), 14.0);
	color += accent_color.rgb * (worm_ring * 1.55 + bridge * (0.24 + bridge_packets)) * wormhole_open;

	// Travel progress and brightness are intentionally independent. The packet stays fully visible
	// for its whole journey, rests briefly on the photon ring, then becomes an absorption flash.
	float return_position = mix(0.64, horizon_radius, success_return_progress);
	vec2 return_point = worm_dir * return_position;
	float return_packet = exp(-length(p - return_point) / 0.018) * success_return;
	float absorption_flash = ring(radius, horizon_radius + 0.012, 0.009) * smoothstep(0.92, 1.0, success_return_progress) * success_return;
	color += success_color.rgb * (return_packet * 1.8 + bridge * success_return * 0.42 + absorption_flash * 1.25);

	// Failure perturbs the disk rather than tinting the whole screen.
	float shock_radius = (1.0 - failure_shock) * 0.52 + horizon_radius;
	float shock = ring(radius + sin(angle * 11.0 + TIME * 9.0) * 0.012, shock_radius, 0.012);
	float broken_disk = disk_band * smoothstep(0.72, 0.98, noise(vec2(angle * 17.0, floor(TIME * 12.0))));
	color += error_color.rgb * (shock + broken_disk * 1.4) * failure_shock;

	// Completion consumes the remaining field, flashes at the singularity, then emits sparse
	// Hawking-like dust. Error completion substitutes a red unstable glow for the white flash.
	float consume = smoothstep(0.0, 0.58, completion);
	float collapse_radius = mix(0.42, 0.018, consume);
	float collapse_ring = ring(radius, collapse_radius, 0.009) * smoothstep(0.02, 0.62, completion);
	float flash = exp(-radius / 0.055) * smoothstep(0.5, 0.7, completion) * (1.0 - smoothstep(0.72, 0.84, completion));
	float evaporation = smoothstep(0.66, 1.0, completion);
	float hawking = smoothstep(0.9, 0.995, noise(floor(p * 175.0) - floor(TIME * 5.0))) * smoothstep(0.68, 0.08, radius);
	vec3 final_color = mix(vec3(1.0), error_color.rgb, error_completion);
	color *= 1.0 - consume * 0.92;
	color += final_color * (collapse_ring * 1.5 + flash * 2.4 + hawking * evaporation * 0.85);

	float alpha = clamp(length(color) * 0.72 + horizon * gravity * 0.62, 0.0, 0.82);
	alpha *= 1.0 - smoothstep(0.91, 1.0, completion);
	COLOR = vec4(color, alpha);
}
