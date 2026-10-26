shader_type canvas_item;
render_mode unshaded;

uniform vec4 energy_color : source_color = vec4(0.12, 0.96, 0.78, 1.0);
uniform float seed = 0.0;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.5;


void fragment() {
	float phase = TIME * (8.0 + impact_strength * 9.0) + seed * 19.0;
	float fracture = sin(SCREEN_UV.x * 410.0 - SCREEN_UV.y * 260.0 + phase * 1.7);
	float shimmer = pow(max(fracture, 0.0), 12.0);
	float grain = sin((SCREEN_UV.x * 107.0 + SCREEN_UV.y * 73.0 + seed * 23.0) * 6.283185 + phase * 0.27);
	float flicker = 0.92 + grain * 0.045 + shimmer * 0.12;
	float energy = (0.07 + impact_strength * 0.10 + shimmer * 0.18) * COLOR.a;
	// The note supplies the hue. Fractures are white-hot highlights, never a fixed blue tint.
	vec3 refracted = mix(COLOR.rgb, vec3(1.0), shimmer * 0.12);
	COLOR.rgb = refracted * flicker + energy_color.rgb * energy + vec3(shimmer * COLOR.a * 0.12);
}
