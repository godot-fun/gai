// Standing wave shared by the sand field and the display. The plate is the whole window, kept
// square around the center so nodal figures stay symmetric on wide windows.
// mode = (n, m, sign) for u = cos(n*pi*x)cos(m*pi*y) + sign*cos(m*pi*x)cos(n*pi*y).
uniform vec3 mode_a = vec3(1.0, 2.0, -1.0);
uniform vec3 mode_b = vec3(1.0, 2.0, -1.0);
uniform float mode_mix = 1.0;

vec2 plate_point(vec2 uv, float view_aspect) {
	return vec2(0.5 + (uv.x - 0.5) * view_aspect, uv.y);
}

float chladni_mode(vec2 p, vec3 mode) {
	float pi = 3.14159265;
	return cos(mode.x * pi * p.x) * cos(mode.y * pi * p.y) + mode.z * cos(mode.y * pi * p.x) * cos(mode.x * pi * p.y);
}

// Highest wave number of the current blend; amplitude slopes grow with it.
float plate_frequency() {
	float t = smoothstep(0.0, 1.0, mode_mix);
	return max(mix(max(mode_a.x, mode_a.y), max(mode_b.x, mode_b.y), t), 1.0);
}

// Signed amplitude in [-1, 1]; zero on the nodal lines.
float plate_amplitude(vec2 uv, float view_aspect) {
	vec2 p = plate_point(uv, view_aspect);
	float t = smoothstep(0.0, 1.0, mode_mix);
	return mix(chladni_mode(p, mode_a), chladni_mode(p, mode_b), t) * 0.5;
}
