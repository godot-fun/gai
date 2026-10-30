shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Flat annulus for Saturn's rings. The owning node scales a unit QuadMesh (size 2 × 2), so VERTEX
// stays inside the unit disc and every radius below is a fraction of the ring's outer edge.

uniform vec4 inner_color : source_color = vec4(0.82, 0.74, 0.62, 1.0);
uniform vec4 outer_color : source_color = vec4(0.95, 0.90, 0.78, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.55;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.98;
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform float band_frequency = 42.0;
uniform float band_contrast : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;

// Fragment-stage VERTEX is in view space, so the ring radius must be measured in the vertex stage.
varying vec2 ring_position;

float band_noise(float radius, float angle) {
	float bands = sin(radius * band_frequency) * 0.5 + 0.5;
	float second = sin(radius * band_frequency * 0.37 + 1.7) * 0.5 + 0.5;
	float grain = sin(radius * 260.0 + angle * 8.0) * 0.08;
	return clamp(bands * 0.65 + second * 0.35 + grain, 0.0, 1.0);
}

void vertex() {
	ring_position = VERTEX.xy;
}

void fragment() {
	vec2 local = ring_position;
	float radius = length(local);
	float angle = atan(local.y, local.x);
	if (radius < inner_radius || radius > outer_radius) {
		discard;
	}
	float edge = smoothstep(inner_radius, inner_radius + 0.04, radius) * (1.0 - smoothstep(outer_radius - 0.06, outer_radius, radius));
	float bands = band_noise(radius, angle);
	float density = mix(1.0 - band_contrast, 1.0, bands);
	vec3 tint = mix(inner_color.rgb, outer_color.rgb, smoothstep(inner_radius, outer_radius, radius));
	ALBEDO = tint * brightness;
	ALPHA = clamp(edge * density * opacity, 0.0, 1.0);
}
