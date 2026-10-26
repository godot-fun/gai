shader_type canvas_item;
render_mode unshaded;

uniform vec4 energy_color : source_color = vec4(0.12, 0.96, 0.78, 1.0);
uniform float seed = 0.0;


void fragment() {
	float flicker = 0.90 + sin((SCREEN_UV.x * 83.0 + SCREEN_UV.y * 57.0 + seed * 19.0) * 6.283185) * 0.10;
	COLOR.rgb = COLOR.rgb * flicker + energy_color.rgb * COLOR.a * 0.12;
}
