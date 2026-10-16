shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.9, 1.0, 0.85);
uniform float pulse : hint_range(0.0, 2.0) = 1.0;
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	float flicker = 0.85 + 0.15 * sin(TIME * 3.5 * time_scale + VERTEX.x * 12.0 + VERTEX.y * 7.0);
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * pulse * flicker * 1.6;
	ALPHA = base_color.a * pulse;
}
