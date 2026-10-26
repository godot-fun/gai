shader_type canvas_item;
render_mode unshaded;

uniform vec4 note_tint : source_color = vec4(0.10, 0.90, 0.82, 1.0);
uniform float seed = 0.0;
uniform float shader_time = 0.0;


void fragment() {
	float shimmer = 0.92 + sin(shader_time * 4.0 + seed * 21.0 + SCREEN_UV.y * 35.0) * 0.08;
	vec3 glow = note_tint.rgb * (0.10 + shimmer * 0.16) * COLOR.a;
	COLOR.rgb = COLOR.rgb * shimmer + glow;
}
