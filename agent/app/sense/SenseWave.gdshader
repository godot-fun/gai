shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent_color : source_color = vec4(0.30, 0.65, 1.0, 1.0);
uniform sampler2D ripple_texture : filter_linear, repeat_enable;
uniform float elapsed = 0.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float syllable : hint_range(0.0, 1.0) = 0.0;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float attack : hint_range(0.0, 1.0) = 0.0;
uniform float peak : hint_range(0.0, 1.0) = 0.0;
uniform float phase_mode : hint_range(0.0, 1.0) = 0.0;
uniform float impact_progress : hint_range(0.0, 1.0) = 1.0;

const float PI_VALUE = 3.14159265359;
const float TAU_VALUE = 6.28318530718;

float soft_line(float distance_value, float width_value, float softness) {
	return 1.0 - smoothstep(width_value, width_value + softness, distance_value);
}

float angular_distance(float a, float b) {
	return abs(mod(a - b + PI_VALUE, TAU_VALUE) - PI_VALUE);
}

void add_light(inout vec3 light, inout float alpha_value, vec3 color, float amount) {
	light += color * amount;
	alpha_value += amount;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.y *= -1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float life = 0.68 + energy * 1.10 + syllable * 2.80;

	// A few low-frequency harmonics make one continuous living membrane. Raw microphone
	// samples never reach this geometry, so the silhouette cannot develop waveform spikes.
	float drift = elapsed * (mix(0.42, 0.72, phase_mode) + activity * 0.58);
	float harmonic_a = sin(angle * 3.0 + drift * 1.3);
	float harmonic_b = sin(angle * 5.0 - drift * 0.9 + 1.7);
	float harmonic_c = sin(angle * 2.0 + drift * 0.48 - 0.8);
	float membrane_noise = harmonic_a * 0.018 + harmonic_b * 0.010 + harmonic_c * 0.008;
	float history_u = fract(angle / TAU_VALUE + 0.5 - elapsed * (0.055 + activity * 0.09));
	float history_ripple = texture(ripple_texture, vec2(history_u, 0.5)).r;
	float ripple_carrier = sin(angle * 8.0 - elapsed * (2.0 + activity * 4.5));
	float voice_ripple = history_ripple * ripple_carrier * (0.018 + syllable * 0.060);
	float attack_direction = drift * 1.8 + 0.9;
	float directional_bulge = pow(max(0.0, cos(angular_distance(angle, attack_direction))), 7.0) * attack * 0.105;
	float membrane_radius = 0.225 + energy * 0.078 + membrane_noise * life + voice_ripple + directional_bulge;
	float membrane_sdf = radius - membrane_radius;

	// Soft grounding shadow, deliberately detached from the luminous silhouette.
	vec2 shadow_p = p - vec2(0.0, -0.105);
	float shadow_shape = length(shadow_p / vec2(1.18, 0.48));
	float shadow = (1.0 - smoothstep(0.20, 0.48, shadow_shape)) * 0.18;

	// Aurora fog and a thin translucent membrane, with moving cyan-violet refraction.
	float outer_fog = exp(-max(0.0, membrane_sdf) * 11.0) * (1.0 - smoothstep(-0.02, 0.20, membrane_sdf)) * 0.12;
	float membrane_glow = exp(-abs(membrane_sdf) * 44.0) * 0.42;
	float membrane_edge = soft_line(abs(membrane_sdf), 0.0025, 0.006) * 0.64;
	float color_flow = 0.5 + 0.5 * sin(angle * 2.0 - drift * 2.1 + radius * 18.0);
	vec3 cyan = mix(accent_color.rgb, vec3(0.30, 0.92, 1.0), 0.46);
	vec3 violet = mix(accent_color.rgb, vec3(0.68, 0.38, 1.0), 0.52);
	vec3 aurora_color = mix(cyan, violet, color_flow);

	// Glassy interior: sparse caustics rather than an opaque filled circle.
	float inside = 1.0 - smoothstep(-0.005, 0.018, membrane_sdf);
	float caustic_wave = sin(angle * (4.0 + syllable * 3.0) + radius * 31.0 - drift * (2.4 + activity * 2.8));
	float caustics = pow(max(0.0, caustic_wave), 7.0) * inside * (0.10 + syllable * 0.22);
	float outward_flow = pow(max(0.0, sin(radius * 42.0 - elapsed * (3.0 + activity * 8.0) + angle * 2.0)), 10.0) *
		inside * activity * 0.14;
	float inner_haze = (1.0 - smoothstep(0.03, membrane_radius, radius)) * 0.055;

	// A compact refractive seed anchors the composition without a large white diamond.
	float core_radius = 0.038 + energy * 0.012 + sin(elapsed * 3.6) * 0.0025;
	float core_glow = exp(-radius * 27.0) * (0.20 + peak * 0.16);
	float core_shell = soft_line(abs(radius - core_radius), 0.002, 0.005) * 0.70;
	float core_seed = 1.0 - smoothstep(core_radius * 0.34, core_radius * 0.62, radius);

	// Three incomplete orbital particles become more legible during transcription.
	float orbit_radius = 0.355 + sin(elapsed * 0.7) * 0.008;
	float particle_mask = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float particle_angle = elapsed * (mix(0.48, 1.05, phase_mode) + activity * 1.35) + fi * TAU_VALUE / 3.0;
		vec2 particle_position = vec2(cos(particle_angle), sin(particle_angle)) * orbit_radius;
		float particle_distance = length(p - particle_position);
		particle_mask += exp(-particle_distance * 95.0) * (0.14 + phase_mode * 0.22 + peak * 0.08);
	}
	float orbit_arc = soft_line(abs(radius - orbit_radius), 0.0015, 0.004) *
		(0.5 + 0.5 * sin(angle * 3.0 - elapsed)) * (0.025 + phase_mode * 0.055);

	// p is normalized to the effect's half-height; 1.0 reaches one screen half-height from center.
	float impact_radius = mix(0.08, 1.0, impact_progress);
	float impact_ring = soft_line(abs(radius - impact_radius), 0.002, 0.007) *
		(1.0 - impact_progress) * 0.42;

	vec3 light = vec3(0.0);
	float alpha_value = 0.0;
	add_light(light, alpha_value, vec3(0.018, 0.025, 0.050), shadow);
	add_light(light, alpha_value, aurora_color, outer_fog);
	add_light(light, alpha_value, aurora_color, membrane_glow);
	add_light(light, alpha_value, mix(aurora_color, vec3(1.0), 0.28), membrane_edge);
	add_light(light, alpha_value, aurora_color, caustics + outward_flow + inner_haze);
	add_light(light, alpha_value, accent_color.rgb, core_glow);
	add_light(light, alpha_value, mix(accent_color.rgb, vec3(1.0), 0.52), core_shell);
	add_light(light, alpha_value, vec3(0.86, 0.97, 1.0), core_seed * 0.90);
	add_light(light, alpha_value, mix(cyan, vec3(1.0), 0.25), particle_mask + orbit_arc);
	add_light(light, alpha_value, aurora_color, impact_ring);
	alpha_value = clamp(alpha_value, 0.0, 1.0);
	vec3 straight_color = light / max(alpha_value, 0.001);
	COLOR = vec4(clamp(straight_color, vec3(0.0), vec3(1.0)), alpha_value * fade_alpha);
}
