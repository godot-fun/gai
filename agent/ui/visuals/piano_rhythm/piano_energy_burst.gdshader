shader_type canvas_item;
render_mode unshaded;

uniform vec4 energy_color : source_color = vec4(0.12, 0.96, 0.78, 1.0);
uniform float seed = 0.0;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.5;


void fragment() {
	float phase = TIME * (11.0 + impact_strength * 7.0) + seed * 19.0;
	float grain = sin((SCREEN_UV.x * 83.0 + SCREEN_UV.y * 57.0 + seed * 19.0) * 6.283185 + phase * 0.31);
	float flicker = 0.89 + grain * 0.07 + sin(phase + SCREEN_UV.x * 13.0) * 0.04;
	float spark = pow(max(sin(phase * 1.61 + SCREEN_UV.x * 29.0 - SCREEN_UV.y * 23.0), 0.0), 10.0);
	float energy = (0.11 + impact_strength * 0.11 + spark * 0.20) * COLOR.a;
	COLOR.rgb = COLOR.rgb * flicker + energy_color.rgb * energy + vec3(spark * COLOR.a * 0.15);
}
